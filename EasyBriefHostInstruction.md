# Easy Brief Host Instruction

This guide walks through hosting this project with Vercel, from prep work through domain connection.

## 1. Know What Vercel Is Doing Here

This app uses:

- Vercel for deployment and request handling
- Cloudflare R2 for file storage
- PostgreSQL for the database

Large uploads are handled by direct-to-storage upload flow. That means:

- the browser uploads large files straight to R2
- Vercel does not need to accept the full 2 GB request body

## 2. What You Need Before Creating the Vercel Project

Prepare these first:

- a GitHub repository containing this app
- a Vercel account
- a PostgreSQL database
- a Cloudflare R2 bucket
- a domain name, if you want production on `cdn.gccse.tech`

You will also need values for:

- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET_NAME`
- `R2_ENDPOINT`
- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `LOCKBOX_MASTER_KEY`
- `BLIND_INDEX_MASTER_KEY`
- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`
- optional `SENTRY_DSN`

## 3. Prepare Cloudflare R2

In Cloudflare:

1. Create an R2 bucket.
2. Create an R2 API token with bucket read/write access.
3. Copy:
   - access key ID
   - secret access key
   - bucket name
   - endpoint URL
4. Create or choose a public custom domain for the bucket.

Recommended value:

- app domain: `cdn.gccse.tech`
- asset domain: `assets.gccse.tech`

Set `CDN_ASSETS_HOST=assets.gccse.tech`.

## 4. Configure Bucket CORS

This is required for browser direct uploads.

Your bucket must allow:

- `PUT`
- `OPTIONS`
- `GET`
- your site origin, usually `https://cdn.gccse.tech`

At minimum, your CORS rules should allow:

- origin: `https://cdn.gccse.tech`
- methods: `GET`, `PUT`, `HEAD`, `OPTIONS`
- headers: `Content-Type`

If CORS is wrong, uploads will fail in the browser before they ever reach storage.

## 5. Prepare PostgreSQL

Create a PostgreSQL database on a provider you trust, for example:

- Neon
- Supabase
- Railway
- Render

Copy the full connection string and store it as:

- `DATABASE_URL`

If your provider requires SSL, use the SSL-enabled URL it gives you.

## 6. Generate Secrets

Run these locally:

```bash
ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
```

Use one generated value for each of:

- `SECRET_KEY_BASE`
- `LOCKBOX_MASTER_KEY`
- `BLIND_INDEX_MASTER_KEY`

For Active Record encryption keys, run:

```bash
bin/rails db:encryption:init
```

Copy the generated values into:

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`

## 7. Push the Latest Code

Before creating the Vercel project, make sure your repo includes:

- `vercel.json`
- the current `Gemfile`
- the current `Gemfile.lock`
- the latest migrations

Then push to GitHub.

## 8. Create the Vercel Project

In Vercel:

1. Click `Add New...`
2. Click `Project`
3. Import the GitHub repository
4. Select the production branch, usually `main`

Vercel should detect the repo automatically.

## 9. Configure Project Settings Before First Deploy

In the Vercel project settings, set:

- Framework preset: leave auto-detected if Vercel does not require a change
- Root directory: repository root
- Install command: Vercel will read [vercel.json](/Users/aparikh1/Documents/cdn/vercel.json)

This repo already contains:

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "installCommand": "bundle config set without 'development test' && bundle install && yarn install --frozen-lockfile"
}
```

That is important because it prevents production deploys from installing development/test gems that can fail on Vercel.

## 10. Add Environment Variables in Vercel

In the Vercel project:

1. Open `Settings`
2. Open `Environment Variables`
3. Add these values for Production

Required:

- `RAILS_ENV=production`
- `RACK_ENV=production`
- `DATABASE_URL=...`
- `R2_ACCESS_KEY_ID=...`
- `R2_SECRET_ACCESS_KEY=...`
- `R2_BUCKET_NAME=...`
- `R2_ENDPOINT=...`
- `CDN_HOST=cdn.gccse.tech`
- `CDN_ASSETS_HOST=assets.gccse.tech`
- `SECRET_KEY_BASE=...`
- `LOCKBOX_MASTER_KEY=...`
- `BLIND_INDEX_MASTER_KEY=...`
- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=...`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...`

Optional:

- `SENTRY_DSN=...`
- `RAILS_LOG_LEVEL=info`

## 11. Start the First Deploy

After env vars are saved:

1. Trigger the first deployment
2. Wait for build logs

If the build fails:

- check missing env vars first
- check database URL format
- check that R2 credentials are correct

## 12. Run Database Migrations

After the first deploy succeeds, the app still needs the database schema.

You must run:

```bash
bin/rails db:migrate
```

How you run it depends on your workflow:

- locally with production env vars pointed at the production database
- in a one-off job runner outside Vercel
- in another host or CI step that can run Rails tasks

Vercel is not a great place to rely on interactive Rails task execution, so many teams run migrations from local machine or CI.

## 13. Verify the App

After deployment and migration:

1. Open the Vercel deployment URL
2. Start a session
3. Open the uploads page
4. Upload a small file
5. Upload a larger file using the browser flow
6. Confirm the final file URL resolves

Also verify:

- `/up` returns healthy
- API endpoints respond
- file deletion works
- uploaded file URLs redirect correctly

## 14. Connect the Domain

In Vercel:

1. Open the project
2. Go to `Settings`
3. Go to `Domains`
4. Add `cdn.gccse.tech`

Then update DNS where your domain is managed.

Usually Vercel will tell you exactly which record to add. Follow the values Vercel shows.

Common pattern:

- add a `CNAME` for `cdn` pointing to Vercel

If your DNS provider does not allow that exact setup, use the records Vercel gives you in the domain UI.

## 15. Configure the Asset Domain

If you are also using `assets.gccse.tech` for R2:

1. Configure that custom domain in Cloudflare R2
2. Point DNS for `assets.gccse.tech` to the R2 custom domain target
3. Make sure `CDN_ASSETS_HOST=assets.gccse.tech` is set in Vercel

This is separate from the Vercel domain setup.

## 16. Final Production Checklist

Before calling it done, confirm:

- Vercel deploy is green
- database migrations have run
- `cdn.gccse.tech` resolves to the app
- `assets.gccse.tech` resolves to the bucket
- R2 CORS allows browser uploads
- file upload works
- file URLs open publicly
- delete works
- `/up` is healthy

## 17. If Vercel Build Fails Again

Check these first:

- `Gemfile.lock` matches the repo state
- all environment variables exist
- `DATABASE_URL` is valid
- the production install is skipping `development` and `test`

If the failure mentions gems like `debug`, `irb`, `rdoc`, or `psych`, that usually means Vercel is still trying to install development/test gems instead of production-only gems.

## 18. Recommended Deployment Order

Use this order:

1. Prepare R2
2. Prepare Postgres
3. Generate secrets
4. Push latest code
5. Create Vercel project
6. Add env vars
7. Deploy
8. Run migrations
9. Verify app
10. Connect `cdn.gccse.tech`
11. Verify uploads on the real domain
