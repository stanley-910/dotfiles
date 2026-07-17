import assert from "node:assert/strict";
import test from "node:test";
import {
	applyInlineSlashCompletion,
	filterSkillCommands,
	findSlashCommandToken,
	isInlineSlashCommandToken,
	shouldOpenInlineSlashPicker,
} from "./completion.ts";

test("keeps at most 15 skill commands in the inline picker", () => {
	const skills = Array.from({ length: 20 }, (_, index) => ({
		value: `skill:skill-${index + 1}`,
		label: `skill:skill-${index + 1}`,
	}));
	const items = [{ value: "model", label: "model" }, ...skills];

	assert.deepEqual(filterSkillCommands(items), skills.slice(0, 15));
});

test("finds a slash command token after whitespace", () => {
	assert.deepEqual(findSlashCommandToken(["please use /skill:rese"], 0, 22), {
		query: "skill:rese",
		slashIndex: 11,
	});
});

test("finds a slash command token at the start of a later line", () => {
	assert.deepEqual(findSlashCommandToken(["first line", "/review"], 1, 7), {
		query: "review",
		slashIndex: 0,
	});
	assert.equal(isInlineSlashCommandToken(["first line", "/review"], 1, 7), true);
});

test("does not treat URLs, paths, or command arguments as command-name tokens", () => {
	assert.equal(findSlashCommandToken(["https://example.com"], 0, 19), undefined);
	assert.equal(findSlashCommandToken(["open foo/bar"], 0, 12), undefined);
	assert.equal(findSlashCommandToken(["use /deploy prod"], 0, 16), undefined);
});

test("opens the custom picker only where Pi's built-in picker will not", () => {
	assert.equal(shouldOpenInlineSlashPicker([""], 0, 0, "/"), false);
	assert.equal(shouldOpenInlineSlashPicker(["  "], 0, 2, "/"), false);
	assert.equal(shouldOpenInlineSlashPicker(["please "], 0, 7, "/"), true);
	assert.equal(shouldOpenInlineSlashPicker(["first", ""], 1, 0, "/"), true);
	assert.equal(shouldOpenInlineSlashPicker(["word"], 0, 4, "/"), false);
});

test("replaces only the inline command query and adds a trailing space", () => {
	assert.deepEqual(
		applyInlineSlashCompletion(["please /ski"], 0, 11, "skill:research", "ski"),
		{
			lines: ["please /skill:research "],
			cursorLine: 0,
			cursorCol: 23,
		},
	);
});

test("does not duplicate existing whitespace after the cursor", () => {
	assert.deepEqual(
		applyInlineSlashCompletion(["please /ski later"], 0, 11, "skill:research", "ski"),
		{
			lines: ["please /skill:research later"],
			cursorLine: 0,
			cursorCol: 22,
		},
	);
});

test("leaves start-of-message completion to Pi", () => {
	assert.equal(applyInlineSlashCompletion(["/ski"], 0, 4, "skill:research", "ski"), undefined);
});
