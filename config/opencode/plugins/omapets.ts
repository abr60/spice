import { execFile } from "node:child_process"
import { Plugin } from "@opencode/plugin"

const HOOK = "/home/abr/.config/omarchy/plugins/omapets/bin/omapets-hook"

function emit(event: string) {
  execFile(HOOK, [event, "opencode"], { stdio: "ignore" }, () => {})
}

export default Plugin.define({
  id: "omapets",
  async setup(ctx) {
    const abort = new AbortController()

    const stream = ctx.event.subscribe({
      signal: abort.signal,
      types: [
        "session.created",
        "session.status",
        "permission.asked",
        "session.idle",
        "session.execution.failed",
        "session.deleted",
      ],
    })

    void (async () => {
      try {
        for await (const event of stream) {
          switch (event.type) {
            case "session.created":
              emit("session-start")
              break
            case "session.status":
              if (event.data.status.type !== "idle") emit("prompt")
              break
            case "permission.asked":
              emit("permission")
              break
            case "session.idle":
              emit("stop")
              break
            case "session.execution.failed":
              emit("error")
              break
            case "session.deleted":
              emit("session-end")
              break
          }
        }
      } catch {
        // stream aborted on shutdown
      }
    })()

    await ctx.tool.hook("execute.before", () => {
      emit("tool-start")
    })
    await ctx.tool.hook("execute.after", () => {
      emit("tool-end")
    })

    return () => {
      abort.abort()
    }
  },
})
