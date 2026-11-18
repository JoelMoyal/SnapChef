import { type Detector, ProviderError } from "./gemini.ts";

/** Formats the vision model accepts. */
export const supportedMimeTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);

/** The app sends photos resized to about 0.5 MB, so this is generous. */
export const maxImageBytes = 5 * 1024 * 1024;

const maxIngredients = 50;
const maxNameLength = 60;
const base64 = /^[A-Za-z0-9+/]+={0,2}$/;

/**
 * POST { "image": "<base64>", "mimeType": "image/jpeg" }
 *
 * - 200 { "ingredients": [{ "name": "tomato" }, ...] }, possibly empty
 * - 4xx/5xx { "error": "<code>", "message": "<text>" }
 *
 * Pass a null [detect] when the provider isn't configured.
 */
export function createHandler(detect: Detector | null) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") {
      return failure(405, "method_not_allowed", "Use POST.");
    }
    if (detect === null) {
      console.error("GEMINI_API_KEY is not set");
      return failure(500, "not_configured", "Recognition is not set up yet.");
    }

    // Base64 is 4/3 the size of the bytes it encodes; allow for the JSON too.
    const length = Number(req.headers.get("content-length") ?? 0);
    if (length > maxImageBytes * 1.4) {
      return failure(413, "image_too_large", "The photo is too large.");
    }

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return failure(400, "invalid_request", "Send a JSON body.");
    }
    const { image, mimeType } = (body ?? {}) as Record<string, unknown>;
    if (typeof image !== "string") {
      return failure(400, "invalid_request", "image must be base64 text.");
    }
    if (image.length * 0.75 > maxImageBytes) {
      return failure(413, "image_too_large", "The photo is too large.");
    }
    if (!base64.test(image)) {
      return failure(400, "invalid_request", "image must be base64 text.");
    }
    if (typeof mimeType !== "string" || !supportedMimeTypes.has(mimeType)) {
      return failure(
        415,
        "unsupported_image",
        "Send a JPEG, PNG, WebP or HEIC photo.",
      );
    }

    try {
      const names = await detect({ data: image, mimeType });
      return Response.json({
        ingredients: tidy(names).map((name) => ({ name })),
      });
    } catch (error) {
      if (!(error instanceof ProviderError)) throw error;
      console.error(`Recognition ${error.kind}: ${error.message}`);
      switch (error.kind) {
        case "busy":
          return failure(
            429,
            "busy",
            "Recognition is busy. Try again shortly.",
          );
        case "timeout":
          return failure(504, "timeout", "Recognition took too long.");
        case "failed":
          return failure(502, "recognition_failed", "Recognition failed.");
      }
    }
  };
}

/** Trims, lowercases and de-duplicates names, dropping junk. */
export function tidy(names: string[]): string[] {
  const seen = new Set<string>();
  for (const raw of names) {
    const name = raw.trim().replace(/\s+/g, " ").toLowerCase();
    if (name.length > 0 && name.length <= maxNameLength) seen.add(name);
    if (seen.size === maxIngredients) break;
  }
  return [...seen];
}

function failure(status: number, error: string, message: string): Response {
  return Response.json({ error, message }, { status });
}
