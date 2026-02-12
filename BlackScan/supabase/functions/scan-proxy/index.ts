// Supabase Edge Function: scan-proxy
// Proxies OpenAI API requests so the API key never leaves the server.
//
// DEPLOYMENT:
//   1. Install Supabase CLI: npm i -g supabase
//   2. Link your project:   supabase link --project-ref YOUR_PROJECT_REF
//   3. Set the secret:      supabase secrets set OPENAI_API_KEY=sk-proj-YOUR_KEY
//   4. Deploy:              supabase functions deploy scan-proxy
//
// The function exposes two routes:
//   POST /analyze-text   — OCR text analysis via GPT-4o-mini
//   POST /analyze-image  — Image analysis via GPT-4o Vision
//
// Rate limiting: 20 requests per user per day (enforced via Supabase table).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const MAX_DAILY_SCANS = 20;
const OPENAI_ENDPOINT = "https://api.openai.com/v1/chat/completions";

// Allowed models — prevent callers from using expensive models
const ALLOWED_MODELS = new Set(["gpt-4o", "gpt-4o-mini"]);
const MAX_TOKENS_LIMIT = 1000;
const MAX_BODY_SIZE = 10 * 1024 * 1024; // 10 MB (base64 images can be large)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Only allow POST
  if (req.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  try {
    // --- Check body size ---
    const contentLength = parseInt(req.headers.get("content-length") || "0");
    if (contentLength > MAX_BODY_SIZE) {
      return jsonError("Request too large", 413);
    }

    // --- Auth: verify the caller's JWT ---
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Missing authorization header", 401);
    }

    const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);

    // Extract user from JWT (anon key creates an anonymous session)
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    // For anon-key requests, use a hash of the token as the user identifier
    const userId = user?.id ?? hashString(token).slice(0, 32);

    // --- Rate Limiting ---
    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
    const { data: usage, error: usageError } = await supabase
      .from("scan_usage")
      .select("scan_count")
      .eq("user_id", userId)
      .eq("date", today)
      .maybeSingle();

    const currentCount = usage?.scan_count ?? 0;

    if (currentCount >= MAX_DAILY_SCANS) {
      return jsonError(
        `Daily scan limit (${MAX_DAILY_SCANS}) exceeded. Try again tomorrow.`,
        429
      );
    }

    // Increment usage
    await supabase.from("scan_usage").upsert(
      {
        user_id: userId,
        date: today,
        scan_count: currentCount + 1,
      },
      { onConflict: "user_id,date" }
    );

    // --- Parse and validate request body ---
    const body = await req.json();

    if (!OPENAI_API_KEY) {
      return jsonError("Server misconfigured: missing OpenAI API key", 500);
    }

    // --- SECURITY: Validate and constrain the OpenAI payload ---
    const sanitizedBody = sanitizeOpenAIPayload(body);
    if (sanitizedBody.error) {
      return jsonError(sanitizedBody.error, 400);
    }

    // --- Forward to OpenAI ---
    const openaiResponse = await fetch(OPENAI_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(sanitizedBody.payload),
    });

    const openaiData = await openaiResponse.json();

    if (!openaiResponse.ok) {
      console.error("OpenAI error status:", openaiResponse.status);
      return jsonError("Analysis service temporarily unavailable", 502);
    }

    return new Response(JSON.stringify(openaiData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error("scan-proxy error:", (err as Error).message);
    return jsonError("Internal server error", 500);
  }
});

// --- Payload Validation ---

interface SanitizeResult {
  payload?: Record<string, unknown>;
  error?: string;
}

function sanitizeOpenAIPayload(body: Record<string, unknown>): SanitizeResult {
  // 1. Validate model — only allow approved models
  const model = body.model as string;
  if (!model || !ALLOWED_MODELS.has(model)) {
    return { error: `Model not allowed. Use one of: ${[...ALLOWED_MODELS].join(", ")}` };
  }

  // 2. Validate messages exist and are an array
  const messages = body.messages;
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > 5) {
    return { error: "Invalid messages format" };
  }

  // 3. Cap max_tokens to prevent expensive requests
  let maxTokens = typeof body.max_tokens === "number" ? body.max_tokens : 500;
  maxTokens = Math.min(maxTokens, MAX_TOKENS_LIMIT);

  // 4. Force temperature to 0 (deterministic — matches client expectations)
  const temperature = 0;

  // 5. Build constrained payload — strip any unexpected fields
  return {
    payload: {
      model,
      messages,
      max_tokens: maxTokens,
      temperature,
    },
  };
}

// --- Helpers ---

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}

function hashString(str: string): string {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash |= 0;
  }
  return Math.abs(hash).toString(16).padStart(8, "0");
}
