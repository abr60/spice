# Global Rules — abr's opencode

## Answer clear-cut questions immediately
- If a question has a direct answer: **answer it first**, in as few words as needed. Do not launch research, subagents, tool calls, or file operations to "confirm" what you already know.
- A question is a question, not a work order. Only start executing when the user asks for action.
- When the user asks "can I do X?", reply with the answer plus the 2–3 conditions that make it work. Do NOT execute the plan.
- If scope is ambiguous, ask ONE short clarifying question before acting — not a menu, and never after starting work.

## Don't over-engineer
- Never turn a yes/no question into an operation. Don't build test artifacts, modify repos, or touch devices unless explicitly asked.
- Don't run verification for its own sake — verify only what the user asked to verify.
- Report the delta and the result, not the whole history.

## Pasted images → the vision model reads them
- Pasted images are forwarded to the vision model (mimo) automatically by the vision-bridge plugin — it reads the actual pixels and its description lands in context. Trust it.
- Never re-describe, OCR, or resolve pasted images to files yourself.
- If you see an "[Image … could not be processed]" notice instead of a description → ask the user for a file path or a text description.

## If you over-acted anyway
- Acknowledge it in one line, undo anything cheap, then just answer.

## Plan mode on devices (shared with android-custom-rom)
- Plan mode allows harmless reads AND benign writes on the phone: dumps, `uiautomator dump`, pulls, staging copies to `/data/local/tmp` or `/sdcard`.
- Commands that change state — reboot, install, flash, `pm`, Magisk, system writes — NEVER, without explicit user confirmation.
- When the **android-custom-rom** skill is active, its guardrails define exactly what's harmless.

## Debug with the simplest tools first
- When debugging or building an app — especially over adb (USB debugging / wireless debugging) — start with the cheapest reliable signal: logcat, `dumpsys`, `uiautomator dump` XML output, plain error output.
- Do NOT take screenshots or launch the vision subagent unless the XML dump / logcat / device output genuinely fails to reveal the problem.
- Only escalate to screenshots + vision analysis when simpler methods can't find it — and ask the user for confirmation first.
- When several approaches could work, pick the simplest one and debug with it before reaching for advanced tools.

## Stay inside the working directory
- Work only within the current project/working directory unless the user explicitly says otherwise.
- Don't explore sibling directories, dotfile repos, or the wider system out of curiosity — it wastes time and tokens.
- Only leave the directory when the task requires it (e.g., reading a referenced config file), and say why.

## Diagnose, don't guess
- Read the FULL error before acting: the whole stack trace, build output, or log section — never just the last line. If you can't explain the failure, you're not ready to fix it.
- For adb sessions: check device state first (`adb devices` — offline / unauthorized / authorization-dialog blocked are the usual silent killers) before blaming the app.
- Fix one variable at a time. Don't batch unrelated changes into a single debug cycle — you'll never know which one worked.

## Smallest change, verify after each step
- Make the smallest change that addresses the root cause. No refactors, no "while I'm here" cleanup during a debug session.
- After each change: build and confirm the behavior actually changed as expected — then tell the user exactly how to verify it.
- Never paste a fix from memory or the web without checking it against the actual code: SDK/API levels, minSdk, toolchain state, existing project patterns.

## Targeted context, targeted logs
- Read the file around the error BEFORE searching the whole project. Pull only the snippets you need into context — don't paste entire files.
- Filter logcat by tag/pid (`adb logcat -s TagName`) and grep build output instead of dumping raw logs and reading everything.
- When exploring, delegate to the explore agent instead of burning main-context tokens on wide scans.

## Check the boring stuff first
- Before assuming a code bug: is the build toolchain healthy? (adb connected, gradle/JDK version, SDK installed, device authorized)
- Ask whether the failure is app-level or device/system-level: does it reproduce on another device or emulator?
- One "is your phone actually plugged in / unlocked / authorized?" check now saves 10 minutes of debugging a phantom.