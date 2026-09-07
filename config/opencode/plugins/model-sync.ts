// model-sync.ts
// Per-launch dynamic model resolution for the `opencode` (Zen) provider.
//
// Every opencode launch, this plugin:
//   1. Reads the session-accepted model set (`opencode models opencode --pure`).
//      This is the exact set opencode will start sessions with — the ground truth.
//   2. Fetches the live serving set (Zen GET /v1/models, public key, ~200ms).
//   3. Resolves one model per role slot from the curated BASELINE below:
//        - same-family newer version appears -> auto-upgrade (e.g. muse 1.2 -> 1.3)
//        - baseline model leaves the accepted set -> category fallback pick
//        - brand-new picks are verified with a 1-token probe before use
//   4. Applies the resolved set via the `config` hook (runtime only —
//      opencode.json on disk is never touched) and notifies on change.
//
// Design rules:
//   - Free-only. Never touches slots pinned to other providers (ollama, ...).
//   - Fail-open: any error, timeout (>10s total), or offline -> launch normally.
//   - No recursion: children spawned for `opencode models` get MODEL_SYNC_CHILD=1.
//
// Knobs (env):
//   MODEL_SYNC_DISABLE=1   -> no-op
//   MODEL_SYNC_PIN="plan=opencode/big-pickle,build=opencode/muse-spark-1.3-contributor-free"
//   MODEL_SYNC_RESEED=1    -> ignore baseline/cache, full category re-pick
//   MODEL_SYNC_DEBUG=1     -> verbose stderr logging
//   MODEL_SYNC_API_URL     -> override Zen models endpoint (testing)

import type { Plugin } from "@opencode-ai/plugin";
import fs from "node:fs";
import path from "node:path";

type Slot = "main" | "plan" | "build" | "small" | "quickfix" | "explore" | "vision";
type Category = "coder" | "architect" | "utility" | "vision";

const PROVIDER = "opencode";
const HOME = process.env.HOME ?? "/home/abr";
const CACHE_PATH = path.join(HOME, ".cache/opencode/model-sync.json");
const MODELS_JSON = path.join(HOME, ".cache/opencode/models.json");
const ZEN_MODELS_URL =
  process.env.MODEL_SYNC_API_URL ?? "https://opencode.ai/zen/v1/models";
const ZEN_CHAT_URL = "https://opencode.ai/zen/v1/chat/completions";
const ZEN_KEY = "public";
const OVERALL_TIMEOUT_MS = 25_000;
const PROBE_TIMEOUT_MS = 12_000;
const RETRY_AFTER_MS = 3_600_000; // re-probe a failed model at most once per hour

const DISABLED = process.env.MODEL_SYNC_DISABLE === "1";
const IS_CHILD = process.env.MODEL_SYNC_CHILD === "1";
const RESEED = process.env.MODEL_SYNC_RESEED === "1";
const DEBUG = process.env.MODEL_SYNC_DEBUG === "1";

// abr's curated role table. The sync keeps this fresh, it does not replace it.
const BASELINE: Record<Slot, string> = {
  main: "opencode/muse-spark-1.2-contributor-free",
  plan: "opencode/big-pickle",
  build: "opencode/muse-spark-1.2-contributor-free",
  small: "opencode/nemotron-3.5-lightning-free",
  quickfix: "opencode/nemotron-3.5-lightning-free",
  explore: "opencode/nemotron-3.5-lightning-free",
  vision: "opencode/mimo-v2.5-free",
};

const SLOT_CATEGORY: Record<Slot, Category> = {
  main: "coder",
  plan: "architect",
  build: "coder",
  small: "utility",
  quickfix: "utility",
  explore: "utility",
  vision: "vision",
};

// Zero-cost models that don't carry a `-free` suffix.
const FREE_ALLOWLIST = new Set(["big-pickle", "grok-code"]);

interface Meta {
  costIn: number;
  costOut: number;
  context: number;
}
interface CacheFile {
  updatedAt: string;
  slots: Partial<Record<Slot, string>>;
  confirmed: string[];
  failedAt?: Record<string, string>;
}
interface Change {
  slot: Slot;
  from: string;
  to: string;
  reason: string;
}

const log = (...a: any[]) => {
  if (DEBUG) console.info("[model-sync]", ...a);
};
const bare = (id: string) => id.replace(/^opencode\//, "");
const full = (id: string) => (id.startsWith("opencode/") ? id : `opencode/${id}`);

// "muse-spark-1.2-contributor-free" -> "muse-spark-#-contributor-free"
function familyKey(id: string): string {
  return bare(id)
    .toLowerCase()
    .replace(/\d+(\.\d+)+/g, "#")
    .replace(/\d+/g, "#");
}

// Compare embedded version numbers: 1.3 > 1.2. Returns >0 if a is newer.
function compareVersion(a: string, b: string): number {
  const pa = (bare(a).match(/\d+/g) ?? []).map(Number);
  const pb = (bare(b).match(/\d+/g) ?? []).map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) return d;
  }
  return 0;
}

function readCache(): CacheFile | null {
  try {
    const raw = fs.readFileSync(CACHE_PATH, "utf8");
    const c = JSON.parse(raw) as CacheFile;
    if (!c || typeof c !== "object" || !c.slots) return null;
    return c;
  } catch {
    return null;
  }
}

function writeCache(slots: Record<Slot, string>, confirmed: string[], failedAt: Record<string, string>) {
  try {
    fs.mkdirSync(path.dirname(CACHE_PATH), { recursive: true });
    fs.writeFileSync(
      CACHE_PATH,
      JSON.stringify(
        { updatedAt: new Date().toISOString(), slots, confirmed, failedAt } satisfies CacheFile,
        null,
        2,
      ),
    );
  } catch (err) {
    log("cache write failed:", String(err));
  }
}

// Cost/context metadata from opencode's own models cache (best-effort).
function readMetas(): Record<string, Meta> {
  try {
    const j = JSON.parse(fs.readFileSync(MODELS_JSON, "utf8"));
    const models = j?.[PROVIDER]?.models ?? j?.models ?? {};
    const out: Record<string, Meta> = {};
    for (const [id, m] of Object.entries<any>(models)) {
      out[full(id)] = {
        costIn: m?.cost?.input ?? m?.cost?.costIn ?? 0,
        costOut: m?.cost?.output ?? m?.cost?.costOut ?? 0,
        context: m?.limit?.context ?? 0,
      };
    }
    return out;
  } catch (err) {
    log("models.json read failed:", String(err));
    return {};
  }
}

function isFree(id: string, metas: Record<string, Meta>): boolean {
  const m = metas[full(id)];
  if (m) return m.costIn === 0 && m.costOut === 0;
  const b = bare(id);
  return b.endsWith("-free") || FREE_ALLOWLIST.has(b);
}

// The exact set opencode will start sessions with. Runs with --pure plus a
// guard env so a child can never recurse back into this plugin.
async function acceptedModels($: any): Promise<string[] | null> {
  try {
    const raw: string = await $`opencode models ${PROVIDER} --pure`
      .quiet()
      .env({ ...process.env, MODEL_SYNC_CHILD: "1" })
      .text();
    const ids = raw
      .replace(/\x1b\[[0-9;]*m/g, "")
      .split("\n")
      .map((l) => l.trim())
      .filter((l) => l.startsWith(`${PROVIDER}/`));
    log("accepted:", ids.join(",") || "(empty)");
    return ids.length > 0 ? ids : null;
  } catch (err) {
    log("accepted list failed:", String(err));
    return null;
  }
}

// Live serving set from Zen (tiny response, public key).
async function liveModels(): Promise<Set<string> | null> {
  try {
    const r = await fetch(ZEN_MODELS_URL, {
      headers: { Authorization: `Bearer ${ZEN_KEY}` },
      signal: AbortSignal.timeout(4000),
    });
    if (!r.ok) return null;
    const j: any = await r.json();
    const all = new Set<string>((j?.data ?? []).map((m: any) => String(m?.id)));
    const free = new Set<string>([...all].filter((id) => {
      const b = bare(id);
      return b.endsWith("-free") || FREE_ALLOWLIST.has(b);
    }));
    log("free live count:", free.size);
    return free;
  } catch (err) {
    log("live fetch failed:", String(err));
    return null;
  }
}

// 1-token existence probe. 200 or rate-limited => alive; 404/unknown-id => dead.
async function probe(bareId: string): Promise<"alive" | "dead" | "unknown"> {
  try {
    const r = await fetch(ZEN_CHAT_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${ZEN_KEY}`,
      },
      body: JSON.stringify({
        model: bareId,
        messages: [{ role: "user", content: "ping" }],
        max_tokens: 1,
      }),
      signal: AbortSignal.timeout(PROBE_TIMEOUT_MS),
    });
    if (r.ok) return "alive";
    const j: any = await r.json().catch(() => null);
    const msg = `${r.status} ${j?.error?.message ?? ""} ${j?.error?.type ?? ""}`;
    log(`probe ${bareId}:`, msg);
    if (r.status === 404 || /not exist|not found|invalid model|no such model/i.test(msg))
      return "dead";
    if (r.status === 429 || /limit|quota|overload|busy|rate/i.test(msg)) return "alive";
    if (r.status === 401 || r.status === 403) return "dead";
    return "unknown";
  } catch (err) {
    log(`probe ${bareId} error:`, String(err));
    return "unknown";
  }
}

function parsePins(): Partial<Record<Slot, string>> {
  const out: Partial<Record<Slot, string>> = {};
  const raw = process.env.MODEL_SYNC_PIN ?? "";
  for (const part of raw.split(",")) {
    const [k, v] = part.split("=").map((s) => s?.trim());
    if (k && v && k in BASELINE) out[k as Slot] = full(v);
  }
  return out;
}

function scoreCandidate(b: string, cat: Category, meta?: Meta): number {
  const s = b.toLowerCase();
  let sc = 0;
  if (cat === "vision") {
    if (!/mimo|vision|omni|vl\b|image/i.test(s)) return -Infinity;
    if (/mimo/i.test(s)) sc += 100;
  }
  if (cat === "architect") {
    if (/ultra|opus|pro\b|max|thinking|deep|premier/i.test(s)) sc += 50;
  }
  if (cat === "coder") {
    if (/muse|code|coder|codex|sonnet|gpt|qwen|glm/i.test(s)) sc += 50;
  }
  if (cat === "utility") {
    if (/lightning|flash|lite|nano|mini|tiny|fin\b|haiku|fast/i.test(s)) sc += 50;
    if (meta?.context) sc += 1e6 / meta.context; // prefer lighter for cheap slots
  } else if (meta?.context) {
    sc += Math.log10(meta.context);
  }
  return sc;
}

interface Resolution {
  slots: Record<Slot, string>;
  changes: Change[];
  confirmed: string[];
  failedAt: Record<string, string>;
}

async function resolve($: any): Promise<Resolution | null> {
  const cache = readCache();
  const [accepted, live] = await Promise.all([acceptedModels($), liveModels()]);
  if (!accepted || accepted.length === 0) {
    log("no accepted set -> fail-open");
    return null;
  }
  const acceptedSet = new Set(accepted);
  const metas = readMetas();
  const pins = parsePins();
  const prevSlots = cache?.slots ?? {};
  const confirmed = new Set(cache?.confirmed ?? []);
  const failedAt: Record<string, string> = cache?.failedAt ?? {};
  const inFlight = new Map<string, Promise<boolean>>();
  const slots = {} as Record<Slot, string>;
  const changes: Change[] = [];

  const failedRecently = (id: string) => {
    const ts = failedAt[id];
    if (!ts) return false;
    return Date.now() - new Date(ts).getTime() < RETRY_AFTER_MS;
  };

  const ensureConfirmed = async (id: string): Promise<boolean> => {
    if (confirmed.has(id)) return true;
    if (failedRecently(id)) {
      log(`${id} failed recently, skipping probe`);
      return false;
    }
    const pendingProbe = inFlight.get(id);
    if (pendingProbe) return pendingProbe;
    const p = probe(bare(id)).then((st) => {
      inFlight.delete(id);
      if (st === "alive") {
        confirmed.add(id);
        delete failedAt[id];
        return true;
      }
      failedAt[id] = new Date().toISOString();
      return false;
    });
    inFlight.set(id, p);
    return p;
  };

  for (const slot of Object.keys(BASELINE) as Slot[]) {
    const cat = SLOT_CATEGORY[slot];

    // 1. Explicit pin wins (validated against the accepted set).
    const pin = pins[slot];
    if (pin) {
      if (acceptedSet.has(pin) && (await ensureConfirmed(pin))) {
        slots[slot] = pin;
        if (prevSlots[slot] && prevSlots[slot] !== pin)
          changes.push({ slot, from: prevSlots[slot]!, to: pin, reason: "pinned" });
        continue;
      }
      log(`pin ${slot}=${pin} not usable, falling through`);
    }

    if (RESEED) {
      const pick = await pickByCategory(slot, cat, acceptedSet, live, metas, ensureConfirmed);
      if (pick) {
        slots[slot] = pick;
        if (prevSlots[slot] && prevSlots[slot] !== pick)
          changes.push({ slot, from: prevSlots[slot]!, to: pick, reason: "reseed" });
      } else if (prevSlots[slot]) slots[slot] = prevSlots[slot]!;
      continue;
    }

    const cur = prevSlots[slot] ?? BASELINE[slot];
    const curAccepted = acceptedSet.has(cur);
    const curLive = !live || live.has(bare(cur));

    // 2. Current model healthy -> keep, but check for same-family upgrade.
    if (curAccepted && curLive) {
      const fam = familyKey(cur);
      const newer = accepted
        .filter(
          (id) =>
            familyKey(id) === fam &&
            compareVersion(id, cur) > 0 &&
            (!live || live.has(bare(id))) &&
            isFree(id, metas),
        )
        .sort(compareVersion)
        .pop();
      if (newer && newer !== cur) {
        if (await ensureConfirmed(newer)) {
          slots[slot] = newer;
          changes.push({ slot, from: cur, to: newer, reason: "family upgrade" });
          continue;
        }
        log(`${newer} probe failed, keeping ${cur}`);
      }
      slots[slot] = cur;
      continue;
    }

    // 3. Current model suspect (missing from accepted/live) -> probe to confirm.
    if (curAccepted && live && !curLive) {
      const st = await probe(bare(cur));
      if (st === "alive" || st === "unknown") {
        slots[slot] = cur; // fail-open: keep on uncertainty
        continue;
      }
    }

    // 4. Replace via category fallback.
    const from = curAccepted || prevSlots[slot] ? cur : `${cur} (gone)`;
    const pick = await pickByCategory(slot, cat, acceptedSet, live, metas, ensureConfirmed);
    if (pick) {
      slots[slot] = pick;
      changes.push({ slot, from, to: pick, reason: "replacement" });
    } else if (cur) {
      slots[slot] = cur; // nothing better: keep (fail-open)
      log(`no fallback for ${slot}, keeping ${cur}`);
    }
  }

  return { slots, changes, confirmed: [...confirmed], failedAt };
}

async function pickByCategory(
  slot: Slot,
  cat: Category,
  acceptedSet: Set<string>,
  live: Set<string> | null,
  metas: Record<string, Meta>,
  ensureConfirmed: (id: string) => Promise<boolean>,
): Promise<string | null> {
  void slot;
  const ranked = [...acceptedSet]
    .filter((id) => (!live || live.has(bare(id))) && isFree(id, metas))
    .map((id) => ({ id, sc: scoreCandidate(bare(id), cat, metas[full(id)]) }))
    .filter((c) => c.sc > -Infinity)
    .sort((a, b) => b.sc - a.sc || (a.id < b.id ? -1 : 1));
  for (const c of ranked) {
    if (await ensureConfirmed(c.id)) return c.id;
  }
  return null;
}

async function notify($: any, client: any, changes: Change[]) {
  const short = (id: string) => bare(id);
  const body = changes.map((c) => `${c.slot}: ${short(c.from)} → ${short(c.to)} (${c.reason})`).join("\n");
  console.info(`[model-sync] models updated:\n${body}`);
  try {
    await client?.app?.log?.({
      body: { service: "model-sync", level: "info", message: `models updated:\n${body}` },
    });
  } catch {}
  try {
    await $`notify-send -a opencode "model-sync: models updated" ${body}`.quiet();
  } catch {}
}

export default (async ({ client, $ }) => {
  if (DISABLED || IS_CHILD) return {};

  // Kick off resolution immediately; the config hook awaits it.
  const pending = Promise.race([
    resolve($).catch((err) => {
      log("resolve failed:", String(err));
      return null;
    }),
    new Promise<null>((r) => setTimeout(() => r(null), OVERALL_TIMEOUT_MS)),
  ]);

  return {
    config: async (cfg: any) => {
      const result = await pending;
      if (!result) {
        log("no resolution -> config untouched");
        return;
      }
      const { slots, changes, confirmed, failedAt } = result;
      const usable = (v: any) => typeof v === "string" && v.startsWith(`${PROVIDER}/`);

      // Top-level default model (drives `general` and any agent without a model).
      if (!cfg.model || usable(cfg.model)) cfg.model = slots.main;
      if (!cfg.small_model || usable(cfg.small_model)) cfg.small_model = slots.small;

      const agentSlot: Record<string, Slot> = {
        plan: "plan",
        build: "build",
        quickfix: "quickfix",
        explore: "explore",
        vision: "vision",
      };
      for (const [name, slot] of Object.entries(agentSlot)) {
        const a = cfg.agent?.[name];
        // Local pins (e.g. ollama/qwen2.5-coder:3b for explore/quickfix/small)
        // always win: never overwrite a model from another provider.
        const isLocalPin = typeof a?.model === "string" && !usable(a.model);
        if (a && !isLocalPin && (!a.model || usable(a.model))) a.model = slots[slot];
      }

      writeCache(slots, Object.values(slots).filter((id) => confirmed.includes(id)), failedAt);
      if (changes.length > 0) await notify($, client, changes);
      else log("slots unchanged");
    },
  };
}) satisfies Plugin;
