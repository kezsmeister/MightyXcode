/**
 * Mighty Auth Proxy - Cloudflare Worker
 *
 * This worker proxies authentication requests to InstantDB,
 * adding the admin token securely on the server side.
 *
 * Endpoints:
 * - POST /auth/send-code  - Send magic code email
 * - POST /auth/verify     - Verify magic code and get tokens
 */

interface Env {
  INSTANTDB_ADMIN_TOKEN: string;
  INSTANTDB_APP_ID: string;
}

const INSTANTDB_BASE_URL = "https://api.instantdb.com";

// CORS headers for iOS app
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      if (path === "/auth/send-code" && request.method === "POST") {
        return await handleSendCode(request, env);
      }

      if (path === "/auth/verify" && request.method === "POST") {
        return await handleVerify(request, env);
      }

      return new Response(JSON.stringify({ error: "Not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } catch (error) {
      console.error("Error:", error);
      return new Response(
        JSON.stringify({ error: "Internal server error" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }
  },
};

/**
 * Handle POST /auth/send-code
 * Proxies to InstantDB admin/send_magic_code endpoint
 */
async function handleSendCode(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { email: string };

  if (!body.email) {
    return new Response(JSON.stringify({ error: "Email is required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const instantDBResponse = await fetch(
    `${INSTANTDB_BASE_URL}/admin/send_magic_code`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${env.INSTANTDB_ADMIN_TOKEN}`,
        "App-Id": env.INSTANTDB_APP_ID,
      },
      body: JSON.stringify({
        email: body.email,
      }),
    }
  );

  if (!instantDBResponse.ok) {
    const errorText = await instantDBResponse.text();
    console.error("InstantDB error:", errorText);
    return new Response(
      JSON.stringify({ error: "Failed to send magic code", details: errorText, status: instantDBResponse.status }),
      {
        status: instantDBResponse.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * Handle POST /auth/verify
 * Proxies to InstantDB admin/verify_magic_code endpoint
 */
async function handleVerify(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { email: string; code: string };

  if (!body.email || !body.code) {
    return new Response(
      JSON.stringify({ error: "Email and code are required" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  const instantDBResponse = await fetch(
    `${INSTANTDB_BASE_URL}/admin/verify_magic_code`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${env.INSTANTDB_ADMIN_TOKEN}`,
        "App-Id": env.INSTANTDB_APP_ID,
      },
      body: JSON.stringify({
        email: body.email,
        code: body.code,
      }),
    }
  );

  if (!instantDBResponse.ok) {
    const errorText = await instantDBResponse.text();
    console.error("InstantDB verify error:", errorText);
    return new Response(JSON.stringify({ error: "Invalid code" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const data = await instantDBResponse.json();

  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
