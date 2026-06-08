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

interface PendingTextObject {
	operator: Operator;
	count: number;
	scope: TextObjectScope;
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
	private pendingTextObject: PendingTextObject | undefined;
	private pendingReplaceCount = 0;
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
			super.handleInput(data);
			if (this.getText() !== before) this.clearRedo();
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
		this.pendingTextObject = undefined;
		this.pendingReplaceCount = 0;
	}

	private clearRedo(): void {
		this.redoStack = [];
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
				this.repeat(KEY.down, count);
				return true;
			case "k":
				this.repeat(KEY.up, count);
				return true;
			case "l":
				this.repeat(KEY.right, count);
				return true;
			case "w":
				this.repeat(KEY.wordRight, count);
				return true;
			case "b":
				this.repeat(KEY.wordLeft, count);
				return true;
			case "e":
				this.moveToNextWordEnd(count);
				return true;
			case "0":
			case "^":
				this.repeat(KEY.lineStart, 1);
				return true;
			case "$":
				this.repeat(KEY.lineEnd, 1);
				return true;
			case "g":
				this.pendingPrefix = "g";
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

		if (data === "g") {
			this.goDocumentStart();
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
		const objectKey = data === "W" ? "w" : data;
		if (objectKey === "w") return this.findWordTextObject(scope, count);

		const pair = pairForTextObject(objectKey);
		if (pair) return this.findBlockTextObject(scope, pair[0], pair[1]);

		if (objectKey === "'" || objectKey === '"' || objectKey === "`") {
			return this.findQuoteTextObject(scope, objectKey);
		}

		return undefined;
	}

	private findWordTextObject(scope: TextObjectScope, count: number): TextRange | undefined {
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

		let start = anchor;
		while (start > 0 && !isWhitespace(text[start - 1] ?? "")) start -= 1;

		let end = anchor + 1;
		while (end < text.length && !isWhitespace(text[end] ?? "")) end += 1;

		for (let i = 1; i < count; i += 1) {
			while (end < text.length && isWhitespace(text[end] ?? "")) end += 1;
			while (end < text.length && !isWhitespace(text[end] ?? "")) end += 1;
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

	private moveToOffset(offset: number): void {
		const clamped = Math.max(0, Math.min(offset, this.getText().length));
		this.goDocumentStart();
		this.repeat(KEY.right, clamped);
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
		const range = this.findWordTextObject("inner", count);
		if (!range) return;
		this.applyRangeOperator("c", range);
	}

	private moveToNextWordEnd(count: number): void {
		const text = this.getText();
		let offset = this.cursorOffset();
		for (let i = 0; i < count; i += 1) {
			offset = nextWordEnd(text, offset);
		}
		this.moveToOffset(offset);
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
				this.repeat(KEY.down, count);
				return true;
			case "k":
				this.repeat(KEY.up, count);
				return true;
			case "l":
				this.repeat(KEY.right, count);
				return true;
			case "w":
				this.repeat(KEY.wordRight, count);
				return true;
			case "b":
				this.repeat(KEY.wordLeft, count);
				return true;
			case "e":
				this.moveToNextWordEnd(count);
				return true;
			case "0":
			case "^":
				this.repeat(KEY.lineStart, 1);
				return true;
			case "$":
				this.repeat(KEY.lineEnd, 1);
				return true;
			case "g":
				this.pendingPrefix = "g";
				return true;
			case "G":
				this.goDocumentEnd();
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
			case "e":
				return this.applyForwardWordOperator(operator, count);
			case "b":
				return this.applyBackwardWordOperator(operator, count);
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

	private applyForwardWordOperator(operator: Operator, count: number): boolean {
		const yank = this.textForwardWord(count);
		if (operator === "y") {
			this.setCharYank(yank);
			return true;
		}

		this.setCharYank(yank);
		this.clearRedo();
		this.repeat(KEY.deleteWordForward, count);
		if (operator === "c") this.mode = "insert";
		return true;
	}

	private applyBackwardWordOperator(operator: Operator, count: number): boolean {
		const yank = this.textBackwardWord(count);
		if (operator === "y") {
			this.setCharYank(yank);
			return true;
		}

		this.setCharYank(yank);
		this.clearRedo();
		this.repeat(KEY.deleteWordBackward, count);
		if (operator === "c") this.mode = "insert";
		return true;
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

	private textForwardWord(count: number): string {
		const { line, col } = this.getCursor();
		const text = this.getLines()[line] ?? "";
		let end = col;
		for (let i = 0; i < count; i += 1) {
			end = nextWordBoundary(text, end);
		}
		return text.slice(col, end);
	}

	private textBackwardWord(count: number): string {
		const { line, col } = this.getCursor();
		const text = this.getLines()[line] ?? "";
		let start = col;
		for (let i = 0; i < count; i += 1) {
			start = previousWordBoundary(text, start);
		}
		return text.slice(start, col);
	}

	private goDocumentStart(): void {
		this.repeat(KEY.up, Math.max(1, this.getText().length + this.getLines().length));
		this.repeat(KEY.lineStart, 1);
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

function nextWordBoundary(text: string, start: number): number {
	let index = Math.max(0, Math.min(start, text.length));
	if (index >= text.length) return text.length;

	if (/\s/.test(text[index] ?? "")) {
		while (index < text.length && /\s/.test(text[index] ?? "")) index += 1;
		while (index < text.length && !/\s/.test(text[index] ?? "")) index += 1;
		return index;
	}

	while (index < text.length && !/\s/.test(text[index] ?? "")) index += 1;
	while (index < text.length && /\s/.test(text[index] ?? "")) index += 1;
	return index;
}

function previousWordBoundary(text: string, start: number): number {
	let index = Math.max(0, Math.min(start, text.length));
	if (index <= 0) return 0;

	index -= 1;
	while (index > 0 && /\s/.test(text[index] ?? "")) index -= 1;
	while (index > 0 && !/\s/.test(text[index - 1] ?? "")) index -= 1;
	return index;
}

function nextWordEnd(text: string, start: number): number {
	if (!text) return 0;

	const original = Math.max(0, Math.min(start, text.length - 1));
	let index = original;

	if (!isWhitespace(text[index] ?? "")) {
		if (index + 1 < text.length && !isWhitespace(text[index + 1] ?? "")) {
			while (index + 1 < text.length && !isWhitespace(text[index + 1] ?? "")) index += 1;
			return index;
		}

		// Already at the end of a word; search for the next word instead of
		// bouncing back to the whitespace before it.
		index += 1;
	}

	while (index < text.length && isWhitespace(text[index] ?? "")) index += 1;
	if (index >= text.length) return original;

	while (index + 1 < text.length && !isWhitespace(text[index + 1] ?? "")) index += 1;
	return index;
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		ctx.ui.setEditorComponent((tui, theme, keybindings) => new VimEditor(tui, theme, keybindings));
	});
}
