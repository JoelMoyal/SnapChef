// Lists the food ingredients in a photo for the ingredient scanner. See
// handler.ts for the request format and docs/ARCHITECTURE.md for deploying.
//
// Only signed-in users can call it: verify_jwt (on by default) rejects
// requests without a valid session token before this code runs. Photos are
// passed to the vision model and never stored.

import { createGeminiDetector } from "./gemini.ts";
import { createHandler } from "./handler.ts";

const apiKey = Deno.env.get("GEMINI_API_KEY");

Deno.serve(
  createHandler(
    apiKey
      ? createGeminiDetector({
        apiKey,
        model: Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash-lite",
      })
      : null,
  ),
);
