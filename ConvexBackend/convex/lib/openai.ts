/**
 * The ONE OpenAI adapter. Every model call in this backend goes through
 * `callOpenAI` — solo, group and deep dives alike. There is deliberately no
 * second client anywhere (and, as of the backend boundary work, none on the
 * device either): the API key exists only as `OPENAI_API_KEY` in the Convex
 * environment.
 *
 * The returned `usage` block is the raw material for the cost/latency questions
 * the plan refuses to answer by estimate. Callers log it; nothing here claims a
 * number it did not measure.
 */

/** Single provider/model selection point for the whole backend. */
export const OPENAI_MODEL = "gpt-4o-mini";
/**
 * Near You proposes named places from model knowledge and MapKit then verifies
 * every one, so the expensive half of the old design — a forced hosted web
 * search on a mid-tier model — bought accuracy the verification pass now
 * provides for free. Luna is the cheap tier, which matters because this
 * component deliberately over-requests: roughly double the places the screen
 * needs, since the map gate discards whatever cannot be found.
 *
 * What is genuinely lost is one-off timeliness — a pop-up opening this week.
 * Recurring rhythms a host would actually mention ("Saturday morning market")
 * are stable enough to sit in model knowledge.
 */
export const NEAR_YOU_MODEL = "gpt-5.6-luna";
/**
 * Worth It is a compact judgment task: it benefits from stronger taste and
 * personalization, but does not need the deeper reasoning budget of Sol.
 */
export const WORTH_IT_MODEL = "gpt-5.6-luna";

export type OpenAIReasoningEffort =
  | "none"
  | "low"
  | "medium"
  | "high"
  | "xhigh"
  | "max";

export type OpenAIWebSource = {
  url: string;
  title: string | null;
};

export type OpenAIUsage = {
  inputTokens: number;
  cachedInputTokens: number;
  outputTokens: number;
  reasoningTokens: number;
};

export type OpenAIResult = {
  /** Parsed structured output — already validated against `schema` by strict mode. */
  data: unknown;
  usage: OpenAIUsage;
  /** Wall-clock milliseconds for the provider call itself. */
  durationMs: number;
  /** Sources consulted by hosted web search, empty for ordinary components. */
  webSources: OpenAIWebSource[];
  /** Paid search actions reported by the provider, retained for spend telemetry. */
  webSearchCalls: number;
  /**
   * The model actually billed. Recorded rather than re-derived from the
   * component later, because component→model routing changes over time and a
   * cost figure computed from today's routing would silently misprice every
   * historical row.
   */
  model: string;
};

/**
 * Errors carry a short, stable, machine-readable code (never a raw provider
 * message) because the code is persisted as `ComponentState.failed(code:)` and
 * shown to users through a lookup table on the client.
 */
export class OpenAIError extends Error {
  /**
   * What the failed call still consumed, when the provider told us.
   *
   * A truncation is the case that matters: `incomplete_max_output_tokens`
   * arrives with a full usage block, and its `outputTokens` is exactly the
   * ceiling that was too low. Throwing that away and recording zeros — which is
   * what happened before — would leave the one measurement V13 asks for
   * missing from precisely the runs that needed it.
   */
  constructor(
    public readonly code: string,
    public readonly usage?: OpenAIUsage,
    public readonly durationMs?: number,
    public readonly providerAttempts: number = 1,
  ) {
    super(code);
    this.name = "OpenAIError";
  }
}

export async function callOpenAI(args: {
  systemPrompt: string;
  userPrompt: string;
  schema: unknown;
  schemaName: string;
  maxOutputTokens: number;
  model?: string;
  reasoning?: { effort: OpenAIReasoningEffort };
  webSearch?: {
    /** Requested provider-side ceiling; actual paid actions are measured separately. */
    maxToolCalls: number;
    /** City/neighbourhood context only. Never an accommodation address. */
    approximateLocation?: {
      city?: string;
      region?: string;
      country?: string;
      timezone?: string;
    };
  };
}): Promise<OpenAIResult> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new OpenAIError("missing_openai_key");

  const startedAt = Date.now();
  let resp: Response;
  try {
    resp = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(buildOpenAIRequestBody(args)),
    });
  } catch {
    throw new OpenAIError("network_error");
  }

  if (!resp.ok) {
    // 429/5xx are the retryable ones; the client distinguishes on the code.
    throw new OpenAIError(`openai_http_${resp.status}`);
  }

  const json = (await resp.json()) as Record<string, unknown>;
  const durationMs = Date.now() - startedAt;
  const usage = extractUsage(json);

  if (json.status === "incomplete") {
    // Almost always `max_output_tokens`. Surfacing it distinctly — with the
    // usage block attached — is what lets the token ceiling be re-derived from
    // measurement rather than guesswork.
    const reason = (json.incomplete_details as Record<string, unknown> | undefined)?.reason;
    throw new OpenAIError(
      typeof reason === "string" ? `incomplete_${reason}` : "output_incomplete",
      usage,
      durationMs,
    );
  }

  const text = extractOutputText(json);
  if (!text) throw new OpenAIError("missing_text_content", usage, durationMs);

  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch {
    throw new OpenAIError("schema_decode_failed", usage, durationMs);
  }

  const webSources = extractWebSources(json);
  const webSearchCalls = countWebSearchCalls(json);
  return {
    data,
    usage,
    durationMs,
    webSources,
    webSearchCalls,
    model: args.model ?? OPENAI_MODEL,
  };
}

/** Pure request construction keeps privacy and cost controls regression-testable. */
export function buildOpenAIRequestBody(args: {
  systemPrompt: string;
  userPrompt: string;
  schema: unknown;
  schemaName: string;
  maxOutputTokens: number;
  model?: string;
  reasoning?: { effort: OpenAIReasoningEffort };
  webSearch?: {
    maxToolCalls: number;
    approximateLocation?: {
      city?: string;
      region?: string;
      country?: string;
      timezone?: string;
    };
  };
}): Record<string, unknown> {
  const body: Record<string, unknown> = {
    model: args.model ?? OPENAI_MODEL,
    instructions: args.systemPrompt,
    input: args.userPrompt,
    max_output_tokens: args.maxOutputTokens,
    store: false,
    text: {
      format: {
        type: "json_schema",
        name: args.schemaName,
        schema: args.schema,
        strict: true,
      },
    },
  };
  if (args.reasoning) body.reasoning = args.reasoning;
  if (args.webSearch) {
    const userLocation = args.webSearch.approximateLocation;
    body.tools = [{
      type: "web_search",
      search_context_size: "medium",
      ...(userLocation && Object.values(userLocation).some(Boolean)
        ? { user_location: { type: "approximate", ...userLocation } }
        : {}),
    }];
    body.tool_choice = "required";
    body.max_tool_calls = Math.max(1, Math.min(2, args.webSearch.maxToolCalls));
    body.include = ["web_search_call.action.sources"];
  }
  return body;
}

function extractUsage(json: Record<string, unknown>): OpenAIUsage {
  const usage = (json.usage ?? {}) as Record<string, unknown>;
  const inputDetails = (usage.input_tokens_details ?? {}) as Record<string, unknown>;
  const outputDetails = (usage.output_tokens_details ?? {}) as Record<string, unknown>;
  return {
    inputTokens: num(usage.input_tokens),
    cachedInputTokens: num(inputDetails.cached_tokens),
    outputTokens: num(usage.output_tokens),
    reasoningTokens: num(outputDetails.reasoning_tokens),
  };
}

function num(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function extractOutputText(json: Record<string, unknown>): string | null {
  const output = json.output;
  if (!Array.isArray(output)) return null;
  for (const item of output) {
    const content = (item as Record<string, unknown>)?.content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      const p = part as Record<string, unknown>;
      if (p.type === "refusal") throw new OpenAIError("refused");
      if ((p.type === "output_text" || p.type === "text") && typeof p.text === "string") {
        return p.text;
      }
    }
  }
  return null;
}

export function countWebSearchCalls(json: Record<string, unknown>): number {
  return Array.isArray(json.output)
    ? json.output.filter(
      (item) => {
        const record = item as Record<string, unknown>;
        const action = record.action as Record<string, unknown> | undefined;
        // The API also emits web_search_call items for open_page and
        // find_in_page. Official pricing charges the search action, so spend
        // telemetry must not count those navigation steps as paid searches.
        return record.type === "web_search_call" && action?.type === "search";
      },
    ).length
    : 0;
}

function extractWebSources(json: Record<string, unknown>): OpenAIWebSource[] {
  const found = new Map<string, OpenAIWebSource>();
  const add = (value: unknown) => {
    if (typeof value !== "object" || value === null) return;
    const record = value as Record<string, unknown>;
    if (typeof record.url !== "string" || !isHTTPURL(record.url)) return;
    found.set(record.url, {
      url: record.url,
      title: typeof record.title === "string" && record.title.trim()
        ? record.title.trim()
        : null,
    });
  };

  if (!Array.isArray(json.output)) return [];
  for (const rawItem of json.output) {
    const item = rawItem as Record<string, unknown>;
    const action = item.action as Record<string, unknown> | undefined;
    if (Array.isArray(action?.sources)) action.sources.forEach(add);
    if (Array.isArray(item.sources)) item.sources.forEach(add);
    if (!Array.isArray(item.content)) continue;
    for (const rawPart of item.content) {
      const part = rawPart as Record<string, unknown>;
      if (Array.isArray(part.annotations)) part.annotations.forEach(add);
    }
  }
  return [...found.values()];
}

function isHTTPURL(raw: string): boolean {
  try {
    const url = new URL(raw);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}
