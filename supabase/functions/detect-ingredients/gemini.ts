// Ingredient recognition with Google Gemini, through the Interactions API.
// This is the only file that knows about the provider: to try another vision
// model, write another `Detector` and wire it up in index.ts.

/** Returns the ingredient names recognized in a base64-encoded photo. */
export type Detector = (photo: Photo) => Promise<string[]>;

export interface Photo {
  /** Base64-encoded image bytes. */
  data: string;
  mimeType: string;
}

/** Why the provider couldn't answer. */
export type ProviderErrorKind = "busy" | "timeout" | "failed";

export class ProviderError extends Error {
  constructor(readonly kind: ProviderErrorKind, message: string) {
    super(message);
    this.name = "ProviderError";
  }
}

const endpoint =
  "https://generativelanguage.googleapis.com/v1beta/interactions";

// Pins the request and response format the parsing below was written for.
const apiRevision = "2026-05-20";

const instructions =
  `You list the food ingredients visible in photos for a recipe app.
- Name each distinct ingredient once, in English, lowercase and singular, using its everyday name ("tomato", "egg", "cheddar cheese", "soy sauce").
- Read labels on packages, jars and bottles when they say what is inside.
- Skip anything you would not cook with: prepared dishes, utensils, appliances, packaging, people.
- Only list what you can see. If there is no food, return an empty list.`;

const outputSchema = {
  type: "object",
  properties: {
    ingredients: {
      type: "array",
      items: { type: "string" },
      maxItems: 50,
    },
  },
  required: ["ingredients"],
};

export interface GeminiOptions {
  apiKey: string;
  model: string;
  timeoutMs?: number;
  /** Replaced in tests. */
  fetch?: typeof fetch;
}

export function createGeminiDetector(options: GeminiOptions): Detector {
  const send = options.fetch ?? fetch;
  const timeoutMs = options.timeoutMs ?? 30_000;

  return async (photo) => {
    let response: Response;
    try {
      response = await send(endpoint, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": options.apiKey,
          "api-revision": apiRevision,
        },
        body: JSON.stringify({
          model: options.model,
          // Photos are processed and forgotten, never kept by the provider.
          store: false,
          system_instruction: instructions,
          input: [
            { type: "image", mime_type: photo.mimeType, data: photo.data },
            { type: "text", text: "List the ingredients in this photo." },
          ],
          response_format: {
            type: "text",
            mime_type: "application/json",
            schema: outputSchema,
          },
        }),
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (error) {
      if (error instanceof DOMException && error.name === "TimeoutError") {
        throw new ProviderError("timeout", `No answer within ${timeoutMs} ms`);
      }
      throw new ProviderError("failed", `Request failed: ${error}`);
    }

    if (response.status === 429) {
      await response.body?.cancel();
      throw new ProviderError("busy", "Gemini quota exceeded");
    }
    if (!response.ok) {
      const detail = (await response.text()).slice(0, 500);
      throw new ProviderError("failed", `Gemini ${response.status}: ${detail}`);
    }

    let interaction: unknown;
    try {
      interaction = await response.json();
    } catch {
      throw new ProviderError("failed", "Gemini returned invalid JSON");
    }
    return ingredientNames(interaction);
  };
}

type Json = Record<string, unknown>;

/** Reads the structured answer out of a finished interaction. */
function ingredientNames(interaction: unknown): string[] {
  const { status, steps } = (interaction ?? {}) as Json;
  if (status !== undefined && status !== "completed") {
    throw new ProviderError("failed", `Interaction ended as ${status}`);
  }

  // The answer is the text of the last model_output step.
  const output = (Array.isArray(steps) ? (steps as Json[]) : []).findLast(
    (step) => step?.type === "model_output",
  );
  const parts = Array.isArray(output?.content)
    ? (output.content as Json[])
    : [];
  const text = parts
    .flatMap((part) =>
      part?.type === "text" && typeof part.text === "string" ? [part.text] : []
    )
    .join("");

  let answer: unknown;
  try {
    answer = JSON.parse(text);
  } catch {
    throw new ProviderError("failed", "Gemini answer is not JSON");
  }
  const names = (answer as { ingredients?: unknown })?.ingredients;
  if (!Array.isArray(names)) {
    throw new ProviderError("failed", "Gemini answer has no ingredients list");
  }
  return names.filter((name): name is string => typeof name === "string");
}
