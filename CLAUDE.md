# skills

Public collection of agent skills and process tooling, shipped as two Claude
Code plugins from a marketplace that lives in this repo. Private counterpart:
`../skills-private`.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest, one entry per plugin.
  The `meteof-skills` entry uses `"source": "./"` because the repo root *is* that
  plugin; anything else lives at `plugins/<name>/` with a matching source.
- `.claude-plugin/plugin.json` — the `meteof-skills` manifest. Bump `version` on
  every release.
- `skills/<name>/SKILL.md` — one directory per skill. Nothing else in `skills/`
  belongs there: every subdirectory is loaded as a skill, so templates and scratch
  files live in `templates/`, not here.
- `templates/skill/` — starting point for a new skill.
- `plugins/sdlc-loop/` — a plugin, not a skill. Self-contained; what it does and
  how it works is in its own `README.md`, not here.

## Rules

- The frontmatter `description` is the whole triggering surface. Write it as
  "use when …" plus the literal words a user would type. A vague description means
  the skill never loads.
- Do not restate a skill's content in `README.md` — link to it. The table there
  carries one line per skill and its license.
- A skill carrying an upstream license keeps its own `LICENSE` file inside its
  directory and is listed in the README licensing section. The repo default is MIT.
- Each plugin versions independently. A release of one must not touch the other's
  manifest.
- Validate before committing: `claude plugin validate .` and
  `claude plugin validate plugins/<name>` for each plugin under `plugins/`.
- A plugin's own tests run from its directory — `bash plugins/<name>/tests/run.sh`.
- `plugins/*/skills/` costs nothing in a session without that plugin installed,
  but an installed plugin's skill descriptions load into every session. Keep the
  count low and the wording tight.
- Anything with client names, credentials, or internal TKB/Knigomag specifics goes
  to `../skills-private`, not here.
