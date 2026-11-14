// vision-bridge.ts (OpenCode V2)
// Automatically processes images pasted/referenced in chat before they reach a
// text-only model. The image is sent to the vision model resolved by the
// model-sync plugin, and the returned text description is added to the prompt
// while the image attachment is dropped.
//
// Pipeline:
//   user pastes image  ->  "prompt" hook sees image FileAttachment
//        ->  vision model describes it  ->  description appended to prompt text
//        ->  image removed from prompt.files  ->  main model receives text only
//
// Local-first. Vision model resolution order:
//   VISION_MODEL env var ("off"/"none" disables)  ->
//   ~/.cache/opencode/model-sync.json (slots.vision,
//      written by the model-sync plugin every launch)  ->  qwen2.5vl:7b.
//
// The vision model always receives the REAL image bytes (inline data URL,
// file read from disk, or remote URL) and interprets them with its own vision
// capability. No OCR, no guessing — the local endpoint is tried first, then
// the cloud fallback (Zen); only if both fail is a visible notice injected.
//
// Config (optional env vars):
//   VISION_MODEL        (override; default qwen2.5vl:7b, "off"/"none" disables)
//   VISION_API_URL      (default: local Ollama http://localhost:11434/v1/chat/completions)
//   VISION_API_KEY      (default: ollama)
//   VISION_FALLBACK_URL (default: Zen cloud; empty disables fallback)
//   VISION_FALLBACK_KEY (default: public)

import { readFileSync } from "node:fs"
import { join, extname } from "node:path"
import { Plugin } from "@opencode/plugin"

const API_URL = process.env.VISION_API_URL ?? "http://localhost:11434/v1/chat/completions"
const API_KEY = process.env.VISION_API_KEY ?? "ollama"
const FALLBACK_API_URL = process.env.VISION_FALLBACK_URL ?? "https://opencode.ai/zen/v1/chat/completions"
const FALLBACK_API_KEY = process.env.VISION_FALLBACK_KEY ?? "public"
const FALLBACK_VISION_MODEL = "openai/gpt-4o-mini"
const SYNC_CACHE = join(process.env.HOME ?? "/home/abr", ".cache/opencode/model-sync.json")
const MAX_RETRIES = 4
const FALLBACK_LOCAL_CHAIN = ["qwen2.5vl:3b", "qwen2.5vl:7b"]

const MIME_BY_EXT: Record<string, string> = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".bmp": "image/bmp",
  ".avif": "image/avif",
  ".svg": "image/svg+xml",
  ".tif": "image/tiff",
  ".tiff": "image/tiff",
  ".heic": "image/heic",
}

interface Attachment {
  uri: string
  source?: { type: "inline" } | { type: "uri"; uri: string }
  name?: string
  description?: string
  mention?: { start: number; end: number; text: string }
}

function resolveVisionModels(): string[] | null {
  const env = process.env.VISION_MODEL?.trim()
  if (env) {
    if (env === "off" || env === "none") return null
    const list = env
      .split(",")
      .map((s) => s.trim().replace(/^opencode\//, ""))
      .filter(Boolean)
    if (list.length === 0) return null
    if (list.length === 1 && list[0] === "qwen2.5vl:3b" && !list.includes("qwen2.5vl:7b")) {
      list.push("qwen2.5vl:7b")
    }
    return list
  }
  // Prefer local Ollama models by default; only use model-sync's slot when it
  // already points to a local qwen vision model.
  try {
    const raw = readFileSync(SYNC_CACHE, "utf8")
    const id = String(JSON.parse(raw)?.slots?.vision ?? "").replace(/^opencode\//, "")
    if (id && id.startsWith("qwen2.5vl")) return [id]
  } catch {
    // ignore
  }
  return [...FALLBACK_LOCAL_CHAIN]
}

function ollamaBase(): string {
  try {
    const u = new URL(API_URL)
    return `${u.protocol}//${u.host}`
  } catch {
    return "http://localhost:11434"
  }
}

async function unloadModel(model: string): Promise<void> {
  // Fire-and-forget unload to free VRAM/RAM; only for local Ollama
  if (!API_URL.includes("localhost") && !API_URL.includes("127.0.0.1")) return
  try {
    await fetch(`${ollamaBase()}/api/generate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model, keep_alive: 0 }),
      signal: AbortSignal.timeout(5000),
    })
  } catch {
    // best-effort, ignore
  }
}

const describePrompt = `You are a meticulous visual analyst. Describe the attached image in exhaustive detail so that a text-only AI can act on it:
- ALL visible text, transcribed verbatim (error messages, labels, commands, code)
- UI elements and their state (buttons, toggles, dialogs, tabs, status bar text)
- Layout, colors, and visual hierarchy
- For screenshots of code: include the exact code/text shown
- For diagrams/tables/charts: describe structure and all labels/values
Output ONLY the complete description. No preamble, no commentary.`

// Simple hash for caching identical images
function hash(s: string): string {
  let h = 5381
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) + h + s.charCodeAt(i)) >>> 0
  }
  return h.toString(36)
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

// One vision call with retries. Returns the description, or null if the
// endpoint is unreachable/rate-limited after all attempts (caller tries next).
async function tryDescribe(
  url: string,
  key: string,
  model: string,
  dataUrl: string,
  mime: string,
  filename: string | undefined,
  maxAttempts: number,
): Promise<string | null> {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const resp = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: "user",
              content: [
                { type: "text", text: describePrompt },
                { type: "image_url", image_url: { url: dataUrl } },
              ],
            },
          ],
        }),
        signal: AbortSignal.timeout(60_000),
      })

      const json: any = await resp.json().catch(() => null)

      if (!resp.ok) {
        const errType = json?.error?.type ?? ""
        const status = resp.status
        if (status === 429 || errType === "FreeUsageLimitError" || status >= 500) {
          await sleep(attempt * 2500)
          continue
        }
        return `[Image "${filename ?? "pasted image"}" could not be processed (HTTP ${status}: ${
          json?.error?.message ?? "unknown error"
        })]`
      }

      const content = json?.choices?.[0]?.message?.content
      if (typeof content === "string" && content.trim().length > 0) {
        return content.trim()
      }
      return `[Image "${filename ?? "pasted image"}" was processed but produced no description]`
    } catch {
      await sleep(attempt * 1500)
    }
  }
  return null
}

// Local-first with chain: try each local model (3b -> 7b) then cloud fallback.
// Each local model is unloaded (keep_alive=0) after use to free RAM/VRAM.
async function describeImage(
  dataUrl: string,
  mime: string,
  filename: string | undefined,
  model: string,
): Promise<string> {
  const chain = model.includes(",")
    ? model.split(",").map((s) => s.trim()).filter(Boolean)
    : [model]

  if (chain.length === 1 && chain[0] === "qwen2.5vl:3b" && !chain.includes("qwen2.5vl:7b")) {
    chain.push("qwen2.5vl:7b")
  }

  const attempted: string[] = []
  for (const m of chain) {
    attempted.push(m)
    const result = await tryDescribe(API_URL, API_KEY, m, dataUrl, mime, filename, MAX_RETRIES)
    queueMicrotask(() => {
      void unloadModel(m)
    })
    if (result !== null) {
      const isErrorNotice = result.startsWith(`[Image "`)
      if (!isErrorNotice) return result
      if (chain.indexOf(m) < chain.length - 1) continue
      return result
    }
  }

  for (const m of attempted)
    queueMicrotask(() => {
      void unloadModel(m)
    })

  if (FALLBACK_API_URL && FALLBACK_API_URL !== API_URL) {
    const fb = await tryDescribe(FALLBACK_API_URL, FALLBACK_API_KEY, FALLBACK_VISION_MODEL, dataUrl, mime, filename, 2)
    if (fb !== null) return fb
  }
  return (
    `[Image "${filename ?? "pasted image"}" could not be processed (local vision and cloud fallback both failed). ` +
    `The user attached an image of type ${mime}. Ask the user to describe it or paste the text content.]`
  )
}

// Resolve an attachment URI to real image bytes (data URL) when possible.
function toDataUrl(uri: string): { dataUrl?: string; mime: string; label: string } | null {
  const label = uri.startsWith("data:") ? "pasted image" : (uri.split("/").pop() ?? uri)

  if (uri.startsWith("data:")) {
    const mime = uri.slice(5, uri.indexOf(";")) || "image/png"
    return { dataUrl: uri, mime, label }
  }
  if (/^https?:\/\//.test(uri)) {
    // Remote URL (e.g. pasted from a browser) — the vision API fetches it itself.
    return { dataUrl: uri, mime: "", label }
  }

  const filePath = uri.startsWith("file://") ? decodeURIComponent(uri.slice("file://".length)) : uri
  const mime = MIME_BY_EXT[extname(filePath).toLowerCase()] ?? "application/octet-stream"
  try {
    const buf = readFileSync(filePath)
    return { dataUrl: `data:${mime};base64,${buf.toString("base64")}`, mime, label: filePath.split("/").pop() ?? label }
  } catch {
    return null
  }
}

function isImage(attachment: Attachment): boolean {
  if (attachment.uri.startsWith("data:image/")) return true
  if (/^https?:\/\//.test(attachment.uri)) {
    return /\.(png|jpe?g|gif|webp|bmp|avif|svg|tiff?|heic)(\?|$)/i.test(attachment.uri)
  }
  const filePath = attachment.uri.startsWith("file://")
    ? decodeURIComponent(attachment.uri.slice("file://".length))
    : attachment.uri
  return Boolean(MIME_BY_EXT[extname(filePath).toLowerCase()])
}

export default Plugin.define({
  id: "vision-bridge",
  async setup(ctx) {
    // Cache: dataUrl hash -> description (avoids re-processing repeated images)
    const cache = new Map<string, string>()

    // Track the effective default model so a vision-capable model can still see
    // images natively.
    let current: { providerID: string; modelID: string } | undefined
    await ctx.model.transform((editor) => {
      current = editor.default.get()
    })

    await ctx.session.hook("prompt", async (event) => {
      try {
        const files = event.prompt.files
        if (!files || files.length === 0) return

        const imageFiles = (files as Attachment[]).filter(isImage)
        if (imageFiles.length === 0) return

        const visionModels = resolveVisionModels()
        if (!visionModels) return

        const norm = (id: string) => id.replace(/^[^/]+\//, "")
        if (current && visionModels.some((vm) => norm(vm) === norm(current!.modelID))) return

        const chainStr = visionModels.join(",")
        const descriptions: string[] = []
        const kept = (files as Attachment[]).filter((f) => !isImage(f))

        for (const file of imageFiles) {
          const resolved = toDataUrl(file.uri)
          if (!resolved?.dataUrl) {
            descriptions.push(
              `[Image: "${file.name ?? file.uri}" — attached as a file but could not be read from disk. Ask the user to re-attach it or describe it.]`,
            )
            continue
          }

          const key = hash(resolved.dataUrl)
          let description = cache.get(key)
          if (!description) {
            description = await describeImage(resolved.dataUrl, resolved.mime, file.name ?? resolved.label, chainStr)
            cache.set(key, description)
          }

          const name = file.name ?? resolved.label ?? "pasted image"
          descriptions.push(
            `[Image: "${name}"${resolved.mime ? ` (${resolved.mime})` : ""} — visual description extracted automatically]\n${description}`,
          )
        }

        event.prompt.files = kept
        if (descriptions.length > 0) {
          const text = event.prompt.text?.trim()
          event.prompt.text = [text, ...descriptions].filter(Boolean).join("\n\n")
        }
      } catch (error) {
        // Never block the prompt on a vision failure
        console.error("[vision-bridge]", error)
      }
    })
  },
})
