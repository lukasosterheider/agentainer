# Agentainer environment

Projects and working files belong under `/workspace`, which is persistent.
Keep an existing project's path; repositories may be grouped under
`/workspace/Projects`.

The shared skills under `/opt/agent/skills` are supplied by the container image.
To change a bundled skill or these instructions, edit the Agentainer repository's
`skills/` directory and rebuild the image. Put project-specific instructions in
the project's own instruction files.

Development servers must listen on `0.0.0.0` to be reachable through the
container's NetBird address. Use the project's documented development command
and port when available.
