from __future__ import annotations

import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parent / "scripts" / "glab-board"


class GlabBoardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.repo = self.root / "repo"
        self.log = self.root / "calls.jsonl"
        self.bin.mkdir()
        self.repo.mkdir()
        agent_link = self.home / "dotfiles" / "scripts" / "bin" / "agent-link"
        agent_link.parent.mkdir(parents=True)
        agent_link.write_text("#!/bin/sh\nprintf '%s\\n' \"agent-link $*\" >> \"$FAKE_TEXT_LOG\"\n")
        agent_link.chmod(0o755)
        self._write_fake_git()
        self._write_fake_glab()
        self._write_fake_gh()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _write_executable(self, name: str, body: str) -> None:
        path = self.bin / name
        path.write_text(textwrap.dedent(body))
        path.chmod(0o755)

    def _write_fake_git(self) -> None:
        self._write_executable(
            "git",
            r'''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write(json.dumps(["git", *args]) + "\n")
if args[:2] == ["remote", "get-url"]:
    print(os.environ.get("FAKE_REMOTE", "git@gitlab.example.com:group/project.git"))
elif args[:2] == ["branch", "--show-current"]:
    print(os.environ.get("FAKE_BRANCH", "issue-103-player-card"))
elif args and args[0] == "symbolic-ref":
    print("refs/remotes/origin/main")
elif args[:2] == ["status", "--porcelain"]:
    print(os.environ.get("FAKE_STATUS", ""), end="")
elif args[:2] == ["rev-list", "--count"]:
    print(os.environ.get("FAKE_AHEAD", "1"))
elif args[:3] == ["worktree", "list", "--porcelain"]:
    existing = os.environ.get("FAKE_EXISTING_WORKTREE")
    if existing:
        print(f"worktree {existing}\nHEAD deadbeef\nbranch refs/heads/{os.environ['FAKE_BRANCH']}")
elif args[:2] == ["worktree", "add"]:
    # Last two arguments are destination and start point.
    destination = pathlib.Path(args[-2])
    destination.mkdir(parents=True, exist_ok=True)
elif args and args[0] == "show-ref":
    raise SystemExit(1)
''',
        )

    def _write_fake_glab(self) -> None:
        self._write_executable(
            "glab",
            r'''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write(json.dumps(["glab", *args]) + "\n")
if args[:2] == ["api", "user"]:
    print(json.dumps({"id": 7}))
elif args[:2] == ["api", "projects/group%2Fproject/boards"]:
    print(json.dumps([{"id": 12}]))
elif args[:2] == ["api", "projects/group%2Fproject/labels?per_page=100"]:
    names = [
        "triage::pending",
        "agent::ready",
        "agent::ready-research",
        "agent::working",
        "agent::researching",
        "agent::parked",
        "agent::mr-ready",
        "agent::failed",
        "agent::for-human",
    ]
    print(json.dumps([{"id": 101 + i, "name": name} for i, name in enumerate(names)]))
elif args[:2] == ["api", "projects/group%2Fproject/boards/12/lists"]:
    print(json.dumps([{"label": {"id": 104, "name": "agent::working"}}]))
elif args and args[0] == "api" and "/issues/" in args[1] and "-X" not in args:
    iid = int(args[1].rsplit("/", 1)[-1])
    print(json.dumps({"iid": iid, "title": "Add async player card", "web_url": f"https://gitlab.example.com/group/project/-/issues/{iid}"}))
elif args and args[0] == "api" and "merge_requests?" in args[1]:
    print("[]")
elif args and args[0] == "api" and "/merge_requests/74" in args[1]:
    print(json.dumps({
        "source_branch": os.environ.get("FAKE_BRANCH", "issue-103-player-card"),
        "target_branch": "main",
        "draft": os.environ.get("FAKE_DRAFT") == "1",
        "changes_count": "4",
        "web_url": "https://gitlab.example.com/group/project/-/merge_requests/74",
    }))
elif args[:2] == ["mr", "create"]:
    print("https://gitlab.example.com/group/project/-/merge_requests/74")
''',
        )

    def _write_fake_gh(self) -> None:
        self._write_executable(
            "gh",
            r'''#!/usr/bin/env python3
import json, os, re, sys
args = sys.argv[1:]
payload = {}
if "--input" in args:
    payload = json.load(sys.stdin)
query = payload.get("query", "")
if not query:
    query = next((arg.removeprefix("query=") for arg in args if arg.startswith("query=")), "")
match = re.search(r"\b(?:query|mutation)\s+(\w+)", query)
operation = match.group(1) if match else ""
call = ["gh", *args]
if operation:
    call.append(f"operation={operation}")
mutation = re.search(r"\b(createProjectV2|linkProjectV2ToRepository|updateProjectV2Field)\b", query)
if mutation:
    call.append(f"mutation={mutation.group(1)}")
if payload.get("variables"):
    call.append("variables=" + json.dumps(payload["variables"], sort_keys=True))
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write(json.dumps(call) + "\n")

if args[:2] == ["label", "edit"]:
    raise SystemExit(1)
if args[:2] != ["api", "graphql"]:
    raise SystemExit(0)

project_state = os.environ.get("FAKE_GITHUB_PROJECT", "fresh")
if operation == "BootstrapProject":
    projects = []
    if project_state in {"existing", "customized"}:
        projects.append({"id": "PVT_existing", "title": "project board"})
    print(json.dumps({"data": {
        "viewer": {"id": "U_viewer"},
        "repository": {
            "id": "R_project",
            "projectsV2": {"nodes": projects},
        },
    }}))
elif operation == "CreateProject":
    print(json.dumps({"data": {"createProjectV2": {"projectV2": {"id": "PVT_created"}}}}))
elif operation == "LinkProject":
    print(json.dumps({"data": {"linkProjectV2ToRepository": {"repository": {"id": "R_project"}}}}))
elif operation == "ProjectStatus":
    desired = [
        "Triage",
        "Ready",
        "Ready-research",
        "Working",
        "Researching",
        "Parked",
        "Review",
        "Failed",
        "For-human",
    ]
    if project_state == "existing":
        names = desired
    elif project_state == "customized":
        names = ["Backlog", "Doing", "Done"]
    else:
        names = ["Todo", "In Progress", "Done"]
    print(json.dumps({"data": {"node": {"fields": {"nodes": [{
        "id": "PVTSSF_status",
        "name": "Status",
        "options": [{"name": name} for name in names],
    }]}}}}))
elif operation == "UpdateStatus":
    print(json.dumps({"data": {"updateProjectV2Field": {"projectV2Field": {"id": "PVTSSF_status"}}}}))
else:
    raise SystemExit(f"unexpected GraphQL operation: {operation}")
''',
        )

    def run_script(self, *args: str, extra_env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env.update(
            {
                "HOME": str(self.home),
                "PATH": f"{self.bin}:/usr/bin:/bin",
                "WORKTREE_ROOT": str(self.root / "worktrees"),
                "FAKE_LOG": str(self.log),
                "FAKE_TEXT_LOG": str(self.root / "calls.txt"),
                "FAKE_BRANCH": "issue-103-player-card",
                "FAKE_REMOTE": "git@gitlab.example.com:group/project.git",
            }
        )
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            [str(SCRIPT), *args],
            cwd=self.repo,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def calls(self) -> list[list[str]]:
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_setup_migrates_creates_and_adds_gitlab_board_lists(self) -> None:
        result = self.run_script("setup")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        legacy_triage = "-".join(("needs", "triage"))
        self.assertIn(
            [
                "glab",
                "api",
                "-X",
                "PUT",
                "projects/group%2Fproject/labels",
                "-f",
                f"name={legacy_triage}",
                "-f",
                "new_name=triage::pending",
            ],
            calls,
        )
        create = next(
            call
            for call in calls
            if call[:5]
            == ["glab", "api", "-X", "POST", "projects/group%2Fproject/labels"]
            and "name=agent::mr-ready" in call
        )
        self.assertIn("color=#6f42c1", create)
        list_calls = [
            call
            for call in calls
            if call[:5]
            == [
                "glab",
                "api",
                "-X",
                "POST",
                "projects/group%2Fproject/boards/12/lists",
            ]
        ]
        self.assertEqual(
            [call[-1] for call in list_calls],
            [
                "label_id=101",
                "label_id=102",
                "label_id=103",
                "label_id=105",
                "label_id=106",
                "label_id=107",
                "label_id=108",
                "label_id=109",
            ],
        )
        self.assertIn("skipped: list agent::working (already exists)", result.stdout)

    def test_setup_github_creates_links_and_sets_fresh_project_status(self) -> None:
        result = self.run_script(
            "setup",
            "--board",
            extra_env={"FAKE_REMOTE": "git@github.com:group/project.git"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        mutations = [
            marker.removeprefix("mutation=")
            for call in self.calls()
            for marker in call
            if marker.startswith("mutation=")
        ]
        self.assertEqual(
            mutations,
            ["createProjectV2", "linkProjectV2ToRepository", "updateProjectV2Field"],
        )
        update = next(call for call in self.calls() if "operation=UpdateStatus" in call)
        variables = json.loads(next(value.removeprefix("variables=") for value in update if value.startswith("variables=")))
        self.assertEqual(
            [(option["name"], option["color"], option["description"]) for option in variables["options"]],
            [
                ("Triage", "YELLOW", ""),
                ("Ready", "GREEN", ""),
                ("Ready-research", "GREEN", ""),
                ("Working", "BLUE", ""),
                ("Researching", "BLUE", ""),
                ("Parked", "ORANGE", ""),
                ("Review", "PURPLE", ""),
                ("Failed", "RED", ""),
                ("For-human", "GRAY", ""),
            ],
        )
        self.assertIn("created: project project board", result.stdout)
        self.assertIn("linked: project project board to group/project", result.stdout)
        self.assertIn("set: status lanes (9)", result.stdout)

    def test_setup_github_default_is_queue_only(self) -> None:
        result = self.run_script(
            "setup",
            extra_env={"FAKE_REMOTE": "git@github.com:group/project.git"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("labels bootstrapped (queue-only)", result.stdout)
        self.assertFalse(any("mutation=" in marker for call in self.calls() for marker in call))

    def test_setup_github_reuses_existing_project(self) -> None:
        result = self.run_script(
            "setup",
            "--board",
            extra_env={
                "FAKE_REMOTE": "git@github.com:group/project.git",
                "FAKE_GITHUB_PROJECT": "existing",
            },
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertIn("skipped: project project board (already linked)", result.stdout)
        self.assertIn("skipped: status lanes (already set)", result.stdout)
        self.assertFalse(any("operation=CreateProject" in call for call in calls))
        self.assertFalse(any("operation=LinkProject" in call for call in calls))

    def test_setup_github_preserves_customized_status(self) -> None:
        result = self.run_script(
            "setup",
            "--board",
            extra_env={
                "FAKE_REMOTE": "git@github.com:group/project.git",
                "FAKE_GITHUB_PROJECT": "customized",
            },
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("warning: status lanes are customized; leaving them unchanged", result.stderr)
        self.assertFalse(any("operation=UpdateStatus" in call for call in self.calls()))

    def test_close_clears_every_agent_label_github(self) -> None:
        result = self.run_script(
            "close",
            "7",
            extra_env={"FAKE_REMOTE": "git@github.com:group/project.git"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        removed = [
            call[call.index("--remove-label") + 1]
            for call in self.calls()
            if call[:3] == ["gh", "issue", "edit"] and "--remove-label" in call
        ]
        self.assertEqual(
            sorted(removed),
            sorted([
                "agent::ready",
                "agent::ready-research",
                "agent::working",
                "agent::researching",
                "agent::parked",
                "agent::mr-ready",
                "agent::failed",
                "agent::for-human",
            ]),
        )

    def test_close_clears_every_agent_label_gitlab(self) -> None:
        result = self.run_script("close", "7")
        self.assertEqual(result.returncode, 0, result.stderr)
        put = next(
            call for call in self.calls()
            if call[:2] == ["glab", "api"] and any("state_event=close" in part for part in call)
        )
        removal = next(part for part in put if part.startswith("remove_labels="))
        self.assertEqual(
            sorted(removal.removeprefix("remove_labels=").split(",")),
            sorted([
                "agent::ready",
                "agent::ready-research",
                "agent::working",
                "agent::researching",
                "agent::parked",
                "agent::mr-ready",
                "agent::failed",
                "agent::for-human",
            ]),
        )

    def test_mr_pins_current_source_and_default_target_then_verifies(self) -> None:
        result = self.run_script("mr", "--title", "Player card", "--yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        create = next(call for call in self.calls() if call[:3] == ["glab", "mr", "create"])
        self.assertIn("--source-branch", create)
        self.assertEqual(create[create.index("--source-branch") + 1], "issue-103-player-card")
        self.assertIn("--target-branch", create)
        self.assertEqual(create[create.index("--target-branch") + 1], "main")
        self.assertIn("verified MR:", result.stdout)
        self.assertIn("agent-link add mr", (self.root / "calls.txt").read_text())

    def test_mr_rejects_source_that_differs_from_current_branch(self) -> None:
        result = self.run_script("mr", "--source-branch", "wrong-branch", "--title", "Bad")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match current branch", result.stderr)
        self.assertFalse(any(call[:3] == ["glab", "mr", "create"] for call in self.calls()))

    def test_start_creates_worktree_claims_issue_and_returns_json(self) -> None:
        result = self.run_script("start", "103", "--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["issue"], 103)
        self.assertEqual(payload["branch"], "issue-103-add-async-player-card")
        self.assertTrue(Path(payload["worktree"]).is_dir())
        self.assertIn("grabbed #103", result.stderr)
        self.assertIn("agent-link issue", (self.root / "calls.txt").read_text())

    def test_start_warns_but_excludes_dirty_shared_checkout(self) -> None:
        result = self.run_script("start", "103", "--json", extra_env={"FAKE_STATUS": " M AGENTS.md\n"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("shared checkout is dirty", result.stderr)
        self.assertTrue(Path(json.loads(result.stdout)["worktree"]).is_dir())

    def test_finish_runs_repo_verifier_and_creates_ready_mr(self) -> None:
        verifier = self.repo / "scripts" / "verify-agent-change"
        verifier.parent.mkdir()
        verifier.write_text("#!/bin/sh\necho verified > \"$FAKE_VERIFY_LOG\"\n")
        verifier.chmod(0o755)
        result = self.run_script(
            "finish",
            "103",
            extra_env={"FAKE_VERIFY_LOG": str(self.root / "verify.log")},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "verify.log").read_text().strip(), "verified")
        create = next(call for call in self.calls() if call[:3] == ["glab", "mr", "create"])
        self.assertNotIn("--draft", create)
        self.assertIn("finished #103", result.stdout)


if __name__ == "__main__":
    unittest.main()
