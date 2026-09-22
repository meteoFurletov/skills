# skills

Public collection of agent skills, shipped as the `meteof-skills` Claude Code
plugin from a marketplace that lives in this repo. The marketplace also lists
`balka`, which lives in its own repo (`../balka`). Private counterpart:
`../skills-private`.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest, one entry per plugin.
  The `meteof-skills` entry uses `"source": "./"` because the repo root *is* that
  plugin; `balka` points at `meteoFurletov/balka` by GitHub source.
- `.claude-plugin/plugin.json` — the `meteof-skills` manifest. Bump `version` on
  every release.
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
- `balka` versions in its own repo. Its entry here changes only when its name,
  source or description does.
- Validate before committing: `claude plugin validate .`
- An installed plugin's skill descriptions load into every session. Keep the
  count low and the wording tight.
- Anything with client names, credentials, or internal TKB/Knigomag specifics goes
  to `../skills-private`, not here.
