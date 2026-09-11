import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts" / "agent-link-skills.sh"


class SkillLinksTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="agentainer-skills-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "persistent home"
        self.skills = self.root / "image skills"
        shutil.copytree(REPO / "skills", self.skills)
        self.add_skill("playwright-cli", "Playwright version 1")
        self.env = {**os.environ, "AGENT_SKILLS_DIR": str(self.skills)}

    def add_skill(self, name, content):
        path = self.skills / name / "SKILL.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def run_links(self, check=True):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.home)],
            env=self.env, check=check, capture_output=True, text=True,
        )

    def test_fresh_home_and_repeated_start(self):
        self.run_links()
        for tool in (".agents", ".claude"):
            for name in ("playwright-cli", "unslop"):
                link = self.home / tool / "skills" / name
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), self.skills / name)
        for relative in (".codex/AGENTS.md", ".claude/CLAUDE.md", ".gemini/GEMINI.md"):
            link = self.home / relative
            self.assertTrue(link.is_symlink())
            self.assertEqual(link.read_text(), (self.skills / "AGENTS.md").read_text())
        self.assertEqual(self.run_links().stdout, "")
        self.assertFalse((self.home / ".local/state/agent/skill-backups").exists())

    def test_existing_home_is_migrated_without_losing_user_data(self):
        previous = {
            ".agents/skills/playwright-cli/SKILL.md": "old Playwright",
            ".claude/skills/playwright-cli/SKILL.md": "old Claude skill",
            ".codex/AGENTS.md": "personal instructions",
            ".claude/CLAUDE.md": "Claude instructions",
            ".gemini/GEMINI.md": "Gemini instructions",
        }
        untouched = {
            ".codex/auth.json": '{"test-token": "dummy"}',
            ".claude/settings.json": "{}",
            ".agents/skills/personal/SKILL.md": "personal skill",
        }
        for relative, content in {**previous, **untouched}.items():
            path = self.home / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        self.run_links()
        backups = list((self.home / ".local/state/agent/skill-backups").iterdir())
        self.assertEqual(len(backups), 1)
        for relative, content in previous.items():
            self.assertEqual((backups[0] / relative).read_text(), content)
        for relative, content in untouched.items():
            self.assertEqual((self.home / relative).read_text(), content)
        self.run_links()
        self.assertEqual(list(backups[0].parent.iterdir()), backups)

    def test_new_image_changes_additions_and_removals(self):
        self.run_links()
        self.add_skill("playwright-cli", "Playwright version 2")
        (self.skills / "AGENTS.md").write_text("New image instructions")
        self.add_skill("new-skill", "New skill")
        shutil.rmtree(self.skills / "unslop")
        personal_link = self.home / ".agents/skills/personal"
        personal_link.symlink_to(self.root / "unavailable-personal-skill")
        self.run_links()
        for tool in (".agents", ".claude"):
            base = self.home / tool / "skills"
            self.assertEqual((base / "playwright-cli/SKILL.md").read_text(), "Playwright version 2")
            self.assertEqual((base / "new-skill/SKILL.md").read_text(), "New skill")
            self.assertFalse((base / "unslop").is_symlink())
        self.assertEqual((self.home / ".codex/AGENTS.md").read_text(), "New image instructions")
        self.assertTrue(personal_link.is_symlink())

    def test_conflicting_symlink_is_backed_up_without_changing_its_target(self):
        original = self.root / "personal-instructions.md"
        original.write_text("personal instructions")
        destination = self.home / ".codex/AGENTS.md"
        destination.parent.mkdir(parents=True)
        destination.symlink_to(original)
        self.run_links()
        self.assertEqual(original.read_text(), "personal instructions")
        backups = list(self.home.glob(".local/state/agent/skill-backups/*/.codex/AGENTS.md"))
        self.assertEqual(len(backups), 1)
        self.assertTrue(backups[0].is_symlink())
        self.assertEqual(backups[0].resolve(), original)

    def test_previous_image_links_are_migrated(self):
        instruction_paths = (".codex/AGENTS.md", ".claude/CLAUDE.md", ".gemini/GEMINI.md")
        for relative in instruction_paths:
            link = self.home / relative
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(self.skills / "agents.md")
        for tool in (".agents", ".claude"):
            old_skill = self.home / tool / "skills/example-workspace-overview"
            old_skill.parent.mkdir(parents=True, exist_ok=True)
            old_skill.symlink_to(self.skills / "example-workspace-overview")
        self.run_links()
        for relative in instruction_paths:
            self.assertEqual((self.home / relative).resolve(), self.skills / "AGENTS.md")
        for tool in (".agents", ".claude"):
            base = self.home / tool / "skills"
            self.assertFalse((base / "example-workspace-overview").is_symlink())
            self.assertEqual((base / "unslop").resolve(), self.skills / "unslop")
        self.assertEqual(self.run_links().stdout, "")

    def test_incomplete_image_fails_before_modifying_home(self):
        (self.skills / "AGENTS.md").unlink()
        result = self.run_links(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing image-provided", result.stderr)
        self.assertFalse(self.home.exists())


if __name__ == "__main__":
    unittest.main()
