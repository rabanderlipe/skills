#!/usr/bin/env python3
"""Drives one real interactive Claude Code session in a pseudo-terminal.

Usage: drive.py <scenario> <repo-dir> <plugin-dir> <out-dir> [--timeout-min N]

Starts `claude` in <repo-dir> with the scenario's prompt, accepts the folder-trust
dialog, and ends the session once it is done: the run's report.md exists and the screen
has been quiet, or the screen has been quiet for a long stretch (the session is waiting
for the user), or the timeout passes. Writes <out-dir>/<scenario>.screen.txt (ANSI
stripped) and <scenario>.meta.json (start/end, how it ended).
"""
import glob, json, os, pty, re, select, signal, sys, time

scenario, repo, plugin, out = sys.argv[1:5]
timeout = 90 * 60
if "--timeout-min" in sys.argv:
    timeout = int(sys.argv[sys.argv.index("--timeout-min") + 1]) * 60
sc = json.load(open(os.path.join(os.path.dirname(__file__), "scenarios.json")))[scenario]
prompt = sc["prompt"]
answer_questions = sc.get("answer_questions", True)
answered = 0
ansi = re.compile(rb"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07]*\x07|\x1b[()][A-Za-z0-9]|\x1b[=>]")
QUIET_DONE, QUIET_IDLE = 60, 240  # seconds of no output

argv = ["claude", "--name", f"tally-{scenario}", "--plugin-dir", plugin, "--permission-mode", "auto", prompt]
# Start a fresh top-level session: drop the variables that mark it as a child of the
# session running this script (those sessions save no transcript of their own).
env = {k: v for k, v in os.environ.items() if not (k.startswith("CLAUDE") or k == "AI_AGENT")}
env.update(CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1", CLAUDE_CODE_ENABLE_TODO_TOOLS="1", COLUMNS="200", LINES="50")
pid, fd = pty.fork()
if pid == 0:
    os.chdir(repo)
    os.execvpe("claude", argv, env)

import fcntl, struct, termios
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 50, 200, 0, 0))
start = time.time()
last_out = start
raw = bytearray()
trusted = False
ended = "timeout"
runs = os.path.expanduser(f"~/.claude/agent-team/runs/{os.path.basename(repo)}-*")

def tail_text(n=6000):
    return ansi.sub(b"", bytes(raw[-n:])).decode("utf8", "replace")

while True:
    now = time.time()
    r, _, _ = select.select([fd], [], [], 2)
    if r:
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            ended = "exited"; break
        if not chunk:
            ended = "exited"; break
        raw += chunk
        last_out = now
        # Startup dialogs only: folder trust. Anything later is the session's own business.
        # The dialog's default is "No, exit": move down to "Yes, I trust this folder" first.
        if not trusted and now - start < 90 and re.search(r"trust\s*this\s*folder", tail_text(), re.I):
            time.sleep(1); os.write(fd, b"\x1b[B"); time.sleep(0.5); os.write(fd, b"\r"); trusted = True
        # Unattended scenarios: accept the recommended (first) option of any question,
        # like a user who trusts the planner's defaults. Recorded in meta.json.
        if answer_questions and trusted and answered < 20 and re.search(r"Enter\s*to\s*select", tail_text(1500)):
            time.sleep(2); os.write(fd, b"\r"); answered += 1; last_out = time.time()
    quiet = now - last_out
    reports = [p for p in glob.glob(runs) if os.path.exists(os.path.join(p, "report.md")) and os.path.getmtime(os.path.join(p, "report.md")) > start]
    if reports and quiet > QUIET_DONE:
        ended = "report"; break
    if quiet > QUIET_IDLE and now - start > 300:
        ended = "idle"; break
    if now - start > timeout:
        ended = "timeout"; break

screen = ansi.sub(b"", bytes(raw)).decode("utf8", "replace")
if ended != "exited":
    for _ in range(2):
        try:
            os.write(fd, b"\x1b"); time.sleep(0.5); os.write(fd, b"/exit\r"); time.sleep(5)
        except OSError:
            break
    try:
        os.kill(pid, signal.SIGTERM); time.sleep(3); os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
os.makedirs(out, exist_ok=True)
open(os.path.join(out, f"{scenario}.screen.txt"), "w").write(screen[-200000:])
json.dump({"scenario": scenario, "repo": repo, "start": start, "end": time.time(), "ended": ended, "questions_answered": answered,
           "minutes": round((time.time() - start) / 60, 1)}, open(os.path.join(out, f"{scenario}.meta.json"), "w"), indent=2)
print(f"{scenario}: ended by {ended} after {round((time.time() - start) / 60, 1)} min")
