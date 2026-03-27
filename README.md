<div align="center">
  <img src="./new-assets/BlackGCCSE-Logo.png" width="140" alt="logo">
  <h1>cdn.hackclub.com</h1>
</div>

<p align="center"><i>Direct-to-storage uploads for large files, static assets, and durable URLs.</i></p>

<div align="center">
  <img src="./new-assets/Placeholder.jpg" width="100%" alt="Placeholder banner">
</div>

---

A Rails 8 application for hosting and managing CDN uploads, with OAuth authentication via Hack Club.

## Prerequisites

- Ruby 3.4.4 (see `.ruby-version`)
- PostgreSQL
- Node.js + Yarn (for Vite frontend)
- A Cloudflare R2 bucket (or S3-compatible storage)

## Setup

1. **Clone and install dependencies:**
   ```bash
   git clone https://github.com/hackclub/cdn.git
   cd cdn
   bundle install
   yarn install
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your credentials (see below for details).

3. **Setup the database:**
   ```bash
   bin/rails db:create db:migrate
   ```

4. **Generate encryption keys** (for API key encryption):
   ```bash
   # Generate a 32-byte hex key for Lockbox
   ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"
   
   # Generate a 32-byte hex key for BlindIndex
   ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"
   
   # Generate Active Record encryption keys
   bin/rails db:encryption:init
   ```

5. **Start the development servers:**
   ```bash
   # In one terminal, run the Vite dev server:
   bin/vite dev
   
   # In another terminal, run the Rails server:
   bin/rails server
   ```

## Environment Variables

See `.env.example` for the full list. Key variables:

| Variable | Description |
|----------|-------------|
| `R2_ACCESS_KEY_ID` | Cloudflare R2 access key |
| `R2_SECRET_ACCESS_KEY` | Cloudflare R2 secret key |
| `R2_BUCKET_NAME` | R2 bucket name |
| `R2_ENDPOINT` | R2 endpoint URL |
| `CDN_HOST` | Public hostname for CDN URLs |
| `CDN_ASSETS_HOST` | Public R2 bucket hostname |
| `HACKCLUB_CLIENT_ID` | OAuth client ID from Hack Club Auth |
| `HACKCLUB_CLIENT_SECRET` | OAuth client secret |
| `LOCKBOX_MASTER_KEY` | 64-char hex key for encrypting API keys |
| `BLIND_INDEX_MASTER_KEY` | 64-char hex key for searchable encryption |

## DNS Setup

| Domain | Points to |
|--------|-----------|
| `cdn.hackclub.com` | Your app or proxy layer |
| `cdn.hackclub-assets.com` | R2 bucket (custom domain in R2 settings) |

## API

The API uses bearer token authentication. Create an API key from the web dashboard after logging in.

**Upload a file:**
```bash
curl -X POST https://cdn.hackclub.com/api/v4/upload \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -F "file=@image.png"
```

**Upload from URL:**
```bash
curl -X POST https://cdn.hackclub.com/api/v4/upload_from_url \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/image.png"}'
```

**Direct upload for large files / Vercel-fronted deployments:**
```bash
curl -X POST https://cdn.hackclub.com/api/v4/direct_upload \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"filename":"video.mp4","byte_size":2147483648,"content_type":"video/mp4"}'
```

See `/docs` in the running app for full API documentation.

## Vercel

Large uploads should use the direct-upload flow so the file goes straight from the client to R2 instead of through the app server. That keeps uploads working when requests pass through Vercel limits.

Make sure your bucket CORS policy allows `PUT` and `OPTIONS` from your app origin, or browser-based direct uploads will be blocked before they reach storage.

## Architecture

- **Rails 8** with **Vite** for frontend assets
- **Phlex** + **Primer ViewComponents** for UI
- **Active Storage** with Cloudflare R2 backend
- **Solid Queue/Cache/Cable** for background jobs and caching (production)
- **Pundit** for authorization
- **Lockbox + BlindIndex** for API key encryption

<div align="center">
  <br>
  <p>Made with 💜 for Hack Club</p>
</div>
