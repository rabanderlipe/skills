# Why the plugin works this way

Sources behind the design, checked 2026-10-09. Update this file when a design choice changes.

| Design choice | Evidence |
|---|---|
| Triage first; Solo for one-sentence or sequential changes | Multi-agent runs used ~15x the tokens of chat and suit parallel, independent work, not "most coding tasks" ([Anthropic, multi-agent research](https://www.anthropic.com/engineering/multi-agent-research-system)). Multi-agent variants made sequential tasks 39–70% worse ([Google Research](https://research.google/blog/towards-a-science-of-scaling-agent-systems-when-and-why-agent-systems-work/)). Claude Code docs: teams for independent modules, review and competing hypotheses; one session for sequential or same-file work ([agent-teams](https://code.claude.com/docs/en/agent-teams)). |
| At most five working teammates | "Start with 3-5 teammates"; "three focused teammates often outperform five scattered ones" ([agent-teams](https://code.claude.com/docs/en/agent-teams)). |
| Full spawn prompts; run folder with file handoffs | Teammates don't inherit the lead's history ([agent-teams](https://code.claude.com/docs/en/agent-teams)). Vague briefs caused misread tasks and duplicate work; workers should write to files and return references ([Anthropic](https://www.anthropic.com/engineering/multi-agent-research-system)). |
| Planner waits and checks handoffs | Independent agents amplified errors 17.2x vs 4.4x with a central checkpoint ([arXiv 2512.08296](https://arxiv.org/abs/2512.08296v2)). |
| Observable criteria; QA verdicts only from its own runs; "Done when" per role | Verification and termination failures dominate multi-agent failures; role drift is rare (1.5%) ([MAST, arXiv 2503.13657](https://arxiv.org/html/2503.13657v3)). Feature lists starting as failing, with tests as evidence, curb premature "done" ([Anthropic, long-running harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)). |
| Fresh reviewers that see the diff and criteria, not the plan; findings limited to correctness | A fresh context isn't biased toward code it wrote; reviewers told to find gaps will find some, so scope them ([best practices](https://code.claude.com/docs/en/best-practices)). |
| Devil's advocate critiques once; the tech-lead decides, the planner settles | Free debate between agents drifts toward conformity and can flip correct answers ([arXiv 2509.05396](https://arxiv.org/abs/2509.05396v2)). |
| Opus planner and judgement roles, Sonnet builders, Haiku for mechanical work | Opus lead with Sonnet workers beat single-agent Opus by 90.2% ([Anthropic](https://www.anthropic.com/engineering/multi-agent-research-system)); Sonnet for teammates, Opus for architecture ([costs](https://code.claude.com/docs/en/costs)). Spawn-prompt model beats the definition's `model:` ([agent-teams](https://code.claude.com/docs/en/agent-teams)). |
| Quality gate on TaskCompleted, one idle nudge | Exit 2 on TaskCompleted keeps the task open; on TeammateIdle it keeps the teammate working ([hooks](https://code.claude.com/docs/en/hooks)). Verified 2026-10-09: plugin TaskCreated/TaskCompleted hooks fire and a failing gate leaves the task pending. |
| Researcher works in the foreground | In-process teammates cannot run background subagents ([agent-teams](https://code.claude.com/docs/en/agent-teams)). Verified: a plugin agent sees the Skill tool, other plugins' skills and SendMessage. |

## Verified end to end (2026-10-09, Claude Code 2.1.295)

`evals/agent-team/run-all.sh` drove real interactive sessions (agent teams on, auto permission mode) against five sandbox repos with hidden acceptance tests. Final run: solo 8/8, parked 8/8, full 22/22, worktree 27/27, gate 24/24.

- TaskCreated, TaskCompleted and TeammateIdle plugin hooks fire inside teammate sessions, and the gate's refusal reaches the engineer's own transcript.
- The shared task list needs `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` on Claude 5.x models (the Task tools are off by default there). Without it the gate still runs on TeammateIdle.
- Teammates honour the spawn-prompt model. A mod's `agent.spawn` hook that only sets a model when none is given (like model-router) leaves the planner's choice alone.
- The stress test changed the design in four places: the idle-time gate, squash-merging worktree branches into uncommitted changes, deciding questions that have a clear default instead of asking, and the task-tools preflight.
