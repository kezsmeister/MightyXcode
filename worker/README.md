# InstantDB Proxy Worker

This Cloudflare Worker proxies requests to InstantDB, keeping the admin token secure on the server side.

## Setup

### 1. Install Wrangler CLI (if not already installed)

```bash
npm install -g wrangler
```

### 2. Login to Cloudflare

```bash
wrangler login
```

### 3. Set the Admin Token Secret

Get your admin token from [InstantDB Dashboard](https://instantdb.com/dash) → Your App → Settings → Admin token

```bash
cd worker
wrangler secret put INSTANTDB_ADMIN_TOKEN
# Paste your admin token when prompted
```

### 4. Deploy the Worker

```bash
wrangler deploy
```

After deployment, you'll get a URL like:
`https://mighty-db-proxy.<your-subdomain>.workers.dev`

### 5. Update the iOS App

Update `Secrets.swift` with your worker URL:
```swift
static let instantDBProxyURL = "https://mighty-db-proxy.<your-subdomain>.workers.dev"
```

## API Endpoints

### POST /db/query

Query data from InstantDB.

**Request:**
```json
{
  "refresh_token": "user's refresh token",
  "query": {
    "kidProfiles": {}
  }
}
```

**Response:**
```json
{
  "kidProfiles": [...]
}
```

### POST /db/transact

Write data to InstantDB.

**Request:**
```json
{
  "refresh_token": "user's refresh token",
  "steps": [
    ["update", "kidProfiles", "uuid", { "name": "John" }],
    ["link", "kidProfiles", "uuid", { "parent": "user-id" }]
  ]
}
```

### GET /health

Health check endpoint.

## Security

- The admin token is stored as a Cloudflare secret and never exposed to clients
- Each request validates the user's refresh token before proceeding
- User impersonation (`As-Token` header) ensures permission rules apply
- CORS headers are configured for cross-origin requests
