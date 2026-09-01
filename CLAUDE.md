# skills

Public collection of agent skills, shipped as a single Claude Code plugin
(`meteof-skills`) that is also its own marketplace. Private counterpart:
`../skills-private`.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest; the plugin entry uses
  `"source": "./"` because the repo root *is* the plugin.
- `.claude-plugin/plugin.json` — plugin manifest. Bump `version` on every release.
- `skills/<name>/SKILL.md` — one directory per skill. Nothing else in `skills/`
  belongs there: every subdirectory is loaded as a skill, so templates and scratch
  files live in `templates/`, not here.
- `templates/skill/` — starting point for a new skill.

## Rules

- The frontmatter `description` is the whole triggering surface. Write it as
  "use when …" plus the literal words a user would type. A vague description means
  the skill never loads.
- Do not restate a skill's content in `README.md` — link to it. The table there
  carries one line per skill and its license.
- A skill carrying an upstream license keeps its own `LICENSE` file inside its
  directory and is listed in the README licensing section. The repo default is MIT.
- Validate before committing: `claude plugin validate .`
- Anything with client names, credentials, or internal TKB/Knigomag specifics goes
  to `../skills-private`, not here.
