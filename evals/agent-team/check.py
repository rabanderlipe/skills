#!/usr/bin/env python3
"""Checks one finished scenario against its expectations and prints PASS/FAIL lines.

Usage: check.py <scenario> <repo-dir> <results-dir>

Evidence comes from the repo itself (git, tests, hidden acceptance tests copied in from
hidden/), the run folder under ~/.claude/agent-team/runs/, the hook log
~/.claude/agent-team/log.jsonl, and the session transcripts under ~/.claude/projects/.
Writes <results-dir>/<scenario>.check.json.
"""
import glob, json, os, re, shutil, subprocess, sys

scenario, repo, results = sys.argv[1:4]
here = os.path.dirname(os.path.abspath(__file__))
spec = json.load(open(os.path.join(here, "scenarios.json")))[scenario]
meta = json.load(open(os.path.join(results, f"{scenario}.meta.json")))
start = meta["start"]
checks = []

def check(name, ok, detail=""):
    checks.append({"check": name, "ok": bool(ok), "detail": detail})

def sh(cmd, cwd=repo):
    p = subprocess.run(["bash", "-o", "pipefail", "-c", cmd], cwd=cwd, capture_output=True, text=True)
    return p.returncode, (p.stdout + p.stderr).strip()

# --- evidence ------------------------------------------------------------------------
real = os.path.realpath(repo)
log = []
for line in open(os.path.expanduser("~/.claude/agent-team/log.jsonl")):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if os.path.realpath(e.get("cwd") or "/") .startswith(real):
        log.append(e)
runs = sorted(p for p in glob.glob(os.path.expanduser(f"~/.claude/agent-team/runs/{os.path.basename(repo)}-*")) if os.path.getmtime(p) >= start - 5)
run = runs[-1] if runs else None

tool_uses, texts = [], []
proj_dirs = [d for d in glob.glob(os.path.expanduser("~/.claude/projects/*")) if os.path.basename(repo) in d]
for d in proj_dirs:
    for f in glob.glob(os.path.join(d, "**", "*.jsonl"), recursive=True):
        if os.path.getmtime(f) < start:
            continue
        for line in open(f, errors="replace"):
            try:
                j = json.loads(line)
            except ValueError:
                continue
            content = (j.get("message") or {}).get("content")
            if isinstance(content, list):
                for c in content:
                    if c.get("type") == "tool_use":
                        tool_uses.append({"file": f, **c})
                    elif c.get("type") == "text":
                        texts.append(c.get("text", ""))
                    elif c.get("type") == "tool_result":
                        r = c.get("content")
                        texts.append(json.dumps(r) if not isinstance(r, str) else r)
spawns = [t["input"] for t in tool_uses if t.get("name") in ("Agent", "Task") and isinstance(t.get("input"), dict)]
def spawn_name(s):
    return s.get("name") or (re.search(r"teammate (\S+)", s.get("prompt", "")) or [None, None])[1] or s.get("subagent_type", "?")
def spawn_model(s):
    return s.get("model") or (re.search(r"on model (opus|sonnet|haiku)", s.get("prompt", ""), re.I) or [None, None])[1]
team = [{"name": spawn_name(s), "type": s.get("subagent_type"), "model": spawn_model(s)} for s in spawns]
asked = any(t.get("name") == "AskUserQuestion" for t in tool_uses)
all_text = "\n".join(texts) + open(os.path.join(results, f"{scenario}.screen.txt"), errors="replace").read()

# --- common --------------------------------------------------------------------------
check("session found and transcripts readable", bool(tool_uses), f"{len(tool_uses)} tool calls in {len(proj_dirs)} project dir(s)")
check("session ended on its own terms (report or idle, not timeout)", meta["ended"] in ("report", "idle", "exited"), meta["ended"])
code, _ = sh("git diff --quiet HEAD -- docs/spec.md")
check("owner-only docs/spec.md untouched", code == 0)
code, out = sh("git diff HEAD --stat -- test/ledger.test.js; git show HEAD:test/ledger.test.js | grep -c '^test(' ; grep -c '^test(' test/ledger.test.js")
nums = [int(x) for x in out.split() if x.isdigit()][-2:]
check("original tests kept (none deleted)", len(nums) == 2 and nums[1] >= nums[0], out.replace("\n", " | "))

def tests_and_hidden():
    code, out = sh("npm run lint --silent && npm test --silent 2>&1 | tail -5")
    check("project lint + tests pass", code == 0, out[-300:])
    for h in spec.get("hidden", []):
        dst = os.path.join(repo, "test", f"zz-hidden-{h}.test.js")
        shutil.copy(os.path.join(here, "hidden", f"{h}.test.js"), dst)
        code, out = sh(f"node --test test/zz-hidden-{h}.test.js 2>&1 | grep -E '^(# |ℹ )(pass|fail)|^not ok|✖' | head -12")
        os.remove(dst)
        check(f"hidden acceptance tests: {h}", code == 0, out.replace("\n", " | "))

def team_checks(required):
    names = [t["name"] for t in team]
    check(f"team spawned with roles {required}", all(any(n == r or n.startswith(r) for n in names) for r in required), str(team))
    check("every spawn names a model", team and all(t["model"] for t in team), str(team))
    check("not all teammates on the same model", len({t["model"] for t in team}) > 1, str({t['model'] for t in team}))
    eng = [t for t in team if t["name"].startswith("eng-")]
    check("engineers spawned as agent-team:engineer", eng and all((t["type"] or "").endswith("engineer") for t in eng), str(eng))
    check("run folder created", run is not None, run or "none")
    if run:
        for f in ["brief.md", "criteria.md", "qa.md", "report.md"] + (["plan.md"] if any(t["name"] == "tech-lead" for t in team) else []):
            check(f"run folder has {f}", os.path.exists(os.path.join(run, f)))
        rep = open(os.path.join(run, "report.md")).read() if os.path.exists(os.path.join(run, "report.md")) else ""
        check("report has a per-teammate model table", re.search(r"\|.*(opus|sonnet|haiku).*\|", rep, re.I))
        qa = open(os.path.join(run, "qa.md")).read() if os.path.exists(os.path.join(run, "qa.md")) else ""
        check("qa.md has a verdict per criterion", qa.count("✅") + qa.count("❌") >= 3, f"{qa.count('✅')} ✅ / {qa.count('❌')} ❌")
    completions = [e for e in log if e["event"] == "TaskCompleted" and e["teammate"].startswith("eng-")]
    check("hook log: engineers completed shared tasks", completions, f"{len(completions)} eng completions")
    check("hook log: gate ran for engineers on idle", any(e["event"] == "TeammateIdle" and e["teammate"].startswith("eng-") for e in log))
    events = {e["event"] for e in log}
    check("hook log: TaskCreated and TeammateIdle fired", {"TaskCreated", "TeammateIdle"} <= events, str(events))
    return completions

# --- per scenario --------------------------------------------------------------------
if scenario == "solo":
    check("no teammates spawned", not [t for t in team if t["name"] not in ("?",) and (t["type"] or "").startswith("agent-team")], str(team))
    code, out = sh("grep -n 'Received' src/messages.js && ! grep -rn 'Recieved' src")
    check("typo fixed", code == 0, out)
    code, out = sh("git diff HEAD --name-only")
    check("only src/messages.js changed", out.strip() in ("src/messages.js", ""), out)
    tests_and_hidden()
elif scenario in ("full", "gate", "worktree"):
    required = {"full": ["pm", "tech-lead", "eng-", "qa"], "gate": ["eng-", "qa"], "worktree": ["eng-", "qa"]}[scenario]
    completions = team_checks(required)
    tests_and_hidden()
    commits = sh("git rev-list --count HEAD")[1]
    if scenario == "worktree":
        check("worktrees removed at the end", sh("git worktree list | wc -l")[1].strip() == "1", sh("git worktree list")[1])
        check("team/* branches merged and deleted", sh("git branch --list 'team/*'")[1] == "", sh("git branch -a")[1])
        check("engineers' work landed in the main working tree", sh("git status --porcelain -- src")[1] != "" or int(commits) > 1, sh("git status --short")[1])
        check("engineers were told worktree mode", any("worktree mode" in s.get("prompt", "").lower() for s in spawns if spawn_name(s).startswith("eng-")))
    check("no commits on main (changes left for the user)", commits == "1", f"{commits} commits")
    if scenario == "gate":
        by_task = {}
        for e in completions:
            by_task.setdefault(e["task_id"], 0); by_task[e["task_id"]] += 1
        eng_files = {t["file"] for t in tool_uses if "/subagents/" in t["file"] and "eng-" in os.path.basename(t["file"])}
        refused = any("Quality gate failed in" in open(f, errors="replace").read() for f in eng_files)
        tripped = os.path.exists(os.path.join(os.path.dirname(os.path.realpath(repo)), ".gate-tripped"))
        check("hook-run gate tripped (the hook really ran the gate)", tripped)
        check("the hook's refusal reached the engineer's own transcript", refused, f"engineer transcripts={len(eng_files)}")
        check("gate passes at the end", sh("bash .claude/team-gate.sh")[0] == 0)
elif scenario == "parked":
    check("no engineers spawned", not [t for t in team if t["name"].startswith("eng-")], str(team))
    check("no source changes", sh("git status --porcelain -- src test")[1] == "", sh("git status --porcelain")[1])
    check("parked status surfaced", re.search(r"parked", all_text, re.I))
    check("planner asked the user (AskUserQuestion or a direct question)", asked or re.search(r"(want me to|should I|do you want|would you like)", all_text, re.I), f"AskUserQuestion={asked}")

ok = sum(c["ok"] for c in checks)
print(f"\n== {scenario}: {ok}/{len(checks)} checks pass ({meta['ended']}, {meta['minutes']} min)")
for c in checks:
    print(f"  {'PASS' if c['ok'] else 'FAIL'}  {c['check']}" + (f"  — {c['detail'][:220]}" if c["detail"] and not c["ok"] else ""))
print(f"  team: {team}")
json.dump({"scenario": scenario, "meta": meta, "team": team, "run": run, "checks": checks}, open(os.path.join(results, f"{scenario}.check.json"), "w"), indent=2)
