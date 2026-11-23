"""Run with python3 tests/taction.py; no extra dependencies required."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class ChangedFilesTest(unittest.TestCase):
    def test_pr_excludes_newer_base_changes(self):
        action = (Path(__file__).resolve().parents[1] / "action.yml").read_text()
        step = action.split("    - name: Lint changed files\n", 1)[1]
        head_expression = next(
            line.strip() for line in step.splitlines() if line.strip().startswith("HEAD:")
        )
        self.assertEqual(
            head_expression,
            "HEAD: ${{ github.event.pull_request.head.sha || github.sha }}",
        )
        script = "\n".join(line[8:] for line in step.split("      run: |\n", 1)[1].splitlines())

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def git(*args):
                return subprocess.check_output(
                    ["git", "-c", "commit.gpgsign=false", *args], cwd=root, text=True, stderr=subprocess.STDOUT
                ).strip()

            def commit_file(name):
                (root / name).write_text("discard\n")
                git("add", name)
                git("commit", "-qm", name)
                return git("rev-parse", "HEAD")

            git("init", "-q")
            git("config", "user.name", "Action test")
            git("config", "user.email", "action-test@example.invalid")
            base = commit_file("base.nim")
            git("checkout", "-qb", "pr")
            pr_head = commit_file("changed.nim")
            git("checkout", "-qb", "new-base", base)
            commit_file("unrelated.nim")
            git("merge", "--no-ff", "-m", "Synthetic PR merge", "pr")
            merge_head = git("rev-parse", "HEAD")

            cache = root / ".lint-cache"
            cache.mkdir()
            linter = cache / "linter"
            linter.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$CAPTURE"\n')
            linter.chmod(0o755)
            capture = root / "arguments"

            # Execute the action's actual script while the merge remains checked out.
            # PRs use the PR head; merge queues and pushes retain github.sha.
            for head, expected in [
                (pr_head, ["--format=github", "--semantic", "changed.nim"]),
                (merge_head, ["--format=github", "--semantic", "changed.nim", "unrelated.nim"]),
            ]:
                with self.subTest(head=head):
                    subprocess.run(
                        ["bash", "-eo", "pipefail", "-c", script],
                        cwd=root,
                        env=dict(os.environ, BASE=base, HEAD=head, SEMANTIC="true", CAPTURE=str(capture)),
                        check=True,
                        capture_output=True,
                    )
                    self.assertEqual(capture.read_text().splitlines(), expected)
                    self.assertEqual(git("rev-parse", "HEAD"), merge_head)


if __name__ == "__main__":
    unittest.main()
