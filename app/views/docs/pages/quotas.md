---
title: Storage Quotas
icon: database
order: 4
---

# Storage Quotas

CDN provides storage for GCCSE. Standard accounts start on the verified tier.

## What's My Quota?

| Tier | Per File | Total Storage |
|------|----------|---------------|
| **Unverified** | 2 GB | 50 GB |
| **Verified** | 2 GB | 300 GB |
| **"Unlimited"** | 2 GB | 2 TB |

**New users start verified.** Administrators can still assign a different tier when needed.

## Check Your Usage

Your homepage shows available storage with a progress bar. You'll see warnings when you hit 80% usage, and uploads will be blocked at 100%.

**Via API:**

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://cdn.gccse.tech/api/v4/me
```

```json
{
  "storage_used": 1048576000,
  "storage_limit": 53687091200,
  "quota_tier": "verified"
}
```

## What Happens When I'm Over Quota?

**Web:** You'll see a red banner and uploads will fail with an error message.

**API:** Returns `402 Payment Required` with quota details:

```json
{
  "error": "Storage quota exceeded",
  "quota": {
    "storage_used": 52428800,
    "storage_limit": 52428800,
    "quota_tier": "unverified",
    "percentage_used": 100.0
  }
}
```

Delete some files from **Uploads** to free up space.
