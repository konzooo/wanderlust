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
      body: JSON.stringify({
        model: OPENAI_MODEL,
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
      }),
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

  return { data, usage, durationMs };
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
