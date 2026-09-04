# Hardened push dispatcher

This endpoint is private service-to-service infrastructure. It intentionally
uses `verify_jwt = false` because pg_cron calls it with a dedicated non-JWT
secret. The handler rejects every request whose
`x-tuktuk-dispatch-secret` header does not match
`TUKTUK_PUSH_DISPATCH_SECRET`.

## Safe production order

1. Confirm that Vault contains `tuktuk_push_dispatch_secret`.
2. Set the Edge Function secret `TUKTUK_PUSH_DISPATCH_SECRET` to the same value.
3. Apply `20260904132810_harden_push_notification_worker.sql`. The old worker
   ignores the new header, so cron and immediate dispatch remain compatible.
4. Deploy this function with `verify_jwt=false`.
5. Send an unauthenticated request and require HTTP 401.
6. Invoke a controlled authenticated test for one test device and confirm one
   delivery plus an empty pending queue.

Never put the secret value in Git, Flutter, SQL literals, logs, test fixtures,
or a command line recorded in shell history.

## Defaults and bounds

- `limit`: 100, allowed 1..500
- `max_batches`: 10, allowed 1..20
- `concurrency`: 8, allowed 1..20
- `time_budget_ms`: 45000, allowed 1000..50000
- maximum attempts: 5
- processing lease: 300 seconds

Temporary failures are returned to `pending` with exponential backoff. Invalid
FCM tokens are disabled. Permanent failures and exhausted retries remain in
the outbox for audit. A guarded `claim_id` prevents an overlapping worker from
finalizing another worker's lease.
