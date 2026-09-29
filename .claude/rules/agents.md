# Agents

Every agent spawned names its `model:`. One that does not runs on `sonnet` (`CLAUDE_CODE_SUBAGENT_MODEL` in `.claude/settings.json`).

| Agent | Model | For |
|---|---|---|
| Explore | `haiku` | Finding files and naming patterns |
| Explore / general-purpose | `sonnet` | Reading and summarising a subsystem |
| Plan | `opus` | A design across layers (or `/plan`, on `fable`) |
| `fable-validator` | `fable` (pinned) | The finished change, before its pull request opens or merges |

- Launch independent agents in parallel, in one message.
- Use direct tools for a known file, a single grep, a single edit, or a command.
- Consult the advisor (Fable) before choosing an approach, a public API or option name, a dependency, anything irreversible, and when a failure repeats.
