import {
	findChar,
	findCharBackward,
	findCharForward,
	nextWORDEnd,
	nextWORDStart,
	nextWordEnd,
	nextWordStart,
	previousWORDEnd,
	previousWORDStart,
	previousWordEnd,
	previousWordStart,
} from "./index.ts";

let failures = 0;

function assertEqual(actual: unknown, expected: unknown, label: string) {
	const pass = actual === expected;
	console.log(`${pass ? "PASS" : "FAIL"}: ${label}`);
	if (!pass) {
		console.log(`  expected ${String(expected)}, got ${String(actual)}`);
		failures += 1;
	}
}

function applyCount(scan: (text: string, offset: number) => number, text: string, offset: number, count: number): number {
	let result = offset;
	for (let i = 0; i < count; i += 1) result = scan(text, result);
	return result;
}

const mixed = "foo.bar-baz  qux";

assertEqual(nextWordStart(mixed, 0), 3, "w stops at punctuation run");
assertEqual(nextWORDStart(mixed, 0), 13, "W crosses punctuation inside WORD");
assertEqual(applyCount(nextWordStart, mixed, 0, 4), 8, "counted w traverses word classes");
assertEqual(applyCount(nextWORDStart, mixed, 0, 2), mixed.length, "counted W reaches end of text");
assertEqual(previousWordStart(mixed, 13), 8, "b finds previous lowercase word start");
assertEqual(previousWORDStart(mixed, 13), 0, "B finds previous WORD start");
assertEqual(applyCount(previousWordStart, mixed, mixed.length, 3), 7, "counted b traverses punctuation");
assertEqual(nextWordEnd(mixed, 0), 2, "e finds current word end");
assertEqual(nextWordEnd(mixed, 2), 3, "e advances from a word end");
assertEqual(nextWORDEnd(mixed, 0), 10, "E finds current WORD end");
assertEqual(applyCount(nextWordEnd, mixed, 0, 3), 6, "counted e traverses word classes");
assertEqual(applyCount(nextWORDEnd, mixed, 0, 2), 15, "counted E traverses WORDs");
assertEqual(previousWordEnd(mixed, 13), 10, "ge finds previous word end");
assertEqual(previousWordEnd(mixed, 10), 7, "ge crosses to punctuation end");
assertEqual(previousWORDEnd(mixed, 13), 10, "gE finds previous WORD end");
assertEqual(applyCount(previousWordEnd, mixed, 13, 3), 6, "counted ge traverses word classes");

const punctuation = "foo...bar";
assertEqual(nextWordStart(punctuation, 0), 3, "punctuation is its own maximal word run");
assertEqual(nextWordStart(punctuation, 3), 6, "w crosses a punctuation run");
assertEqual(nextWordEnd(punctuation, 3), 5, "e lands at punctuation run end");

const lines = "foo\nbar";
assertEqual(nextWordStart(lines, 0), 4, "w treats newline as whitespace");
assertEqual(previousWordStart(lines, 4), 0, "b crosses a newline boundary");
assertEqual(nextWordEnd(lines, 2), 6, "e crosses a newline boundary");
assertEqual(previousWordEnd(lines, 4), 2, "ge crosses a newline boundary");

assertEqual(nextWordStart("", 5), 0, "empty next-start clamps to zero");
assertEqual(previousWordStart("", -5), 0, "empty previous-start clamps to zero");
assertEqual(nextWordEnd("", 5), 0, "empty next-end clamps to zero");
assertEqual(previousWordEnd("", -5), 0, "empty previous-end clamps to zero");
assertEqual(nextWordStart("foo bar", -5), 4, "negative next-start offset clamps to start");
assertEqual(nextWordStart("foo bar", 99), 7, "next-start offset clamps to text end");
assertEqual(previousWordStart("foo bar", 99), 4, "previous-start offset clamps to text end");
assertEqual(nextWordEnd("foo bar", 99), 7, "next-end offset clamps to text end");
assertEqual(previousWordEnd("foo bar", -5), 0, "previous-end offset clamps to start");

const finds = "abacad\naxa";
assertEqual(findCharForward(finds, 0, "a"), 2, "f scan finds next occurrence");
assertEqual(findCharForward(finds, 0, "a", 2), 4, "counted f scan finds Nth occurrence");
assertEqual(findCharBackward(finds, 5, "a"), 4, "F scan finds previous occurrence");
assertEqual(findCharBackward(finds, 5, "a", 2), 2, "counted F scan finds Nth occurrence");
assertEqual(findChar(finds, 0, "f", "a"), 2, "f lands on target");
assertEqual(findChar(finds, 0, "t", "a"), 1, "t lands before target");
assertEqual(findChar(finds, 5, "F", "a"), 4, "F lands on target");
assertEqual(findChar(finds, 5, "T", "a"), 5, "T lands after target");
assertEqual(findChar("axaxa", 0, "t", "x", 1, true), 2, "repeated t skips adjacent target");
assertEqual(findChar("axaxa", 4, "T", "x", 1, true), 2, "repeated T skips adjacent target");
assertEqual(findCharForward(finds, 0, "x"), undefined, "forward find does not cross newline");
assertEqual(findCharBackward(finds, 8, "d"), undefined, "backward find does not cross newline");
assertEqual(findChar(finds, 0, "f", "z"), undefined, "failed find returns undefined");

process.exit(failures === 0 ? 0 : 1);
