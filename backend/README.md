# OmniPOS backend

This service is the security boundary between the Flutter POS and ABA. ABA credentials belong only in the server environment, never in Flutter or source control.

## Run locally

```powershell
cd backend
npm install
Copy-Item .env.example .env
npm run dev
```

The ABA adapter intentionally fails closed until the official ABA sandbox API, signing algorithm, merchant ID, and callback contract are configured. The in-memory store is development-only and must be replaced with PostgreSQL or another durable transactional database before production.

## API

- `GET /health`
- `POST /v1/payments/aba` with `Idempotency-Key` header
- `GET /v1/payments/:paymentId`
- `POST /v1/webhooks/aba`

The payment endpoint accepts a server-validated order amount in minor currency units. A production implementation must authenticate the POS user/device, derive the amount from server-side order lines, and persist audit events transactionally.
