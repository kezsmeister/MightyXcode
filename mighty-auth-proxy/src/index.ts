/**
 * Mighty Auth Proxy - Cloudflare Worker
 *
 * This worker proxies authentication requests to InstantDB,
 * adding the admin token securely on the server side.
 *
 * Endpoints:
 * - POST /auth/send-code  - Send magic code email
 * - POST /auth/verify     - Verify magic code and get tokens
 * - POST /family/invite   - Create and send family invitation
 * - POST /family/accept-invite - Accept invitation with token
 * - POST /family/members  - List family members
 * - POST /family/invitations - List pending invitations
 * - POST /family/revoke-invite - Revoke pending invitation
 * - POST /family/remove-member - Remove a family member
 */

interface Env {
  INSTANTDB_ADMIN_TOKEN: string;
  INSTANTDB_APP_ID: string;
  RESEND_API_KEY: string;
}

interface UserInfo {
  id: string;
  email: string;
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
      // Auth endpoints
      if (path === "/auth/send-code" && request.method === "POST") {
        return await handleSendCode(request, env);
      }

      if (path === "/auth/verify" && request.method === "POST") {
        return await handleVerify(request, env);
      }

      // Family sharing endpoints
      if (path === "/family/invite" && request.method === "POST") {
        return await handleFamilyInvite(request, env);
      }

      if (path === "/family/accept-invite" && request.method === "POST") {
        return await handleAcceptInvite(request, env);
      }

      if (path === "/family/members" && request.method === "POST") {
        return await handleGetMembers(request, env);
      }

      if (path === "/family/invitations" && request.method === "POST") {
        return await handleGetInvitations(request, env);
      }

      if (path === "/family/revoke-invite" && request.method === "POST") {
        return await handleRevokeInvite(request, env);
      }

      if (path === "/family/remove-member" && request.method === "POST") {
        return await handleRemoveMember(request, env);
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

// ============================================
// FAMILY SHARING ENDPOINTS
// ============================================

/**
 * Verify refresh token and get user info
 */
async function verifyTokenAndGetUser(refreshToken: string, env: Env): Promise<UserInfo | null> {
  const response = await fetch(`${INSTANTDB_BASE_URL}/runtime/auth/verify_refresh_token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      "app-id": env.INSTANTDB_APP_ID,
      "refresh-token": refreshToken,
    }),
  });

  if (!response.ok) {
    return null;
  }

  const data = await response.json() as { user: UserInfo };
  return data.user;
}

/**
 * Generate a secure random invitation token
 */
function generateInviteToken(): string {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Query InstantDB using admin API
 */
async function queryInstantDB(query: object, env: Env): Promise<any> {
  const response = await fetch(`${INSTANTDB_BASE_URL}/admin/query`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${env.INSTANTDB_ADMIN_TOKEN}`,
      "App-Id": env.INSTANTDB_APP_ID,
    },
    body: JSON.stringify({ query }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`InstantDB query failed: ${errorText}`);
  }

  return await response.json();
}

/**
 * Execute InstantDB transaction using admin API
 */
async function transactInstantDB(steps: any[], env: Env): Promise<any> {
  const response = await fetch(`${INSTANTDB_BASE_URL}/admin/transact`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${env.INSTANTDB_ADMIN_TOKEN}`,
      "App-Id": env.INSTANTDB_APP_ID,
    },
    body: JSON.stringify({ steps }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`InstantDB transact failed: ${errorText}`);
  }

  return await response.json();
}

/**
 * Send invitation email via Resend
 */
async function sendInvitationEmail(
  env: Env,
  toEmail: string,
  inviterEmail: string,
  token: string
): Promise<boolean> {
  const inviteLink = `mightyapp://invite/${token}`;

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Mighty <noreply@mighty-app.com>",
      to: toEmail,
      subject: `${inviterEmail} invited you to view their family on Mighty`,
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #7C3AED;">You're invited to Mighty!</h2>
          <p>${inviterEmail} has invited you to view their family's activities on Mighty.</p>
          <p>As a viewer, you'll be able to see all scheduled activities, but you won't be able to make changes.</p>
          <p style="margin: 30px 0;">
            <a href="${inviteLink}" style="background-color: #7C3AED; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; display: inline-block;">Accept Invitation</a>
          </p>
          <p style="color: #666; font-size: 14px;">This invitation expires in 7 days.</p>
          <p style="color: #666; font-size: 14px;">If you don't have the Mighty app, download it from the App Store first.</p>
        </div>
      `,
    }),
  });

  return response.ok;
}

/**
 * Handle POST /family/invite
 * Creates invitation and sends email
 */
async function handleFamilyInvite(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { refresh_token: string; email: string };

  if (!body.refresh_token || !body.email) {
    return new Response(JSON.stringify({ error: "refresh_token and email are required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Verify user
  const user = await verifyTokenAndGetUser(body.refresh_token, env);
  if (!user) {
    return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Normalize email
  const inviteeEmail = body.email.toLowerCase().trim();

  // Check if inviting self
  if (inviteeEmail === user.email.toLowerCase()) {
    return new Response(JSON.stringify({ error: "You cannot invite yourself" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // Get or create family for this user
    const familyQuery = await queryInstantDB({
      families: {
        $: { where: { ownerId: user.id } }
      }
    }, env);

    let familyId: string;

    if (familyQuery.families && familyQuery.families.length > 0) {
      familyId = familyQuery.families[0].id;
    } else {
      // Create new family
      familyId = crypto.randomUUID();
      await transactInstantDB([
        ["update", "families", familyId, {
          ownerId: user.id,
          name: `${user.email}'s Family`,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        }]
      ], env);
    }

    // Check if already a member
    const membersQuery = await queryInstantDB({
      familyMembers: {
        $: { where: { family: familyId, email: inviteeEmail } }
      }
    }, env);

    if (membersQuery.familyMembers && membersQuery.familyMembers.length > 0) {
      return new Response(JSON.stringify({ error: "This person is already a family member" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check for existing pending invitation
    const existingInviteQuery = await queryInstantDB({
      familyInvitations: {
        $: { where: { family: familyId, email: inviteeEmail, status: "pending" } }
      }
    }, env);

    // Generate token and expiry
    const token = generateInviteToken();
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(); // 7 days

    // Create or update invitation
    const invitationId = existingInviteQuery.familyInvitations?.[0]?.id || crypto.randomUUID();

    await transactInstantDB([
      ["update", "familyInvitations", invitationId, {
        token: token,
        email: inviteeEmail,
        role: "viewer",
        status: "pending",
        expiresAt: expiresAt,
        createdAt: new Date().toISOString(),
        inviterId: user.id,
        familyId: familyId,
      }],
      ["link", "familyInvitations", invitationId, { family: familyId }],
    ], env);

    // Send email
    const emailSent = await sendInvitationEmail(env, inviteeEmail, user.email, token);

    return new Response(JSON.stringify({
      success: true,
      invitationId,
      emailSent,
      shareLink: `mightyapp://invite/${token}`
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Family invite error:", error);
    return new Response(JSON.stringify({ error: "Failed to create invitation" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

/**
 * Handle POST /family/accept-invite
 * Accepts invitation and adds user as family member
 */
async function handleAcceptInvite(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { refresh_token: string; token: string };

  if (!body.refresh_token || !body.token) {
    return new Response(JSON.stringify({ error: "refresh_token and invitation token are required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Verify user
  const user = await verifyTokenAndGetUser(body.refresh_token, env);
  if (!user) {
    return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // Find invitation by token
    const inviteQuery = await queryInstantDB({
      familyInvitations: {
        $: { where: { token: body.token } }
      }
    }, env);

    if (!inviteQuery.familyInvitations || inviteQuery.familyInvitations.length === 0) {
      return new Response(JSON.stringify({ error: "Invitation not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const invitation = inviteQuery.familyInvitations[0];

    // Check invitation status
    if (invitation.status !== "pending") {
      return new Response(JSON.stringify({ error: "This invitation has already been used or revoked" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check expiry
    if (new Date(invitation.expiresAt) < new Date()) {
      await transactInstantDB([
        ["update", "familyInvitations", invitation.id, { status: "expired" }]
      ], env);
      return new Response(JSON.stringify({ error: "This invitation has expired" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Skip email check - allow anyone with the link to accept
    // (The link itself is the authorization)

    // Create family member record
    const memberId = crypto.randomUUID();
    const familyId = invitation.familyId;

    await transactInstantDB([
      ["update", "familyMembers", memberId, {
        userId: user.id,
        email: user.email,
        role: invitation.role || "viewer",
        joinedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }],
      ["link", "familyMembers", memberId, { family: familyId }],
      ["update", "familyInvitations", invitation.id, {
        status: "accepted",
        acceptedAt: new Date().toISOString(),
      }],
    ], env);

    return new Response(JSON.stringify({
      success: true,
      familyId,
      role: invitation.role || "viewer"
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Accept invite error:", error);
    return new Response(JSON.stringify({ error: "Failed to accept invitation" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

/**
 * Handle POST /family/members
 * Returns family members for the user's family
 */
async function handleGetMembers(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { refresh_token: string };

  if (!body.refresh_token) {
    return new Response(JSON.stringify({ error: "refresh_token is required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const user = await verifyTokenAndGetUser(body.refresh_token, env);
  if (!user) {
    return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // Get user's owned family
    const familyQuery = await queryInstantDB({
      families: {
        $: { where: { ownerId: user.id } },
        members: {}
      }
    }, env);

    if (!familyQuery.families || familyQuery.families.length === 0) {
      return new Response(JSON.stringify({
        members: [],
        isOwner: true,
        familyId: null
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const family = familyQuery.families[0];
    const members = family.members || [];

    // Add owner as first member
    const allMembers = [
      {
        id: "owner",
        userId: user.id,
        email: user.email,
        role: "admin",
        joinedAt: family.createdAt,
        isOwner: true,
      },
      ...members.map((m: any) => ({ ...m, isOwner: false }))
    ];

    return new Response(JSON.stringify({
      members: allMembers,
      isOwner: true,
      familyId: family.id
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Get members error:", error);
    return new Response(JSON.stringify({ error: "Failed to get family members" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

/**
 * Handle POST /family/invitations
 * Returns pending invitations for the user's family
 */
async function handleGetInvitations(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { refresh_token: string };

  if (!body.refresh_token) {
    return new Response(JSON.stringify({ error: "refresh_token is required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const user = await verifyTokenAndGetUser(body.refresh_token, env);
  if (!user) {
    return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // Get user's family and pending invitations
    const familyQuery = await queryInstantDB({
      families: {
        $: { where: { ownerId: user.id } },
        invitations: {
          $: { where: { status: "pending" } }
        }
      }
    }, env);

    if (!familyQuery.families || familyQuery.families.length === 0) {
      return new Response(JSON.stringify({ invitations: [] }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const invitations = familyQuery.families[0].invitations || [];

    return new Response(JSON.stringify({ invitations }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Get invitations error:", error);
    return new Response(JSON.stringify({ error: "Failed to get invitations" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

/**
 * Handle POST /family/revoke-invite
 * Revokes a pending invitation
 */
async function handleRevokeInvite(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { refresh_token: string; invitationId: string };

  if (!body.refresh_token || !body.invitationId) {
    return new Response(JSON.stringify({ error: "refresh_token and invitationId are required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const user = await verifyTokenAndGetUser(body.refresh_token, env);
  if (!user) {
    return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // Verify user owns the family
    const familyQuery = await queryInstantDB({
      families: {
        $: { where: { ownerId: user.id } }
      }
    }, env);

    if (!familyQuery.families || familyQuery.families.length === 0) {
      return new Response(JSON.stringify({ error: "You don't have a family to manage" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Update invitation status
    await transactInstantDB([
      ["update", "familyInvitations", body.invitationId, { status: "revoked" }]
    ], env);

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Revoke invite error:", error);
    return new Response(JSON.stringify({ error: "Failed to revoke invitation" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

/**
 * Handle POST /family/remove-member
 * Removes a family member
 */
async function handleRemoveMember(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { refresh_token: string; memberId: string };

  if (!body.refresh_token || !body.memberId) {
    return new Response(JSON.stringify({ error: "refresh_token and memberId are required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const user = await verifyTokenAndGetUser(body.refresh_token, env);
  if (!user) {
    return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // Verify user owns the family
    const familyQuery = await queryInstantDB({
      families: {
        $: { where: { ownerId: user.id } }
      }
    }, env);

    if (!familyQuery.families || familyQuery.families.length === 0) {
      return new Response(JSON.stringify({ error: "You don't have a family to manage" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Delete family member
    await transactInstantDB([
      ["delete", "familyMembers", body.memberId]
    ], env);

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Remove member error:", error);
    return new Response(JSON.stringify({ error: "Failed to remove member" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}
