import assert from "node:assert/strict";
import test from "node:test";
import {
	buildListCommand,
	extractIssueNumbers,
	findReferenceToken,
	formatReferenceItem,
	parseForgeRemote,
	parseReferenceList,
	referenceSearchText,
} from "./forge.ts";

test("parses GitHub SSH and HTTPS remotes", () => {
	assert.deepEqual(parseForgeRemote("git@github.com:owner/repo.git"), {
		forge: "github",
		host: "github.com",
		path: "owner/repo",
		selector: "owner/repo",
	});
	assert.deepEqual(parseForgeRemote("https://github.com/owner/repo.git"), {
		forge: "github",
		host: "github.com",
		path: "owner/repo",
		selector: "owner/repo",
	});
});

test("parses GitHub Enterprise remotes", () => {
	assert.deepEqual(parseForgeRemote("ssh://git@github.example.com/team/repo.git"), {
		forge: "github",
		host: "github.example.com",
		path: "team/repo",
		selector: "github.example.com/team/repo",
	});
});

test("parses GitLab and Autodesk GitLab remotes", () => {
	assert.deepEqual(parseForgeRemote("git@gitlab.ea.com:group/subgroup/repo.git"), {
		forge: "gitlab",
		host: "gitlab.ea.com",
		path: "group/subgroup/repo",
		selector: "https://gitlab.ea.com/group/subgroup/repo",
	});
	assert.deepEqual(parseForgeRemote("https://git.autodesk.com/group/repo.git"), {
		forge: "gitlab",
		host: "git.autodesk.com",
		path: "group/repo",
		selector: "https://git.autodesk.com/group/repo",
	});
});

test("rejects unsupported and local remotes", () => {
	assert.equal(parseForgeRemote("git@bitbucket.org:owner/repo.git"), undefined);
	assert.equal(parseForgeRemote("../repo"), undefined);
});

test("finds issue and MR tokens at start or after whitespace", () => {
	assert.deepEqual(findReferenceToken(["#auth"], 0, 5), {
		kind: "issue",
		marker: "#",
		query: "auth",
		prefix: "#auth",
	});

	const line = "please check !login";
	assert.deepEqual(findReferenceToken([line], 0, line.length), {
		kind: "merge-request",
		marker: "!",
		query: "login",
		prefix: "!login",
	});
});

test("does not treat language names or URL fragments as reference tokens", () => {
	assert.equal(findReferenceToken(["use C#"], 0, 6), undefined);
	const url = "https://example.com/page#section";
	assert.equal(findReferenceToken([url], 0, url.length), undefined);
});

test("builds GitHub and GitLab list commands", () => {
	const github = parseForgeRemote("git@github.com:owner/repo.git")!;
	assert.deepEqual(buildListCommand(github, "issue"), {
		command: "gh",
		args: [
			"issue",
			"list",
			"--repo",
			"owner/repo",
			"--state",
			"open",
			"--limit",
			"100",
			"--json",
			"number,title,state",
		],
	});

	const gitlab = parseForgeRemote("git@gitlab.ea.com:group/repo.git")!;
	assert.deepEqual(buildListCommand(gitlab, "merge-request"), {
		command: "glab",
		args: [
			"mr",
			"list",
			"--repo",
			"https://gitlab.ea.com/group/repo",
			"--per-page",
			"100",
			"--output",
			"json",
		],
	});
});

test("parses GitHub issues and PR relations", () => {
	assert.deepEqual(
		parseReferenceList(JSON.stringify([{ number: 14, title: "Fix auth", state: "OPEN" }]), "issue"),
		[{ kind: "issue", number: 14, title: "Fix auth", relatedIssues: [] }],
	);

	const prs = parseReferenceList(
		JSON.stringify([
			{
				number: 27,
				title: "Ship login flow",
				body: "Also follows up on #3 and https://github.com/owner/repo/issues/8",
				closingIssuesReferences: [{ number: 14 }, { number: 3 }],
			},
		]),
		"merge-request",
	);
	assert.deepEqual(prs, [
		{ kind: "merge-request", number: 27, title: "Ship login flow", relatedIssues: [14, 3, 8] },
	]);
});

test("parses GitLab iids and description issue references", () => {
	const references = parseReferenceList(
		JSON.stringify([
			{ iid: 31, title: "Add deploy gate", description: "Closes #9; related to #12" },
		]),
		"merge-request",
	);
	assert.deepEqual(references, [
		{ kind: "merge-request", number: 31, title: "Add deploy gate", relatedIssues: [9, 12] },
	]);
});

test("formats number-only insertions with picker metadata", () => {
	const reference = {
		kind: "merge-request" as const,
		number: 27,
		title: "Ship login flow",
		relatedIssues: [14, 3],
	};
	assert.deepEqual(formatReferenceItem(reference, "github"), {
		value: "!27",
		label: "!27",
		description: "[pr · issues #14, #3] Ship login flow",
	});
	assert.equal(referenceSearchText(reference), "27 Ship login flow #14 #3");
});

test("deduplicates issue references", () => {
	assert.deepEqual(extractIssueNumbers("Closes #14, follows #3 and #14"), [14, 3]);
});
