import { execFile } from "node:child_process"
import { basename } from "node:path"
import { Plugin } from "@opencode/plugin"

const MAX_PREVIEW = 60

function notify(summary: string, body: string) {
  execFile(
    "notify-send",
    ["-a", "opencode", "-i", "dialog-information", summary, body],
    { stdio: "ignore", timeout: 5000 },
    () => {},
  )
}

function duration(ms: number) {
  const total = Math.max(0, Math.round(ms / 1000))
  const minutes = Math.floor(total / 60)
  const seconds = total % 60
  if (!minutes) return `${seconds}s`
  return `${minutes}m ${seconds.toString().padStart(2, "0")}s`
}

function preview(text: string | undefined) {
  if (!text) return ""
  const flat = text.replace(/\s+/g, " ").trim()
  if (!flat) return ""
  return flat.length > MAX_PREVIEW ? `${flat.slice(0, MAX_PREVIEW - 1)}…` : flat
}

export default Plugin.define({
  id: "simple-notify",
  async setup(ctx) {
    const name = basename(ctx.location.directory) || "opencode"
    const abort = new AbortController()
    const started = new Map<string, number>()
    const lastText = new Map<string, string>()

    await ctx.session.hook("prompt", (event) => {
      if (!started.has(event.sessionID)) started.set(event.sessionID, Date.now())
      lastText.set(event.sessionID, event.prompt.text ?? "")
    })

    const stream = ctx.event.subscribe({
      signal: abort.signal,
      types: ["session.created", "session.idle", "session.execution.failed", "permission.asked"],
    })

    void (async () => {
      try {
        for await (const event of stream) {
          if (event.type === "session.created") {
            started.set(event.data.sessionID, Date.now())
            continue
          }
          if (event.type === "permission.asked") {
            notify("OpenCode needs approval", `Permission: ${event.data.action}`)
            continue
          }
          if (event.type === "session.execution.failed") {
            notify(`${name} error`, preview(event.data.error?.message) || "Run failed")
            continue
          }
          if (event.type === "session.idle") {
            const sessionID = event.data.sessionID
            const begin = started.get(sessionID)
            const elapsed = begin ? ` (${duration(Date.now() - begin)})` : ""
            const body = preview(lastText.get(sessionID)) || "task completed"
            notify(`${name} done${elapsed}`, body)
            started.delete(sessionID)
            lastText.delete(sessionID)
          }
        }
      } catch {
        // stream aborted on shutdown
      }
    })()

    await ctx.tool.hook("execute.before", (event) => {
      if (event.tool !== "question") return
      const input = event.input as { questions?: Array<{ header?: string; question?: string }> } | undefined
      const first = input?.questions?.[0]
      notify("OpenCode waiting", preview(first?.header || first?.question) || "Answer the question")
    })

    return () => {
      abort.abort()
    }
  },
})
