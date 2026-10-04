# skills

Claude Code plugins by [@rabanderlipe](https://github.com/rabanderlipe).

```
/plugin marketplace add rabanderlipe/skills
/plugin install ship-task@rabanderlipe
```

## ship-task

`/ship-task:ship-task "<conventional-commit PR title>"` — preflight, rebase on the default branch, push, open a PR, watch checks, squash-merge, sync and clean up. Needs `gh` signed in.

Preflight runs the command your `CLAUDE.md` or `AGENTS.md` names (e.g. `Preflight: make check`); otherwise the `lint`, `typecheck`, `test` and `build` scripts that exist in `package.json`.
