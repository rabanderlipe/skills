# Roles and models

Spawn a role only when its output can change a decision. Name every teammate exactly as below so messages and the quality gate find them.

| Name | Agent type | Spawn when | Skip when | Default model |
|---|---|---|---|---|
| `pm` | `agent-team:pm` | Full shape | Pair or Solo (you write the criteria) | sonnet; opus if the request conflicts with the spec or touches security or permissions |
| `researcher` | `agent-team:researcher` | the work depends on facts the repo can't confirm: an external API, a platform limit, a data source, a standard | the answer is in the repo or an existing research doc | sonnet; haiku for a single lookup; opus for contested or high-stakes questions |
| `tech-lead` | `agent-team:tech-lead` | Full shape | Pair (you plan the single task) | opus |
| `advocate` | `agent-team:devils-advocate` | the plan has two or more engineering tasks, or touches data, permissions or money | one small task | opus |
| `eng-1`, `eng-2`, … | `agent-team:engineer` | one per engineering task | never share a task between engineers | from the tech-lead's plan (below) |
| reviewer names from `.claude/team.md` | the agent type listed there | the change touches that reviewer's lens | it doesn't | that agent's own model |
| `security` | `agent-team:security` | the change touches authentication, authorization, permissions, secrets, user input handling or data exposure | it doesn't | opus |
| `qa` | `agent-team:qa` | always, once there is a change | never | sonnet; haiku when only re-running known suites after a small fix |
| `writer` | `agent-team:tech-writer` | behaviour, commands, setup or conventions that docs describe changed | no doc is affected | sonnet; haiku for a one-line fix |

## Model policy

The model named in the spawn prompt overrides the agent definition's `model:`, which is only a fallback (unless the user set `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`, which pins every teammate to one model). Name a model in every spawn prompt and choose it by what the task needs:

- **opus**: ambiguity or cross-cutting judgement: architecture, security, permissions, schema or data migrations, concurrency, money or date math, a bug with no known cause, adversarial review.
- **sonnet**: well-specified work: a feature with a clear contract, UI from a given design, tests for given criteria, QA, scoping against a spec, research with clear sources.
- **haiku**: mechanical, fully specified work: copy edits, renames, a one-line fix at a known location, re-running known commands.

`.claude/team.md` model overrides win. Escalation: haiku → sonnet → opus. A task that fails on opus goes back to the tech-lead for a different split, or to the user.
