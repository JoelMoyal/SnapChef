// Run with: deno test supabase/functions/detect-ingredients
import assert from "node:assert/strict";

import {
  createGeminiDetector,
  type Detector,
  ProviderError,
} from "./gemini.ts";
import { createHandler, maxImageBytes } from "./handler.ts";

const photo = btoa("fake image bytes");

function post(body: unknown): Request {
  return new Request("http://localhost/detect-ingredients", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function call(detect: Detector | null, req: Request) {
  const res = await createHandler(detect)(req);
  return { status: res.status, body: await res.json() };
}

const finds = (...names: string[]): Detector => () => Promise.resolve(names);
const fails = (kind: ProviderError["kind"]): Detector => () =>
  Promise.reject(new ProviderError(kind, "test"));

Deno.test("returns tidied, de-duplicated ingredient names", async () => {
  let received: unknown;
  const detect: Detector = (input) => {
    received = input;
    return Promise.resolve([
      "Tomato ",
      "tomato",
      "  Green   Onions",
      "",
      "x".repeat(100),
    ]);
  };

  const res = await call(
    detect,
    post({ image: photo, mimeType: "image/jpeg" }),
  );

  assert.equal(res.status, 200);
  assert.deepEqual(res.body, {
    ingredients: [{ name: "tomato" }, { name: "green onions" }],
  });
  assert.deepEqual(received, { data: photo, mimeType: "image/jpeg" });
});

Deno.test("an empty result is still a success", async () => {
  const res = await call(
    finds(),
    post({ image: photo, mimeType: "image/png" }),
  );
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { ingredients: [] });
});

Deno.test("rejects bad requests before calling the provider", async () => {
  const cases: [Request, number, string][] = [
    [
      new Request("http://localhost/", { method: "GET" }),
      405,
      "method_not_allowed",
    ],
    [post("not json"), 400, "invalid_request"],
    [post({ mimeType: "image/jpeg" }), 400, "invalid_request"],
    [
      post({ image: "not base64!", mimeType: "image/jpeg" }),
      400,
      "invalid_request",
    ],
    [post({ image: photo }), 415, "unsupported_image"],
    [post({ image: photo, mimeType: "image/gif" }), 415, "unsupported_image"],
    [
      post({ image: "A".repeat(maxImageBytes * 1.4), mimeType: "image/jpeg" }),
      413,
      "image_too_large",
    ],
  ];
  const unreachable: Detector = () => {
    throw new Error("provider should not be called");
  };

  for (const [req, status, error] of cases) {
    const res = await call(unreachable, req);
    assert.equal(res.status, status, error);
    assert.equal(res.body.error, error);
  }
});

Deno.test("reports a missing API key", async () => {
  const res = await call(null, post({ image: photo, mimeType: "image/jpeg" }));
  assert.equal(res.status, 500);
  assert.equal(res.body.error, "not_configured");
});

Deno.test("maps provider failures to statuses the app understands", async () => {
  const cases: [ProviderError["kind"], number][] = [
    ["busy", 429],
    ["timeout", 504],
    ["failed", 502],
  ];
  for (const [kind, status] of cases) {
    const res = await call(
      fails(kind),
      post({ image: photo, mimeType: "image/jpeg" }),
    );
    assert.equal(res.status, status, kind);
  }
});

// --- Gemini --------------------------------------------------------------

function interaction(text: string, status = "completed") {
  return {
    id: "interaction-1",
    status,
    steps: [
      { type: "thought", summary: [] },
      { type: "model_output", content: [{ type: "text", text }] },
    ],
  };
}

function gemini(respond: (init: RequestInit) => Response | Promise<Response>) {
  const requests: { url: string; init: RequestInit }[] = [];
  const detect = createGeminiDetector({
    apiKey: "test-key",
    model: "test-model",
    timeoutMs: 50,
    fetch: (url, init) => {
      requests.push({ url: String(url), init: init! });
      return Promise.resolve(respond(init!));
    },
  });
  return { detect, requests };
}

Deno.test("sends the photo to Gemini and reads the structured answer", async () => {
  const { detect, requests } = gemini(() =>
    Response.json(interaction('{"ingredients":["egg","milk"]}'))
  );

  assert.deepEqual(await detect({ data: photo, mimeType: "image/png" }), [
    "egg",
    "milk",
  ]);

  const [{ url, init }] = requests;
  assert.equal(
    url,
    "https://generativelanguage.googleapis.com/v1beta/interactions",
  );
  const headers = new Headers(init.headers);
  assert.equal(headers.get("x-goog-api-key"), "test-key");
  assert.equal(headers.get("api-revision"), "2026-05-20");
  const body = JSON.parse(String(init.body));
  assert.equal(body.model, "test-model");
  assert.equal(body.store, false);
  assert.deepEqual(body.input[0], {
    type: "image",
    mime_type: "image/png",
    data: photo,
  });
  assert.equal(body.response_format.mime_type, "application/json");
  assert.ok(body.response_format.schema.properties.ingredients);
});

Deno.test("Gemini errors become provider errors", async () => {
  const cases: [() => Response, ProviderError["kind"]][] = [
    [() => new Response("quota", { status: 429 }), "busy"],
    [() => new Response("boom", { status: 500 }), "failed"],
    [() => new Response("not json"), "failed"],
    [
      () => Response.json(interaction('{"ingredients":[]}', "incomplete")),
      "failed",
    ],
    [
      () => Response.json(interaction("Here are the ingredients: egg")),
      "failed",
    ],
    [() => Response.json(interaction('{"items":["egg"]}')), "failed"],
    [() => Response.json({ status: "completed", steps: [] }), "failed"],
  ];
  for (const [respond, kind] of cases) {
    const { detect } = gemini(respond);
    await assert.rejects(
      detect({ data: photo, mimeType: "image/jpeg" }),
      (error) => error instanceof ProviderError && error.kind === kind,
    );
  }
});

Deno.test("gives up when Gemini is too slow", async () => {
  const { detect } = gemini((init) =>
    new Promise((_, reject) =>
      init.signal!.addEventListener("abort", () => reject(init.signal!.reason))
    )
  );
  await assert.rejects(
    detect({ data: photo, mimeType: "image/jpeg" }),
    (error) => error instanceof ProviderError && error.kind === "timeout",
  );
});
