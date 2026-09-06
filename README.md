# skills

Agent skills and process tooling I reuse across projects, shipped as two plugins
from one marketplace — install either, and updates arrive together.

Private / unshareable skills live in the sibling repo `skills-private`.

## Install

```bash
claude plugin marketplace add meteoFurletov/skills
claude plugin install meteof-skills@meteof-skills
claude plugin install sdlc-loop@meteof-skills
```

Or, from inside a Claude Code session, `/plugin marketplace add meteoFurletov/skills`
then `/plugin install <name>@meteof-skills`.

## Plugins

| Plugin | What it is |
| --- | --- |
| `meteof-skills` | The skills below. The repo root is this plugin. |
| [sdlc-loop](plugins/sdlc-loop/) | A six-stage AI-native SDLC — intent, spec with Gherkin scenarios, plan, build, review, watch — as slash commands with opt-in hooks. |

To work on a skill locally without installing, symlink it:

```bash
ln -s ~/Projects/skills/skills/<name> ~/.claude/skills/<name>
```

## Skills

Shipped in `meteof-skills`.

| Skill | What it does | License |
| --- | --- | --- |
| [modern-sql-style](skills/modern-sql-style/) | SQL formatting and naming conventions for DML and DDL — lowercase keywords, river alignment, leading commas, column-aligned ClickHouse DDL. | CC BY-SA 4.0 |
| [remarkable-pdf](skills/remarkable-pdf/) | Laying out readable PDFs for the reMarkable Paper Pro e-ink screen — page geometry, typography, KaTeX math, bookmarks. | MIT |
| [cloud-agent-workstation](skills/cloud-agent-workstation/) | Building, operating and tearing down a personal always-on cloud box that runs a self-hosted AI agent. Ships runnable Terraform (EC2 + EIP + cloud-init) plus runbooks for provisioning, troubleshooting and teardown. | MIT |

## Adding a skill

1. `cp -r templates/skill skills/<name>` and fill in `SKILL.md`.
2. Write the frontmatter `description` for *triggering* — it is the only thing an
   agent sees when deciding whether to load the skill. Say when to use it and name
   the concrete words a user would type. See the two existing skills for the shape.
3. Validate: `claude plugin validate .`
4. Bump `version` in `.claude-plugin/plugin.json` and commit.

Skills are portable across agents that follow the
[agent skills spec](https://agentskills.io) — Claude Code, Copilot, Cursor, Windsurf.

## Licensing

The repo is MIT by default (see [LICENSE](LICENSE)). Individual skills may differ
where an upstream source requires it — a skill with its own `LICENSE` file is
governed by that file. `modern-sql-style` is CC BY-SA 4.0 because it derives from
[mattmc3's Modern SQL Style Guide](https://gist.github.com/mattmc3/38a85e6a4ca1093816c08d4815fbebfb).
