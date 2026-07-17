import assert from "node:assert/strict";
import test from "node:test";
import { buildCopyChoices, extractFencedCodeBlocks } from "./code-blocks.ts";

test("extracts language-labelled fenced code blocks", () => {
	const message = [
		"Diagram:",
		"```mermaid",
		"flowchart TD",
		"  A --> B",
		"```",
		"Implementation:",
		"```java",
		"class Main {}",
		"```",
	].join("\n");

	assert.deepEqual(extractFencedCodeBlocks(message), [
		{ language: "mermaid", text: "flowchart TD\n  A --> B" },
		{ language: "java", text: "class Main {}" },
	]);
	assert.deepEqual(
		buildCopyChoices(message).map((choice) => choice.label),
		["mermaid", "java", "whole message"],
	);
});

test("supports tilde fences and longer closing fences", () => {
	const message = ["~~~~python", "print('```')", "~~~~~"].join("\n");

	assert.deepEqual(extractFencedCodeBlocks(message), [
		{ language: "python", text: "print('```')" },
	]);
});

test("creates distinct labels for unlabelled and repeated blocks", () => {
	const message = [
		"```",
		"plain",
		"```",
		"```java",
		"first",
		"```",
		"```java",
		"second",
		"```",
	].join("\n");

	assert.deepEqual(
		buildCopyChoices(message).map((choice) => choice.label),
		["code block 1", "java", "java (2)", "whole message"],
	);
});

test("ignores an unclosed fence", () => {
	assert.deepEqual(extractFencedCodeBlocks("before\n```js\nconst value = 1;"), []);
});

test("offers the whole message when there are no code blocks", () => {
	assert.deepEqual(buildCopyChoices("plain response"), [
		{ label: "whole message", text: "plain response" },
	]);
});
