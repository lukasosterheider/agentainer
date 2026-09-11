#!/usr/bin/env bash
set -Eeuo pipefail

agent_home=${1:-/home/agent}
skills_dir=${AGENT_SKILLS_DIR:-/opt/agent/skills}
skills_dir=${skills_dir%/}
backup_dir=

if [[ ! -f "$skills_dir/AGENTS.md" || ! -f "$skills_dir/playwright-cli/SKILL.md" ]]; then
    echo "ERROR: Missing image-provided skills or AGENTS.md in $skills_dir" >&2
    exit 1
fi

link_file() {
    local source=$1 destination=$2 backup_path
    mkdir -p -- "$(dirname -- "$destination")"
    if [[ -L "$destination" && $(readlink -- "$destination") == "$source" ]]; then
        return
    fi
    if [[ -e "$destination" || -L "$destination" ]]; then
        # Keep prior copies outside skill discovery paths, once per migration.
        if [[ -z "$backup_dir" ]]; then
            mkdir -p -- "$agent_home/.local/state/agent/skill-backups"
            backup_dir=$(mktemp -d "$agent_home/.local/state/agent/skill-backups/migration.XXXXXXXX")
        fi
        backup_path="$backup_dir/${destination#"$agent_home/"}"
        mkdir -p -- "$(dirname -- "$backup_path")"
        mv -T -- "$destination" "$backup_path"
        printf 'Backed up %s to %s\n' "$destination" "$backup_path"
    fi
    ln -sT -- "$source" "$destination"
}

for relative_dir in .agents/skills .claude/skills; do
    target_dir="$agent_home/$relative_dir"
    mkdir -p -- "$target_dir"

    # Remove only our links to skills that no longer ship in the image.
    for target in "$target_dir"/*; do
        if [[ -L "$target" && $(readlink -- "$target") == "$skills_dir/${target##*/}" \
            && ! -f "$target/SKILL.md" ]]; then
            rm -- "$target"
        fi
    done

    for skill in "$skills_dir"/*; do
        [[ -d "$skill" && -f "$skill/SKILL.md" ]] || continue
        link_file "$skill" "$target_dir/${skill##*/}"
    done
done

link_file "$skills_dir/AGENTS.md" "$agent_home/.codex/AGENTS.md"
link_file "$skills_dir/AGENTS.md" "$agent_home/.claude/CLAUDE.md"
link_file "$skills_dir/AGENTS.md" "$agent_home/.gemini/GEMINI.md"
