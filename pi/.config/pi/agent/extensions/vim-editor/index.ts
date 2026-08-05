/**
 * Vim Editor
 *
 * Lightweight modal Vim editing for Pi's prompt input. It deliberately builds
 * on Pi's CustomEditor instead of replacing app behavior, so control-key app
 * shortcuts still work: Ctrl+G opens $VISUAL/$EDITOR, Ctrl+C clears/aborts,
 * Ctrl+L opens model selection, Ctrl+P cycles models, etc.
 */

import { spawnSync } from "node:child_process";
import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { shouldOpenInlineSlashPicker } from "../inline-slash-completion/completion.ts";

const KEY = {
	left: "\x1b[D",
	down: "\x1b[B",
	up: "\x1b[A",
	right: "\x1b[C",
	lineStart: "\x01",
	lineEnd: "\x05",
	deleteToLineStart: "\x15",
	deleteToLineEnd: "\x0b",
	deleteWordBackward: "\x17",
	deleteWordForward: "\x1bd",
	wordLeft: "\x1bb",
	wordRight: "\x1bf",
	deleteForward: "\x1b[3~",
	deleteBackward: "\x7f",
	undo: "\x1f",
} as const;

type Mode = "insert" | "normal" | "visual";
type Operator = "d" | "c" | "y";
type YankKind = "char" | "line";
type TextObjectScope = "inner" | "around";
type VisualKind = "char" | "line";
type FindKind = "f" | "F" | "t" | "T";
type WordKind = "word" | "WORD";

interface PendingTextObject {
	operator: Operator;
	count: number;
	scope: TextObjectScope;
}

interface PendingFind {
	kind: FindKind;
	count: number;
	context: "normal" | "visual" | "operator";
	operator?: Operator;
}

interface LastFind {
	kind: FindKind;
	char: string;
}

interface TextRange {
	start: number;
	end: number;
	kind: YankKind;
}

interface EditorSnapshot {
	text: string;
	offset: number;
}

class VimEditor extends CustomEditor {
	private mode: Mode = "insert";
	private countBuffer = "";
	private pendingOperator: Operator | undefined;
	private pendingOperatorCount = 1;
	private pendingPrefix: "g" | undefined;
	private pendingPrefixCount = 1;
	private pendingTextObject: PendingTextObject | undefined;
	private pendingFind: PendingFind | undefined;
	private pendingReplaceCount = 0;
	private lastFind: LastFind | undefined;
	private yankText = "";
	private yankKind: YankKind = "line";
	private visualAnchorOffset = 0;
	private visualKind: VisualKind = "char";
	private redoStack: EditorSnapshot[] = [];

	override handleInput(data: string): void {
		if (matchesKey(data, "escape")) {
			if (this.mode === "insert" || this.mode === "visual") {
				this.mode = "normal";
				this.clearPending();
				this.tui.requestRender();
				return;
			}

			this.clearPending();
			super.handleInput(data);
			this.tui.requestRender();
			return;
		}

		if (this.mode === "insert") {
			const before = this.getText();
			const cursor = this.getCursor();
			const openInlineSlashPicker = shouldOpenInlineSlashPicker(
				this.getLines(),
				cursor.line,
				cursor.col,
				data,
			);
			super.handleInput(data);
			if (this.getText() !== before) this.clearRedo();
			if (openInlineSlashPicker) super.handleInput("\t");
			return;
		}

		if (this.mode === "visual") {
			this.handleVisualInput(data);
			return;
		}

		if (matchesKey(data, "enter")) {
			this.changeInnerWord(this.takeCount());
			this.tui.requestRender();
			return;
		}

		if (matchesKey(data, "ctrl+r")) {
			this.performRedo(this.takeCount());
			this.tui.requestRender();
			return;
		}

		// Preserve Pi app-level shortcuts in normal mode: Ctrl+G for $EDITOR,
		// Ctrl+C, Ctrl+D, Ctrl+L, Ctrl+P, extension shortcuts, etc.
		if (!isPlainPrintable(data)) {
			super.handleInput(data);
			return;
		}

		if (this.pendingFind) {
			this.handleFindTarget(data);
			this.tui.requestRender();
			return;
		}

		if (this.pendingReplaceCount > 0) {
			this.replaceWith(data, this.pendingReplaceCount);
			this.pendingReplaceCount = 0;
			this.tui.requestRender();
			return;
		}

		if (this.pendingTextObject) {
			const pending = this.pendingTextObject;
			this.pendingTextObject = undefined;
			if (this.handleTextObjectKey(pending.operator, pending.scope, data, pending.count)) {
				this.tui.requestRender();
				return;
			}

			this.clearPending();
			this.tui.requestRender();
			return;
		}

		if (this.pendingPrefix) {
			if (this.handlePrefixedKey(data)) {
				this.tui.requestRender();
				return;
			}
			this.clearPending();
		}

		if (this.pendingOperator) {
			if (this.captureCount(data)) {
				this.tui.requestRender();
				return;
			}

			const operator = this.pendingOperator;
			const totalCount = this.pendingOperatorCount * this.takeCount();
			const scopeKey = data.toLowerCase();
			this.pendingOperator = undefined;
			this.pendingOperatorCount = 1;

			if (scopeKey === "i" || scopeKey === "a") {
				this.pendingTextObject = {
					operator,
					count: totalCount,
					scope: scopeKey === "i" ? "inner" : "around",
				};
				this.tui.requestRender();
				return;
			}

			if (this.handleOperatorKey(operator, data, totalCount)) {
				this.tui.requestRender();
				return;
			}
		}

		if (this.captureCount(data)) {
			this.tui.requestRender();
			return;
		}

		if (isOperator(data)) {
			this.pendingOperator = data;
			this.pendingOperatorCount = this.takeCount();
			this.tui.requestRender();
			return;
		}

		const count = this.takeCount();
		if (this.handleNormalKey(data, count)) {
			this.tui.requestRender();
		}
	}

	private captureCount(data: string): boolean {
		if (!/^\d$/.test(data)) return false;
		if (data === "0" && this.countBuffer === "") return false;
		this.countBuffer += data;
		return true;
	}

	private takeCount(): number {
		const count = this.countBuffer === "" ? 1 : Math.max(1, Number.parseInt(this.countBuffer, 10));
		this.countBuffer = "";
		return count;
	}

	private clearPending(): void {
		this.countBuffer = "";
		this.pendingOperator = undefined;
		this.pendingOperatorCount = 1;
		this.pendingPrefix = undefined;
		this.pendingPrefixCount = 1;
		this.pendingTextObject = undefined;
		this.pendingFind = undefined;
		this.pendingReplaceCount = 0;
	}

	private clearRedo(): void {
		this.redoStack = [];
	}

	private handleFindTarget(char: string): void {
		const pending = this.pendingFind;
		this.pendingFind = undefined;
		if (!pending) return;

		const destination = findChar(this.getText(), this.cursorOffset(), pending.kind, char, pending.count);
		if (destination === undefined) return;

		this.lastFind = { kind: pending.kind, char };
		if (pending.context === "operator" && pending.operator) {
			const range = this.findOperatorRange(pending.kind, destination);
			if (range) this.applyRangeOperator(pending.operator, range);
			return;
		}

		this.moveToOffset(destination);
	}

	private repeatLastFind(reverse: boolean, count: number, operator?: Operator): boolean {
		if (!this.lastFind) return true;

		const kind = reverse ? reverseFindKind(this.lastFind.kind) : this.lastFind.kind;
		const destination = findChar(this.getText(), this.cursorOffset(), kind, this.lastFind.char, count, true);
		if (destination === undefined) return true;

		if (operator) {
			const range = this.findOperatorRange(kind, destination);
			if (range) this.applyRangeOperator(operator, range);
			return true;
		}

		this.moveToOffset(destination);
		return true;
	}

	private findOperatorRange(kind: FindKind, destination: number): TextRange | undefined {
		const cursor = this.cursorOffset();
		if (kind === "f" || kind === "t") {
			const end = Math.min(this.getText().length, destination + 1);
			return cursor < end ? { start: cursor, end, kind: "char" } : undefined;
		}

		return destination < cursor ? { start: destination, end: cursor, kind: "char" } : undefined;
	}

	private handleVisualInput(data: string): void {
		if (matchesKey(data, "enter")) {
			this.applyVisualOperator("c");
			this.tui.requestRender();
			return;
		}

		if (!isPlainPrintable(data)) {
			super.handleInput(data);
			return;
		}

		if (this.pendingFind) {
			this.handleFindTarget(data);
			this.tui.requestRender();
			return;
		}

		if (this.pendingPrefix) {
			if (this.handlePrefixedKey(data)) {
				this.tui.requestRender();
				return;
			}
			this.clearPending();
		}

		if (this.captureCount(data)) {
			this.tui.requestRender();
			return;
		}

		const count = this.takeCount();
		if (this.handleVisualKey(data, count)) {
			this.tui.requestRender();
		}
	}

	private handleVisualKey(data: string, count: number): boolean {
		switch (data) {
			case "v":
				this.mode = "normal";
				this.clearPending();
				return true;
			case "V":
				this.visualKind = this.visualKind === "line" ? "char" : "line";
				return true;
			case "o": {
				const oldAnchor = this.visualAnchorOffset;
				this.visualAnchorOffset = this.cursorOffset();
				this.moveToOffset(oldAnchor);
				return true;
			}
			case "h":
				this.repeat(KEY.left, count);
				return true;
			case "j":
				this.moveVertical(1, count);
				return true;
			case "k":
				this.moveVertical(-1, count);
				return true;
			case "l":
				this.repeat(KEY.right, count);
				return true;
			case "w":
				this.moveWithScan(nextWordStart, count);
				return true;
			case "W":
				this.moveWithScan(nextWORDStart, count);
				return true;
			case "b":
				this.moveWithScan(previousWordStart, count);
				return true;
			case "B":
				this.moveWithScan(previousWORDStart, count);
				return true;
			case "e":
				this.moveWithScan(nextWordEnd, count);
				return true;
			case "E":
				this.moveWithScan(nextWORDEnd, count);
				return true;
			case "f":
			case "F":
			case "t":
			case "T":
				this.pendingFind = { kind: data, count, context: "visual" };
				return true;
			case ";":
				return this.repeatLastFind(false, count);
			case ",":
				return this.repeatLastFind(true, count);
			case "0":
			case "^":
				this.repeat(KEY.lineStart, 1);
				return true;
			case "$":
				this.repeat(KEY.lineEnd, 1);
				return true;
			case "g":
				this.pendingPrefix = "g";
				this.pendingPrefixCount = count;
				return true;
			case "G":
				this.goDocumentEnd();
				return true;
			case "c":
			case "s":
				this.applyVisualOperator("c");
				return true;
			case "d":
			case "x":
				this.applyVisualOperator("d");
				return true;
			case "y":
				this.applyVisualOperator("y");
				return true;
			case "p":
			case "P":
				this.replaceVisualWithPaste(count);
				return true;
		}

		return false;
	}

	private handlePrefixedKey(data: string): boolean {
		if (this.pendingPrefix !== "g") return false;
		this.pendingPrefix = undefined;
		const count = this.pendingPrefixCount;
		this.pendingPrefixCount = 1;

		if (data === "g") {
			this.goDocumentStart();
			return true;
		}
		if (data === "e") {
			this.moveWithScan(previousWordEnd, count);
			return true;
		}
		if (data === "E") {
			this.moveWithScan(previousWORDEnd, count);
			return true;
		}
		return false;
	}

	private handleTextObjectKey(operator: Operator, scope: TextObjectScope, data: string, count: number): boolean {
		const range = this.findTextObjectRange(scope, data, count);
		if (!range) return false;

		this.applyRangeOperator(operator, range);
		return true;
	}

	private findTextObjectRange(scope: TextObjectScope, data: string, count: number): TextRange | undefined {
		if (data === "w") return this.findWordTextObject(scope, count, "word");
		if (data === "W") return this.findWordTextObject(scope, count, "WORD");

		const pair = pairForTextObject(data);
		if (pair) return this.findBlockTextObject(scope, pair[0], pair[1]);

		if (data === "'" || data === '"' || data === "`") {
			return this.findQuoteTextObject(scope, data);
		}

		return undefined;
	}

	private findWordTextObject(scope: TextObjectScope, count: number, wordKind: WordKind): TextRange | undefined {
		const text = this.getText();
		if (!text) return undefined;

		let anchor = Math.min(this.cursorOffset(), Math.max(0, text.length - 1));
		if (isWhitespace(text[anchor] ?? "")) {
			let right = anchor;
			while (right < text.length && isWhitespace(text[right] ?? "")) right += 1;

			let left = anchor - 1;
			while (left >= 0 && isWhitespace(text[left] ?? "")) left -= 1;

			if (right < text.length) anchor = right;
			else if (left >= 0) anchor = left;
			else return undefined;
		}

		const anchorClass = wordClass(text[anchor] ?? "", wordKind);
		let start = anchor;
		while (start > 0 && wordClass(text[start - 1] ?? "", wordKind) === anchorClass) start -= 1;

		let end = anchor + 1;
		while (end < text.length && wordClass(text[end] ?? "", wordKind) === anchorClass) end += 1;

		for (let i = 1; i < count; i += 1) {
			while (end < text.length && isWhitespace(text[end] ?? "")) end += 1;
			const nextClass = wordClass(text[end] ?? "", wordKind);
			while (end < text.length && wordClass(text[end] ?? "", wordKind) === nextClass) end += 1;
		}

		if (scope === "around") {
			let aroundEnd = end;
			while (aroundEnd < text.length && isWhitespace(text[aroundEnd] ?? "")) aroundEnd += 1;
			if (aroundEnd > end) end = aroundEnd;
			else while (start > 0 && isWhitespace(text[start - 1] ?? "")) start -= 1;
		}

		return start < end ? { start, end, kind: "char" } : undefined;
	}

	private findBlockTextObject(scope: TextObjectScope, open: string, close: string): TextRange | undefined {
		const text = this.getText();
		const pair = findEnclosingPair(text, this.cursorOffset(), open, close);
		if (!pair) return undefined;

		const start = scope === "inner" ? pair.open + 1 : pair.open;
		const end = scope === "inner" ? pair.close : pair.close + 1;
		return start <= end ? { start, end, kind: "char" } : undefined;
	}

	private findQuoteTextObject(scope: TextObjectScope, quote: string): TextRange | undefined {
		const text = this.getText();
		const pair = findEnclosingQuote(text, this.cursorOffset(), quote);
		if (!pair) return undefined;

		const start = scope === "inner" ? pair.open + 1 : pair.open;
		const end = scope === "inner" ? pair.close : pair.close + 1;
		return start <= end ? { start, end, kind: "char" } : undefined;
	}

	private applyRangeOperator(operator: Operator, range: TextRange): void {
		const text = this.getText();
		const yank = text.slice(range.start, range.end);
		if (range.kind === "line") this.setLineYank(yank);
		else this.setCharYank(yank);

		if (operator === "y") return;

		this.replaceRange(range.start, range.end, "");
		if (operator === "c") this.mode = "insert";
	}

	private applyVisualOperator(operator: Operator): void {
		const range = this.visualRange();
		if (!range) return;

		this.applyRangeOperator(operator, range);
		if (operator !== "c") this.mode = "normal";
		this.clearPending();
	}

	private replaceVisualWithPaste(count: number): void {
		const range = this.visualRange();
		if (!range) return;

		const clipboardText = readSystemClipboard();
		const usingClipboard = clipboardText !== undefined && clipboardText.length > 0;
		const text = usingClipboard ? clipboardText : this.yankText;
		if (!text) return;

		const selected = this.getText().slice(range.start, range.end);
		if (range.kind === "line") this.setLineYank(selected);
		else this.setCharYank(selected);

		this.replaceRange(range.start, range.end, repeatText(text, count, usingClipboard ? "" : this.yankKind === "line" ? "\n" : ""));
		this.mode = "normal";
		this.clearPending();
	}

	private visualRange(): TextRange | undefined {
		return this.visualKind === "line" ? this.visualLineRange() : this.visualCharRange();
	}

	private visualCharRange(): TextRange | undefined {
		const text = this.getText();
		if (!text) return undefined;

		const active = Math.min(this.cursorOffset(), Math.max(0, text.length - 1));
		const anchor = Math.min(this.visualAnchorOffset, Math.max(0, text.length - 1));
		const start = Math.min(anchor, active);
		const end = Math.min(text.length, Math.max(anchor, active) + 1);
		return start < end ? { start, end, kind: "char" } : undefined;
	}

	private visualLineRange(): TextRange | undefined {
		const lines = this.getLines();
		if (lines.length === 0) return undefined;

		const anchorLine = this.offsetToLine(this.visualAnchorOffset);
		const activeLine = this.getCursor().line;
		const startLine = Math.min(anchorLine, activeLine);
		const endLine = Math.max(anchorLine, activeLine);
		return {
			start: this.lineStartOffset(startLine),
			end: this.lineEndOffset(endLine),
			kind: "line",
		};
	}

	private replaceRange(start: number, end: number, replacement: string): void {
		const text = this.getText();
		const safeStart = Math.max(0, Math.min(start, text.length));
		const safeEnd = Math.max(safeStart, Math.min(end, text.length));
		if (safeStart !== safeEnd || replacement.length > 0) this.clearRedo();
		this.setText(text.slice(0, safeStart) + replacement + text.slice(safeEnd));
		this.moveToOffset(safeStart + replacement.length);
	}

	private cursorOffset(): number {
		const lines = this.getLines();
		const cursor = this.getCursor();
		let offset = 0;
		for (let i = 0; i < cursor.line; i += 1) {
			offset += (lines[i] ?? "").length + 1;
		}
		return offset + cursor.col;
	}

	private moveVertical(delta: -1 | 1, count: number): void {
		// Clamp to the buffer edge: overshooting Up in the base editor turns
		// into prompt-history navigation (see goDocumentStart), which vim's
		// j/k must never trigger. Arrow keys keep the history behavior. Presses
		// stay ≤ the logical-line distance, which never exceeds the visual one.
		const line = this.getCursor().line;
		const room = delta < 0 ? line : this.getLines().length - 1 - line;
		this.repeat(delta < 0 ? KEY.up : KEY.down, Math.min(count, room));
	}

	private moveToOffset(offset: number): void {
		// Walk back from the end rather than out from the start: reaching the
		// start costs a history-safe end-anchor plus a full left walk anyway
		// (see goDocumentStart), so this halves the key replay.
		const length = this.getText().length;
		const clamped = Math.max(0, Math.min(offset, length));
		this.goDocumentEnd();
		this.repeat(KEY.left, length - clamped);
	}

	private lineStartOffset(line: number): number {
		const lines = this.getLines();
		let offset = 0;
		for (let i = 0; i < Math.min(line, lines.length); i += 1) {
			offset += (lines[i] ?? "").length + 1;
		}
		return offset;
	}

	private lineEndOffset(line: number): number {
		const lines = this.getLines();
		const safeLine = Math.max(0, Math.min(line, lines.length - 1));
		const start = this.lineStartOffset(safeLine);
		const lineEnd = start + (lines[safeLine] ?? "").length;
		return safeLine < lines.length - 1 ? lineEnd + 1 : lineEnd;
	}

	private offsetToLine(offset: number): number {
		const lines = this.getLines();
		let remaining = Math.max(0, offset);
		for (let line = 0; line < lines.length; line += 1) {
			const width = (lines[line] ?? "").length;
			if (remaining <= width) return line;
			remaining -= width + 1;
		}
		return Math.max(0, lines.length - 1);
	}

	private snapshot(): EditorSnapshot {
		return { text: this.getText(), offset: this.cursorOffset() };
	}

	private restoreSnapshot(snapshot: EditorSnapshot): void {
		this.setText(snapshot.text);
		this.moveToOffset(snapshot.offset);
	}

	private performUndo(count: number): void {
		for (let i = 0; i < count; i += 1) {
			const before = this.snapshot();
			super.handleInput(KEY.undo);
			if (this.getText() === before.text && this.cursorOffset() === before.offset) break;
			this.redoStack.push(before);
		}
	}

	private performRedo(count: number): void {
		for (let i = 0; i < count; i += 1) {
			const snapshot = this.redoStack.pop();
			if (!snapshot) break;
			this.restoreSnapshot(snapshot);
		}
	}

	private changeInnerWord(count: number): void {
		const range = this.findWordTextObject("inner", count, "word");
		if (!range) return;
		this.applyRangeOperator("c", range);
	}

	private scanOffset(scan: (text: string, offset: number) => number, count: number): number {
		const text = this.getText();
		let offset = this.cursorOffset();
		for (let i = 0; i < count; i += 1) offset = scan(text, offset);
		return offset;
	}

	private moveWithScan(scan: (text: string, offset: number) => number, count: number): void {
		this.moveToOffset(this.scanOffset(scan, count));
	}

	private applyWordOperator(operator: Operator, motion: "w" | "W" | "e" | "E" | "b" | "B", count: number): boolean {
		const text = this.getText();
		const cursor = this.cursorOffset();
		let range: TextRange | undefined;

		if (motion === "b" || motion === "B") {
			const scan = motion === "b" ? previousWordStart : previousWORDStart;
			const start = this.scanOffset(scan, count);
			if (start < cursor) range = { start, end: cursor, kind: "char" };
		} else if (operator === "c" && (motion === "w" || motion === "W") && !isWhitespace(text[cursor] ?? "")) {
			const scan = motion === "W" ? nextWORDStart : nextWordStart;
			let end = this.scanOffset(scan, count);
			while (end > cursor && isWhitespace(text[end - 1] ?? "")) end -= 1;
			if (cursor < end) range = { start: cursor, end, kind: "char" };
		} else if (motion === "e" || motion === "E") {
			const scan = motion === "E" ? nextWORDEnd : nextWordEnd;
			const end = Math.min(text.length, this.scanOffset(scan, count) + 1);
			if (cursor < end) range = { start: cursor, end, kind: "char" };
		} else {
			const scan = motion === "W" ? nextWORDStart : nextWordStart;
			const end = this.scanOffset(scan, count);
			if (cursor < end) range = { start: cursor, end, kind: "char" };
		}

		if (range) this.applyRangeOperator(operator, range);
		return true;
	}

	private toggleCase(count: number): void {
		const text = this.getText();
		const start = this.cursorOffset();
		const chars = Array.from(text.slice(start)).slice(0, count);
		if (chars.length === 0) return;

		const original = chars.join("");
		const toggled = chars
			.map((char) => {
				if (/^[a-z]$/.test(char)) return char.toUpperCase();
				if (/^[A-Z]$/.test(char)) return char.toLowerCase();
				return char;
			})
			.join("");
		if (toggled === original) this.moveToOffset(start + original.length);
		else this.replaceRange(start, start + original.length, toggled);
	}

	private joinLines(count: number): void {
		const joins = Math.max(2, count) - 1;
		let searchFrom = this.cursorOffset();
		let firstJoin: number | undefined;

		for (let i = 0; i < joins; i += 1) {
			const text = this.getText();
			const newline = text.indexOf("\n", searchFrom);
			if (newline < 0) break;

			const lineStart = text.lastIndexOf("\n", newline - 1) + 1;
			let start = newline;
			while (start > lineStart && isWhitespace(text[start - 1] ?? "")) start -= 1;

			let end = newline + 1;
			while (end < text.length && text[end] !== "\n" && isWhitespace(text[end] ?? "")) end += 1;
			this.replaceRange(start, end, " ");
			if (firstJoin === undefined) firstJoin = start;
			searchFrom = start + 1;
		}

		if (firstJoin !== undefined) this.moveToOffset(firstJoin);
	}

	private enterVisual(kind: VisualKind): void {
		this.mode = "visual";
		this.visualKind = kind;
		this.visualAnchorOffset = this.cursorOffset();
		this.clearPending();
	}

	private handleNormalKey(data: string, count: number): boolean {
		switch (data) {
			case "i":
				this.mode = "insert";
				return true;
			case "v":
				this.enterVisual("char");
				return true;
			case "V":
				this.enterVisual("line");
				return true;
			case "a":
				this.repeat(KEY.right, 1);
				this.mode = "insert";
				return true;
			case "I":
				this.repeat(KEY.lineStart, 1);
				this.mode = "insert";
				return true;
			case "A":
				this.repeat(KEY.lineEnd, 1);
				this.mode = "insert";
				return true;
			case "o":
				this.clearRedo();
				this.repeat(KEY.lineEnd, 1);
				this.insertTextAtCursor("\n");
				this.mode = "insert";
				return true;
			case "O":
				this.clearRedo();
				this.repeat(KEY.lineStart, 1);
				this.insertTextAtCursor("\n");
				this.repeat(KEY.up, 1);
				this.mode = "insert";
				return true;
			case "h":
				this.repeat(KEY.left, count);
				return true;
			case "j":
				this.moveVertical(1, count);
				return true;
			case "k":
				this.moveVertical(-1, count);
				return true;
			case "l":
				this.repeat(KEY.right, count);
				return true;
			case "w":
				this.moveWithScan(nextWordStart, count);
				return true;
			case "W":
				this.moveWithScan(nextWORDStart, count);
				return true;
			case "b":
				this.moveWithScan(previousWordStart, count);
				return true;
			case "B":
				this.moveWithScan(previousWORDStart, count);
				return true;
			case "e":
				this.moveWithScan(nextWordEnd, count);
				return true;
			case "E":
				this.moveWithScan(nextWORDEnd, count);
				return true;
			case "f":
			case "F":
			case "t":
			case "T":
				this.pendingFind = { kind: data, count, context: "normal" };
				return true;
			case ";":
				return this.repeatLastFind(false, count);
			case ",":
				return this.repeatLastFind(true, count);
			case "0":
			case "^":
				this.repeat(KEY.lineStart, 1);
				return true;
			case "$":
				this.repeat(KEY.lineEnd, 1);
				return true;
			case "g":
				this.pendingPrefix = "g";
				this.pendingPrefixCount = count;
				return true;
			case "G":
				this.goDocumentEnd();
				return true;
			case "~":
				this.toggleCase(count);
				return true;
			case "J":
				this.joinLines(count);
				return true;
			case "x":
				this.clearRedo();
				this.setCharYank(this.textForward(count));
				this.repeat(KEY.deleteForward, count);
				return true;
			case "X":
				this.clearRedo();
				this.setCharYank(this.textBackward(count));
				this.repeat(KEY.deleteBackward, count);
				return true;
			case "s":
				this.clearRedo();
				this.setCharYank(this.textForward(count));
				this.repeat(KEY.deleteForward, count);
				this.mode = "insert";
				return true;
			case "S":
				this.applyLineOperator("c", count);
				return true;
			case "D":
				this.clearRedo();
				this.setCharYank(this.textToLineEnd());
				this.repeat(KEY.deleteToLineEnd, 1);
				return true;
			case "C":
				this.clearRedo();
				this.setCharYank(this.textToLineEnd());
				this.repeat(KEY.deleteToLineEnd, 1);
				this.mode = "insert";
				return true;
			case "Y":
				this.applyLineOperator("y", count);
				return true;
			case "p":
				this.paste(true, count);
				return true;
			case "P":
				this.paste(false, count);
				return true;
			case "r":
				this.pendingReplaceCount = count;
				return true;
			case "u":
				this.performUndo(count);
				return true;
		}

		return false;
	}

	private handleOperatorKey(operator: Operator, data: string, count: number): boolean {
		if (data === operator) {
			this.applyLineOperator(operator, count);
			return true;
		}

		switch (data) {
			case "w":
			case "W":
			case "e":
			case "E":
			case "b":
			case "B":
				return this.applyWordOperator(operator, data, count);
			case "f":
			case "F":
			case "t":
			case "T":
				this.pendingFind = { kind: data, count, context: "operator", operator };
				return true;
			case ";":
				return this.repeatLastFind(false, count, operator);
			case ",":
				return this.repeatLastFind(true, count, operator);
			case "h":
				return this.applyBackwardCharOperator(operator, count);
			case "l":
				return this.applyForwardCharOperator(operator, count);
			case "$":
				return this.applyToLineEndOperator(operator);
			case "0":
			case "^":
				return this.applyToLineStartOperator(operator);
		}

		return false;
	}

	private applyLineOperator(operator: Operator, count: number): void {
		const lines = this.getLines();
		const cursor = this.getCursor();
		const block = lines.slice(cursor.line, Math.min(lines.length, cursor.line + count));
		this.setLineYank(block.length > 0 ? block.join("\n") : "");

		if (operator === "y") return;
		this.clearRedo();
		if (operator === "c") {
			this.changeCurrentLines(count);
			this.mode = "insert";
			return;
		}

		this.deleteCurrentLines(count);
	}

	private applyForwardCharOperator(operator: Operator, count: number): boolean {
		const yank = this.textForward(count);
		if (operator === "y") {
			this.setCharYank(yank);
			return true;
		}

		this.setCharYank(yank);
		this.clearRedo();
		this.repeat(KEY.deleteForward, count);
		if (operator === "c") this.mode = "insert";
		return true;
	}

	private applyBackwardCharOperator(operator: Operator, count: number): boolean {
		const yank = this.textBackward(count);
		if (operator === "y") {
			this.setCharYank(yank);
			return true;
		}

		this.setCharYank(yank);
		this.clearRedo();
		this.repeat(KEY.deleteBackward, count);
		if (operator === "c") this.mode = "insert";
		return true;
	}

	private applyToLineEndOperator(operator: Operator): boolean {
		const yank = this.textToLineEnd();
		if (operator === "y") {
			this.setCharYank(yank);
			return true;
		}

		this.setCharYank(yank);
		this.clearRedo();
		this.repeat(KEY.deleteToLineEnd, 1);
		if (operator === "c") this.mode = "insert";
		return true;
	}

	private applyToLineStartOperator(operator: Operator): boolean {
		const yank = this.textToLineStart();
		if (operator === "y") {
			this.setCharYank(yank);
			return true;
		}

		this.setCharYank(yank);
		this.clearRedo();
		this.repeat(KEY.deleteToLineStart, 1);
		if (operator === "c") this.mode = "insert";
		return true;
	}

	private deleteCurrentLines(count: number): void {
		for (let i = 0; i < count; i += 1) {
			this.repeat(KEY.lineStart, 1);
			this.repeat(KEY.deleteToLineEnd, 1);
			if (this.getLines().length > 1) {
				this.repeat(KEY.deleteForward, 1);
			}
		}
	}

	private changeCurrentLines(count: number): void {
		this.repeat(KEY.lineStart, 1);
		this.repeat(KEY.deleteToLineEnd, 1);
		for (let i = 1; i < count; i += 1) {
			if (this.getLines().length <= 1) break;
			this.repeat(KEY.deleteForward, 1);
			this.repeat(KEY.deleteToLineEnd, 1);
		}
	}

	private paste(after: boolean, count: number): void {
		this.clearRedo();
		const clipboardText = readSystemClipboard();
		const usingClipboard = clipboardText !== undefined && clipboardText.length > 0;
		const text = usingClipboard ? clipboardText : this.yankText;
		if (!text) return;

		const kind = usingClipboard && clipboardText !== this.yankText ? "char" : this.yankKind;
		if (usingClipboard) {
			this.yankText = clipboardText;
			this.yankKind = kind;
		}

		if (kind === "line") {
			const repeated = repeatText(text, count, "\n");
			const insertedLineCount = repeated.split("\n").length;
			if (after) {
				this.repeat(KEY.lineEnd, 1);
				this.insertTextAtCursor(`\n${repeated}`);
				return;
			}

			this.repeat(KEY.lineStart, 1);
			this.insertTextAtCursor(`${repeated}\n`);
			this.repeat(KEY.up, insertedLineCount);
			return;
		}

		const repeated = repeatText(text, count, "");
		if (after) this.repeat(KEY.right, 1);
		this.insertTextAtCursor(repeated);
	}

	private replaceWith(data: string, count: number): void {
		this.clearRedo();
		this.setCharYank(this.textForward(count));
		this.repeat(KEY.deleteForward, count);
		this.insertTextAtCursor(data.repeat(count));
		this.repeat(KEY.left, Math.max(1, count));
	}

	private setLineYank(text: string): void {
		this.yankText = text;
		this.yankKind = "line";
		writeSystemClipboard(text);
	}

	private setCharYank(text: string): void {
		this.yankText = text;
		this.yankKind = "char";
		writeSystemClipboard(text);
	}

	private textToLineEnd(): string {
		const { line, col } = this.getCursor();
		return (this.getLines()[line] ?? "").slice(col);
	}

	private textToLineStart(): string {
		const { line, col } = this.getCursor();
		return (this.getLines()[line] ?? "").slice(0, col);
	}

	private textForward(count: number): string {
		const { line, col } = this.getCursor();
		return (this.getLines()[line] ?? "").slice(col, col + count);
	}

	private textBackward(count: number): string {
		const { line, col } = this.getCursor();
		return (this.getLines()[line] ?? "").slice(Math.max(0, col - count), col);
	}

	private goDocumentStart(): void {
		// Never spam KEY.up here: the base editor turns Up on the first visual
		// line (col 0, or empty) into prompt-history navigation, which replaces
		// the buffer once history is non-empty. Anchor at the end (history-safe
		// setText trick) and walk back with Left, which wraps lines and never
		// touches history.
		this.goDocumentEnd();
		this.repeat(KEY.left, this.getText().length);
	}

	private goDocumentEnd(): void {
		// Public Editor.setText() leaves equal content untouched for undo purposes,
		// but still places the cursor at the end through setTextInternal().
		this.setText(this.getText());
	}

	private repeat(sequence: string, count: number): void {
		for (let i = 0; i < count; i += 1) {
			super.handleInput(sequence);
		}
	}

	override render(width: number): string[] {
		const lines = super.render(width);
		if (lines.length === 0) return lines;

		if (this.mode === "visual") this.applyVisualHighlight(lines);

		const label = this.modeLabel();
		const last = lines.length - 1;
		if (visibleWidth(lines[last]!) >= label.length) {
			lines[last] = truncateToWidth(lines[last]!, width - label.length, "") + label;
		}
		return lines;
	}

	private applyVisualHighlight(renderedLines: string[]): void {
		const range = this.visualRange();
		if (!range) return;

		const logicalLines = this.getLines();
		const padding = this.getPaddingX();
		let offset = 0;
		for (let line = 0; line < logicalLines.length; line += 1) {
			const logicalText = logicalLines[line] ?? "";
			const lineStart = offset;
			const lineEnd = offset + logicalText.length;
			const start = Math.max(range.start, lineStart);
			const end = Math.min(range.end, lineEnd);
			const renderIndex = line + 1;

			if (end > start && renderIndex < renderedLines.length - 1) {
				renderedLines[renderIndex] = highlightColumns(renderedLines[renderIndex]!, padding + start - lineStart, padding + end - lineStart);
			} else if (range.kind === "line" && logicalText.length === 0 && lineStart >= range.start && lineStart < range.end && renderIndex < renderedLines.length - 1) {
				renderedLines[renderIndex] = highlightColumns(renderedLines[renderIndex]!, padding, padding + 1);
			}

			offset = lineEnd + 1;
		}
	}

	private modeLabel(): string {
		if (this.mode === "insert") return " INSERT ";
		if (this.mode === "visual") return this.visualLabel();
		return this.normalLabel();
	}

	private visualLabel(): string {
		const range = this.visualRange();
		const size = range ? Math.max(0, range.end - range.start) : 0;
		return this.visualKind === "line" ? ` V-LINE ${size} ` : ` VISUAL ${size} `;
	}

	private normalLabel(): string {
		if (this.pendingReplaceCount > 0) return ` r${this.pendingReplaceCount} `;
		if (this.pendingFind) return ` ${this.pendingFind.operator ?? ""}${this.pendingFind.kind}? `;
		if (this.pendingTextObject) {
			const scope = this.pendingTextObject.scope === "inner" ? "i" : "a";
			return ` ${this.pendingTextObject.operator}${scope}? `;
		}
		if (this.pendingOperator) return ` ${this.pendingOperator}${this.countBuffer || ""}? `;
		if (this.pendingPrefix) return ` ${this.pendingPrefix}? `;
		return this.countBuffer ? ` ${this.countBuffer}·NORMAL ` : " NORMAL ";
	}
}

function isPlainPrintable(data: string): boolean {
	return data.length === 1 && data.charCodeAt(0) >= 32 && data.charCodeAt(0) !== 127;
}

function isOperator(data: string): data is Operator {
	return data === "d" || data === "c" || data === "y";
}

function isWhitespace(char: string): boolean {
	return /\s/.test(char);
}

function highlightColumns(line: string, startCol: number, endCol: number): string {
	if (endCol <= startCol) return line;

	let result = "";
	let col = 0;
	let highlighting = false;
	for (let i = 0; i < line.length; ) {
		const ansi = readAnsiSequence(line, i);
		if (ansi) {
			result += ansi.sequence;
			if (highlighting && disablesInverse(ansi.sequence)) result += "\x1b[7m";
			i += ansi.sequence.length;
			continue;
		}

		if (!highlighting && col >= startCol && col < endCol) {
			result += "\x1b[7m";
			highlighting = true;
		}

		const char = Array.from(line.slice(i))[0] ?? "";
		if (!char) break;
		result += char;
		col += Math.max(1, visibleWidth(char));
		i += char.length;

		if (highlighting && col >= endCol) {
			result += "\x1b[27m";
			highlighting = false;
		}
	}

	if (!highlighting && col === startCol && startCol < endCol) {
		result += "\x1b[7m \x1b[27m";
	} else if (highlighting) {
		result += "\x1b[27m";
	}
	return result;
}

function disablesInverse(sequence: string): boolean {
	return /\x1b\[(?:0|27)(?:;\d+)*m/.test(sequence);
}

function readAnsiSequence(text: string, index: number): { sequence: string } | undefined {
	if (text[index] !== "\x1b") return undefined;

	const rest = text.slice(index);
	const csi = /^\x1b\[[0-?]*[ -/]*[@-~]/.exec(rest);
	if (csi) return { sequence: csi[0] };

	const osc = /^\x1b\][^\x07]*(?:\x07|\x1b\\)/.exec(rest);
	if (osc) return { sequence: osc[0] };

	// Pi's hidden cursor marker is an APC sequence: ESC _ pi:c BEL.
	// Treat it as a zero-width terminal control sequence; otherwise visual
	// highlighting splits it and the literal "pi:c" leaks into the prompt.
	const apc = /^\x1b_[^\x07]*(?:\x07|\x1b\\)/.exec(rest);
	if (apc) return { sequence: apc[0] };

	const dcs = /^\x1bP.*?(?:\x07|\x1b\\)/.exec(rest);
	if (dcs) return { sequence: dcs[0] };

	const pm = /^\x1b\^.*?(?:\x07|\x1b\\)/.exec(rest);
	if (pm) return { sequence: pm[0] };

	return { sequence: text.slice(index, index + 2) };
}

function pairForTextObject(key: string): [string, string] | undefined {
	switch (key) {
		case "b":
		case "(":
		case ")":
			return ["(", ")"];
		case "B":
		case "{":
		case "}":
			return ["{", "}"];
		case "[":
		case "]":
			return ["[", "]"];
		case "<":
		case ">":
			return ["<", ">"];
	}
	return undefined;
}

function findEnclosingPair(text: string, offset: number, open: string, close: string): { open: number; close: number } | undefined {
	const targets = [Math.min(offset, Math.max(0, text.length - 1)), Math.min(Math.max(0, offset - 1), Math.max(0, text.length - 1))];
	let best: { open: number; close: number } | undefined;

	for (const target of targets) {
		const stack: number[] = [];
		for (let i = 0; i < text.length; i += 1) {
			const char = text[i];
			if (char === open) {
				stack.push(i);
			} else if (char === close && stack.length > 0) {
				const pairOpen = stack.pop()!;
				if (pairOpen <= target && target <= i) {
					const candidate = { open: pairOpen, close: i };
					if (!best || candidate.open >= best.open || candidate.close <= best.close) {
						best = candidate;
					}
				}
			}
		}
		if (best) return best;
	}

	return undefined;
}

function findEnclosingQuote(text: string, offset: number, quote: string): { open: number; close: number } | undefined {
	const targets = [Math.min(offset, Math.max(0, text.length - 1)), Math.min(Math.max(0, offset - 1), Math.max(0, text.length - 1))];

	for (const target of targets) {
		let open: number | undefined;
		for (let i = 0; i < text.length; i += 1) {
			if (text[i] !== quote || isEscaped(text, i)) continue;
			if (open === undefined) {
				open = i;
				continue;
			}

			if (open <= target && target <= i) return { open, close: i };
			open = undefined;
		}
	}

	return undefined;
}

function isEscaped(text: string, index: number): boolean {
	let slashCount = 0;
	for (let i = index - 1; i >= 0 && text[i] === "\\"; i -= 1) slashCount += 1;
	return slashCount % 2 === 1;
}

function writeSystemClipboard(text: string): void {
	if (text.length === 0) return;
	const command = clipboardWriteCommand();
	if (!command) return;
	spawnSync(command[0], command.slice(1), {
		input: text,
		encoding: "utf8",
		stdio: ["pipe", "ignore", "ignore"],
		timeout: 500,
	});
}

function readSystemClipboard(): string | undefined {
	const command = clipboardReadCommand();
	if (!command) return undefined;
	const result = spawnSync(command[0], command.slice(1), {
		encoding: "utf8",
		stdio: ["ignore", "pipe", "ignore"],
		timeout: 500,
	});
	return result.status === 0 ? result.stdout : undefined;
}

function clipboardWriteCommand(): string[] | undefined {
	if (process.platform === "darwin") return ["pbcopy"];
	if (process.env.WAYLAND_DISPLAY) return ["wl-copy"];
	return ["xclip", "-selection", "clipboard"];
}

function clipboardReadCommand(): string[] | undefined {
	if (process.platform === "darwin") return ["pbpaste"];
	if (process.env.WAYLAND_DISPLAY) return ["wl-paste", "--no-newline"];
	return ["xclip", "-selection", "clipboard", "-out"];
}

function repeatText(text: string, count: number, separator: string): string {
	return Array.from({ length: count }, () => text).join(separator);
}

function wordClass(char: string, wordKind: WordKind): number {
	if (!char || isWhitespace(char)) return 0;
	if (wordKind === "WORD" || /^[A-Za-z0-9_]$/.test(char)) return 1;
	return 2;
}

function nextStart(text: string, offset: number, wordKind: WordKind): number {
	let index = Math.max(0, Math.min(offset, text.length));
	if (index >= text.length) return text.length;

	const currentClass = wordClass(text[index] ?? "", wordKind);
	if (currentClass === 0) {
		while (index < text.length && wordClass(text[index] ?? "", wordKind) === 0) index += 1;
		return index;
	}

	while (index < text.length && wordClass(text[index] ?? "", wordKind) === currentClass) index += 1;
	while (index < text.length && wordClass(text[index] ?? "", wordKind) === 0) index += 1;
	return index;
}

function previousStart(text: string, offset: number, wordKind: WordKind): number {
	let index = Math.max(0, Math.min(offset, text.length));
	if (index <= 0) return 0;

	index -= 1;
	while (index > 0 && wordClass(text[index] ?? "", wordKind) === 0) index -= 1;
	const targetClass = wordClass(text[index] ?? "", wordKind);
	while (index > 0 && wordClass(text[index - 1] ?? "", wordKind) === targetClass) index -= 1;
	return index;
}

function nextEnd(text: string, offset: number, wordKind: WordKind): number {
	if (!text) return 0;

	const original = Math.max(0, Math.min(offset, text.length));
	if (original >= text.length) return text.length;
	let index = original;
	let targetClass = wordClass(text[index] ?? "", wordKind);

	if (targetClass === 0) {
		while (index < text.length && wordClass(text[index] ?? "", wordKind) === 0) index += 1;
	} else {
		while (index + 1 < text.length && wordClass(text[index + 1] ?? "", wordKind) === targetClass) index += 1;
		if (index > original) return index;
		index += 1;
		while (index < text.length && wordClass(text[index] ?? "", wordKind) === 0) index += 1;
	}

	if (index >= text.length) return original;
	targetClass = wordClass(text[index] ?? "", wordKind);
	while (index + 1 < text.length && wordClass(text[index + 1] ?? "", wordKind) === targetClass) index += 1;
	return index;
}

function previousEnd(text: string, offset: number, wordKind: WordKind): number {
	if (!text) return 0;

	const original = Math.max(0, Math.min(offset, text.length));
	if (original <= 0) return 0;
	let index = original - 1;

	if (original < text.length && wordClass(text[original] ?? "", wordKind) !== 0) {
		const currentClass = wordClass(text[original] ?? "", wordKind);
		while (index >= 0 && wordClass(text[index] ?? "", wordKind) === currentClass) index -= 1;
	}
	while (index >= 0 && wordClass(text[index] ?? "", wordKind) === 0) index -= 1;
	return Math.max(0, index);
}

export function nextWordStart(text: string, offset: number): number {
	return nextStart(text, offset, "word");
}

export function nextWORDStart(text: string, offset: number): number {
	return nextStart(text, offset, "WORD");
}

export function previousWordStart(text: string, offset: number): number {
	return previousStart(text, offset, "word");
}

export function previousWORDStart(text: string, offset: number): number {
	return previousStart(text, offset, "WORD");
}

export function nextWordEnd(text: string, offset: number): number {
	return nextEnd(text, offset, "word");
}

export function nextWORDEnd(text: string, offset: number): number {
	return nextEnd(text, offset, "WORD");
}

export function previousWordEnd(text: string, offset: number): number {
	return previousEnd(text, offset, "word");
}

export function previousWORDEnd(text: string, offset: number): number {
	return previousEnd(text, offset, "WORD");
}

export function findCharForward(
	text: string,
	offset: number,
	char: string,
	count = 1,
	skipAdjacent = false,
): number | undefined {
	if (!text || !char) return undefined;
	const cursor = Math.max(0, Math.min(offset, text.length));
	const lineEnd = text.indexOf("\n", cursor);
	const limit = lineEnd < 0 ? text.length : lineEnd;
	let searchFrom = cursor + 1;
	if (skipAdjacent && text[searchFrom] === char) searchFrom += char.length;

	let found = -1;
	for (let i = 0; i < Math.max(1, count); i += 1) {
		found = text.indexOf(char, searchFrom);
		if (found < 0 || found >= limit) return undefined;
		searchFrom = found + char.length;
	}
	return found;
}

export function findCharBackward(
	text: string,
	offset: number,
	char: string,
	count = 1,
	skipAdjacent = false,
): number | undefined {
	if (!text || !char) return undefined;
	const cursor = Math.max(0, Math.min(offset, text.length));
	const lineStart = text.lastIndexOf("\n", Math.max(0, cursor - 1)) + 1;
	let searchFrom = cursor - 1;
	if (skipAdjacent && text[searchFrom] === char) searchFrom -= char.length;

	let found = -1;
	for (let i = 0; i < Math.max(1, count); i += 1) {
		found = text.lastIndexOf(char, searchFrom);
		if (found < lineStart) return undefined;
		searchFrom = found - 1;
	}
	return found;
}

export function findChar(
	text: string,
	offset: number,
	kind: FindKind,
	char: string,
	count = 1,
	repeat = false,
): number | undefined {
	if (kind === "f" || kind === "t") {
		const found = findCharForward(text, offset, char, count, repeat && kind === "t");
		if (found === undefined) return undefined;
		return kind === "t" ? found - 1 : found;
	}

	const found = findCharBackward(text, offset, char, count, repeat && kind === "T");
	if (found === undefined) return undefined;
	return kind === "T" ? found + 1 : found;
}

function reverseFindKind(kind: FindKind): FindKind {
	if (kind === "f") return "F";
	if (kind === "F") return "f";
	if (kind === "t") return "T";
	return "t";
}

// Reclaim loop bounds. rpiv-core's session_start chain awaits git I/O before
// its lane-switcher handler installs LaneDockEditor, so its clobber can land
// well after our own handler ran — a one-shot deferred install loses that
// race. Instead we re-assert on an interval until the slot has stayed ours.
const RECLAIM_TICK_MS = 100;
const RECLAIM_WINDOW_TICKS = 300; // stop contesting after 30s uncontested
const RECLAIM_STABLE_TICKS = 5; // stop early once beaten + held 500ms

export default function (pi: ExtensionAPI) {
	// setEditorComponent is last-wins. rpiv-core (loaded after this extension
	// from the npm dir) installs its LaneDockEditor exactly once per runtime:
	// ctx.ui is the runner's stable uiContext and rpiv latches on its
	// identity. So whoever installs after rpiv's single shot owns the editor
	// until /reload. Install now (Vim is live while rpiv's chain is still
	// awaiting git I/O), then re-assert each tick a foreign factory appears;
	// once beaten and held, or after the window expires uncontested (e.g.
	// rpiv absent), stop. Trade-off: rpiv's editor-only gestures
	// (Down-on-empty opens top lane, Escape clears done lanes) are
	// unavailable; /lanes, its hotkey, and the dock widget keep working.
	let generation = 0;

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		const token = ++generation;
		const factory = (...args: ConstructorParameters<typeof VimEditor>) => new VimEditor(...args);
		ctx.ui.setEditorComponent(factory);

		let ticks = 0;
		let heldTicks = 0;
		let contested = false;
		const timer = setInterval(() => {
			try {
				if (token !== generation) {
					clearInterval(timer);
					return;
				}
				ticks += 1;
				if (ctx.ui.getEditorComponent() === factory) {
					heldTicks += 1;
					if ((contested && heldTicks >= RECLAIM_STABLE_TICKS) || ticks >= RECLAIM_WINDOW_TICKS) {
						clearInterval(timer);
					}
					return;
				}
				contested = true;
				heldTicks = 0;
				ctx.ui.setEditorComponent(factory);
			} catch {
				// ctx.ui asserts the runner is still active; if it tore down
				// without session_shutdown reaching us, just stop.
				clearInterval(timer);
			}
		}, RECLAIM_TICK_MS);
	});

	pi.on("session_shutdown", () => {
		// Invalidate the reclaim loop so a quit/reload/session-swap never
		// installs an editor against a torn-down ctx.
		generation += 1;
	});
}
