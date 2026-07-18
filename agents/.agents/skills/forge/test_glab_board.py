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
    print("git@gitlab.example.com:group/project.git")
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
