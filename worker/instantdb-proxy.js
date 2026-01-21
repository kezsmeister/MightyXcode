/**
 * Cloudflare Worker: InstantDB Proxy
 *
 * This worker proxies requests to InstantDB Admin API, keeping the admin token secure.
 * The iOS app sends requests here with the user's refresh token, and this worker
 * validates the token and forwards requests to InstantDB with the admin token.
 *
 * Environment variables required (set in Cloudflare dashboard or wrangler.toml):
 * - INSTANTDB_APP_ID: Your InstantDB app ID
 * - INSTANTDB_ADMIN_TOKEN: Your InstantDB admin token (keep secret!)
 */

const INSTANTDB_API = 'https://api.instantdb.com';

export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return handleCORS(request);
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // Route requests
      if (path === '/db/query' && request.method === 'POST') {
        return await handleQuery(request, env);
      }

      if (path === '/db/transact' && request.method === 'POST') {
        return await handleTransact(request, env);
      }

      // Health check
      if (path === '/health') {
        return jsonResponse({ status: 'ok', service: 'instantdb-proxy' });
      }

      return jsonResponse({ error: 'Not found' }, 404);
    } catch (error) {
      console.error('Worker error:', error);
      return jsonResponse({ error: error.message || 'Internal server error' }, 500);
    }
  }
};

/**
 * Handle query requests
 * Expected body: { "refresh_token": "...", "query": { ... } }
 */
async function handleQuery(request, env) {
  const body = await request.json();
  const { refresh_token, query } = body;

  if (!refresh_token) {
    return jsonResponse({ error: 'Missing refresh_token' }, 400);
  }

  if (!query) {
    return jsonResponse({ error: 'Missing query' }, 400);
  }

  // Validate the refresh token
  const tokenValid = await verifyRefreshToken(refresh_token, env);
  if (!tokenValid) {
    return jsonResponse({ error: 'Invalid or expired token' }, 401);
  }

  // Forward to InstantDB Admin API with user impersonation
  console.log('Sending query to InstantDB:', JSON.stringify(query));

  const response = await fetch(`${INSTANTDB_API}/admin/query`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.INSTANTDB_ADMIN_TOKEN}`,
      'App-Id': env.INSTANTDB_APP_ID,
      'As-Token': refresh_token, // Impersonate the user so permission rules apply
    },
    body: JSON.stringify({ query }),
  });

  const data = await response.text();

  console.log('InstantDB response status:', response.status);
  console.log('InstantDB response body:', data.substring(0, 500));

  return new Response(data, {
    status: response.status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(),
    },
  });
}

/**
 * Handle transact requests
 * Expected body: { "refresh_token": "...", "steps": [ ... ] }
 */
async function handleTransact(request, env) {
  const body = await request.json();
  const { refresh_token, steps } = body;

  if (!refresh_token) {
    return jsonResponse({ error: 'Missing refresh_token' }, 400);
  }

  if (!steps || !Array.isArray(steps)) {
    return jsonResponse({ error: 'Missing or invalid steps array' }, 400);
  }

  // Validate the refresh token
  const tokenValid = await verifyRefreshToken(refresh_token, env);
  if (!tokenValid) {
    return jsonResponse({ error: 'Invalid or expired token' }, 401);
  }

  // Forward to InstantDB Admin API with user impersonation
  console.log('Sending transact to InstantDB:', JSON.stringify(steps).substring(0, 500));

  const response = await fetch(`${INSTANTDB_API}/admin/transact`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.INSTANTDB_ADMIN_TOKEN}`,
      'App-Id': env.INSTANTDB_APP_ID,
      'As-Token': refresh_token, // Impersonate the user so permission rules apply
    },
    body: JSON.stringify({ steps }),
  });

  const data = await response.text();

  console.log('InstantDB transact response status:', response.status);
  console.log('InstantDB transact response body:', data.substring(0, 500));

  return new Response(data, {
    status: response.status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(),
    },
  });
}

/**
 * Verify a refresh token with InstantDB
 */
async function verifyRefreshToken(refreshToken, env) {
  try {
    const response = await fetch(`${INSTANTDB_API}/runtime/auth/verify_refresh_token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        'app-id': env.INSTANTDB_APP_ID,
        'refresh-token': refreshToken,
      }),
    });

    return response.ok;
  } catch (error) {
    console.error('Token verification error:', error);
    return false;
  }
}

/**
 * Helper: Create JSON response with CORS headers
 */
function jsonResponse(data, status = 200, request = null) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(request),
    },
  });
}

/**
 * Helper: CORS headers
 * Restricted to specific origins for security
 * iOS native apps don't require CORS, but this protects against web-based attacks
 */
function corsHeaders(request) {
  const origin = request?.headers?.get('Origin') || '';

  // Allow specific origins only
  // Add your web domains here if you have a web app
  const allowedOrigins = [
    'https://mighty-app.com',
    'https://www.mighty-app.com',
    // Allow localhost for development
    'http://localhost:3000',
    'http://localhost:8080',
  ];

  // For iOS native requests, Origin header is typically not sent
  // We allow requests without Origin (native apps) but restrict web origins
  const allowOrigin = origin === '' || allowedOrigins.includes(origin)
    ? (origin || 'https://mighty-app.com')
    : 'https://mighty-app.com';

  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400', // Cache preflight for 24 hours
  };
}

/**
 * Helper: Handle CORS preflight
 */
function handleCORS(request) {
  return new Response(null, {
    status: 204,
    headers: corsHeaders(request),
  });
}
