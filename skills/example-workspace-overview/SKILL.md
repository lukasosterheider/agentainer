---
name: example-workspace-overview
description: Summarize the projects in an Agentainer workspace when the user asks which projects are available or wants a workspace overview.
---

# Workspace overview

Use the workspace path supplied by the user, or `/workspace` by default.
Check for a `Projects` subdirectory before looking for repositories directly
under the workspace. Preserve the actual spelling of existing paths.

Identify candidate projects from their top-level directories and Git markers.
Read each project's README and package/build manifest only as needed to report
its purpose, main technology, and documented start command. Do not install
dependencies or start applications just to produce the overview.

Return a compact table with the project name, path, purpose, and start command.
Mark missing documentation as unknown instead of guessing a command. If no
projects are present, report which directory was checked.
