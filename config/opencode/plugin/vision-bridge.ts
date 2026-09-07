// vision-bridge.ts
// Automatically processes images pasted/referenced in chat before they reach a
// text-only model. The image is sent to the vision model resolved by the
// model-sync plugin, and the returned text description replaces the image.
//
// Pipeline:
//   user pastes image  ->  hook detects image FilePart  ->  vision model describes it
//        ->  image part replaced with "[Image description] ..." text
//        ->  main model receives text only  ->  seamless
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

import type { Plugin } from "@opencode-ai/plugin";
import fs from "node:fs";
import path from "node:path";

const API_URL =
  process.env.VISION_API_URL ?? "http://localhost:11434/v1/chat/completions";
const API_KEY = process.env.VISION_API_KEY ?? "ollama";
const FALLBACK_API_URL =
  process.env.VISION_FALLBACK_URL ?? "https://opencode.ai/zen/v1/chat/completions";
const FALLBACK_API_KEY = process.env.VISION_FALLBACK_KEY ?? "public";
const FALLBACK_VISION_MODEL = "openai/gpt-4o-mini";
const SYNC_CACHE = path.join(
  process.env.HOME ?? "/home/abr",
  ".cache/opencode/model-sync.json",
);
const MAX_RETRIES = 4;
const DEFAULT_VISION_MODEL = "qwen2.5vl:7b";
// Fallback local model chain: try 3b first (fast/low RAM) then 7b if 3b fails
const FALLBACK_LOCAL_CHAIN = ["qwen2.5vl:3b", "qwen2.5vl:7b"];

function resolveVisionModels(): string[] | null {
  const env = process.env.VISION_MODEL?.trim();
  if (env) {
    if (env === "off" || env === "none") return null;
    // Support comma-separated list: "qwen2.5vl:3b,qwen2.5vl:7b"
    const list = env.split(",").map((s) => s.trim().replace(/^opencode\//, "")).filter(Boolean);
    if (list.length === 0) return null;
    // Auto-append fallback chain if primary is 3b and 7b not already in list
    if (list.length === 1 && list[0] === "qwen2.5vl:3b" && !list.includes("qwen2.5vl:7b")) {
      list.push("qwen2.5vl:7b");
    }
    return list;
  }
  // Local-first: opencode.json env is not reliably injected into plugin host
  // (process.env.VISION_MODEL empty even when set in config), so prefer
  // local Ollama models by default instead of model-sync's cloud vision slot.
  // Only use model-sync if it already points to a local qwen model.
  try {
    const raw = fs.readFileSync(SYNC_CACHE, "utf8");
    const id = String(JSON.parse(raw)?.slots?.vision ?? "").replace(/^opencode\//, "");
    if (id && id.startsWith("qwen2.5vl")) return [id];
  } catch {
    // ignore
  }
  return [...FALLBACK_LOCAL_CHAIN];
}

// Backwards compat helper
function resolveVisionModel(): string | null {
  const models = resolveVisionModels();
  return models?.[0] ?? null;
}

function ollamaBase(): string {
  // Derive http://localhost:11434 from VISION_API_URL
  try {
    const u = new URL(API_URL);
    return `${u.protocol}//${u.host}`;
  } catch {
    return "http://localhost:11434";
  }
}

async function unloadModel(model: string): Promise<void> {
  // Fire-and-forget unload to free VRAM/RAM; only for local Ollama
  if (!API_URL.includes("localhost") && !API_URL.includes("127.0.0.1")) return;
  try {
    await fetch(`${ollamaBase()}/api/generate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model, keep_alive: 0 }),
      signal: AbortSignal.timeout(5000),
    });
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
Output ONLY the complete description. No preamble, no commentary.`;

// Simple hash for caching identical images
function hash(s: string): string {
  let h = 5381;
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) + h + s.charCodeAt(i)) >>> 0;
  }
  return h.toString(36);
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

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
      });

      const json: any = await resp.json().catch(() => null);

      if (!resp.ok) {
        const errType = json?.error?.type ?? "";
        const status = resp.status;
        // Rate limited or 5xx -> wait and retry with backoff
        if (status === 429 || errType === "FreeUsageLimitError" || status >= 500) {
          await sleep(attempt * 2500);
          continue;
        }
        return `[Image "${filename ?? "pasted image"}" could not be processed (HTTP ${status}: ${
          json?.error?.message ?? "unknown error"
        })]`;
      }

      const content = json?.choices?.[0]?.message?.content;
      if (typeof content === "string" && content.trim().length > 0) {
        return content.trim();
      }
      return `[Image "${filename ?? "pasted image"}" was processed but produced no description]`;
    } catch {
      await sleep(attempt * 1500);
    }
  }
  return null;
}

// Local-first with chain: try each local model (3b -> 7b) then cloud fallback.
// Each local model is unloaded (keep_alive=0) after use to free RAM/VRAM.
async function describeImage(
  dataUrl: string,
  mime: string,
  filename: string | undefined,
  model: string,
): Promise<string> {
  // Support legacy single model param but also handle comma-separated chain
  const chain = model.includes(",")
    ? model.split(",").map((s) => s.trim()).filter(Boolean)
    : [model];

  // If chain is single 3b, auto-add 7b as fallback
  if (chain.length === 1 && chain[0] === "qwen2.5vl:3b" && !chain.includes("qwen2.5vl:7b")) {
    chain.push("qwen2.5vl:7b");
  }

  const attempted: string[] = [];
  for (const m of chain) {
    attempted.push(m);
    const result = await tryDescribe(API_URL, API_KEY, m, dataUrl, mime, filename, MAX_RETRIES);
    // Unload immediately after attempt to keep system fresh (fire-and-forget, don't block description)
    // Use queueMicrotask so we return description without waiting for unload
    queueMicrotask(() => { void unloadModel(m); });
    if (result !== null) {
      // If result is an error notice (starts with "[Image") and we have more models, try next
      const isErrorNotice = result.startsWith(`[Image "`);
      if (!isErrorNotice) return result;
      // If it's an HTTP error notice (non-retryable), still try next local model before giving up
      if (chain.indexOf(m) < chain.length - 1) continue;
      return result;
    }
    // null = endpoint unreachable, try next model
  }

  // Also unload any attempted models that may still be loaded (extra safety)
  for (const m of attempted) queueMicrotask(() => { void unloadModel(m); });

  if (FALLBACK_API_URL && FALLBACK_API_URL !== API_URL) {
    const fb = await tryDescribe(
      FALLBACK_API_URL, FALLBACK_API_KEY, FALLBACK_VISION_MODEL,
      dataUrl, mime, filename, 2,
    );
    if (fb !== null) return fb;
  }
  return `[Image "${filename ?? "pasted image"}" could not be processed (local vision and cloud fallback both failed). ` +
    `The user attached an image of type ${mime}. Ask the user to describe it or paste the text content.]`;
}

export default (async () => {
  // Cache: dataUrl hash -> description (avoids re-processing repeated images)
  const cache = new Map<string, string>();

  return {
    "experimental.chat.messages.transform": async (
      _input: {},
      output: {
        messages: { info: any; parts: any[] }[];
      },
    ) => {
      for (const msg of output.messages) {
        // Only transform user messages
        if (!msg.info || msg.info.role !== "user") continue;

        // Vision models resolved live (env -> model-sync cache -> default).
        // Explicitly disabled (VISION_MODEL=off) -> leave images untouched.
        const visionModels = resolveVisionModels();
        if (!visionModels) continue;
        const visionModel = visionModels[0];

        // If the current model IS any vision model, let it see the image natively.
        const modelID: string = msg.info.model?.modelID ?? "";
        const norm = modelID.replace(/^[^/]+\//, "");
        if (visionModels.some((vm) => norm === vm.replace(/^[^/]+\//, ""))) continue;

        const parts = msg.parts;
        for (let i = parts.length - 1; i >= 0; i--) {
          const part = parts[i];
          if (!part || part.type !== "file") continue;
          if (typeof part.mime !== "string" || !part.mime.startsWith("image/")) {
            continue;
          }

          let dataUrl: string = part.url ?? "";
          if (!dataUrl.startsWith("data:")) {
            if (/^https?:\/\//.test(dataUrl)) {
              // Remote URL (e.g. pasted from a browser) — the vision API
              // fetches it itself; pass through as the image_url.
            } else {
              // file:// URL or plain path -> read the REAL bytes from disk.
              const filePath = dataUrl.startsWith("file://")
                ? decodeURIComponent(dataUrl.slice("file://".length))
                : dataUrl;
              try {
                const buf = fs.readFileSync(filePath);
                dataUrl = `data:${part.mime};base64,${buf.toString("base64")}`;
              } catch {
                parts.splice(i, 1, {
                  id: part.id,
                  sessionID: part.sessionID,
                  messageID: part.messageID,
                  type: "text",
                  text: `[Image: "${part.filename ?? filePath}" (${part.mime}) — attached as a file but could not be read from disk. Ask the user to re-attach it or describe it.]`,
                });
                continue;
              }
            }
          }

          const key = hash(dataUrl);
          let description = cache.get(key);
          if (!description) {
            const chainStr = visionModels.join(",");
            description = await describeImage(dataUrl, part.mime, part.filename, chainStr);
            cache.set(key, description);
          }

          // Replace the image FilePart with a TextPart (in-place splice!)
          parts.splice(i, 1, {
            id: part.id,
            sessionID: part.sessionID,
            messageID: part.messageID,
            type: "text",
            text: `[Image: "${part.filename ?? "pasted image"}" (${part.mime}) — visual description extracted automatically]\n${description}`,
          });
        }
      }
    },
  };
}) satisfies Plugin;