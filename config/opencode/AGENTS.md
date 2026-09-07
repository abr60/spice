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