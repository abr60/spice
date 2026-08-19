// vision-bridge.ts
// Automatically processes images pasted/referenced in chat before they reach a
// text-only model. The image is sent to a vision-capable model (Mimo), and the
// returned text description replaces the image in the message.
//
// Pipeline:
//   user pastes image  ->  hook detects image FilePart  ->  Mimo describes it
//        ->  image part replaced with "[Image description] ..." text
//        ->  main model (DeepSeek/Big Pickle) receives text only  ->  seamless
//
// Config (optional env vars):
//   VISION_MODEL   (default: mimo-v2.5-free)
//   VISION_API_URL (default: https://opencode.ai/zen/v1/chat/completions)
//   VISION_API_KEY (default: public)

import type { Plugin } from "@opencode-ai/plugin";

const API_URL =
  process.env.VISION_API_URL ?? "https://opencode.ai/zen/v1/chat/completions";
const API_KEY = process.env.VISION_API_KEY ?? "public";
const VISION_MODEL = process.env.VISION_MODEL ?? "mimo-v2.5-free";
const MAX_RETRIES = 4;

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

async function describeImage(
  dataUrl: string,
  mime: string,
  filename?: string,
): Promise<string> {
  let lastError = "";
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const resp = await fetch(API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${API_KEY}`,
        },
        body: JSON.stringify({
          model: VISION_MODEL,
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
        // Rate limited (free tier) or 5xx -> wait and retry with backoff
        if (status === 429 || errType === "FreeUsageLimitError" || status >= 500) {
          lastError = `${status} ${json?.error?.message ?? "rate limited"}`;
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
    } catch (err: any) {
      lastError = String(err?.message ?? err);
      await sleep(attempt * 1500);
    }
  }
  return `[Image "${filename ?? "pasted image"}" could not be processed (${lastError || "unknown error"}). ` +
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

        // If the user is already on a vision-capable model, let it see the image
        const modelID: string = msg.info.model?.modelID ?? "";
        if (/mimo/i.test(modelID)) continue;

        const parts = msg.parts;
        for (let i = parts.length - 1; i >= 0; i--) {
          const part = parts[i];
          if (!part || part.type !== "file") continue;
          if (typeof part.mime !== "string" || !part.mime.startsWith("image/")) {
            continue;
          }

          const dataUrl: string = part.url ?? "";
          if (!dataUrl.startsWith("data:")) continue; // not inline image data

          const key = hash(dataUrl);
          let description = cache.get(key);
          if (!description) {
            description = await describeImage(dataUrl, part.mime, part.filename);
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