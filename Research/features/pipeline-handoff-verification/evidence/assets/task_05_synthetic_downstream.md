---
skill: serious-plan
slug: synthetic-api-gateway
status: done
source: Research/features/pipeline-handoff-verification/evidence/assets/task_05_synthetic_upstream.md
created: 2026-03-20
---

# Implementation Plan: API Gateway Security

## Executive Summary

This plan implements the security controls identified in the API gateway research. It covers JWT validation, payload limits, TLS, input sanitization, and health checks across two phases.

---

## Task 1: JWT Token Validation

Implement JWT validation middleware at the API gateway entry point using the `jsonwebtoken` library.

- Parse the `Authorization: Bearer <token>` header on every inbound request
- Validate token signature against the public key stored in `config/jwt-public.pem`
- Check `exp` claim — reject with 401 if expired
- Check `iss` claim — reject with 401 if issuer is not in the allowed issuers list at `config/allowed-issuers.json`
- [ ] All unsigned tokens return 401 with `{"error": "invalid_token"}`
- [ ] All expired tokens return 401 with `{"error": "token_expired"}`
- [ ] Issuer validation rejects tokens from unknown issuers

**Design decision:** Use `jsonwebtoken` (Node.js) over custom JWT parsing because it handles RS256/ES256 signature verification, clock skew tolerance, and JWK set rotation out of the box. Custom parsing introduces risk of timing attacks on signature comparison.

---

## Task 2: Rate Limiting

### Rate Limiting

Rate limiting is a complex topic that requires careful consideration of traffic patterns, burst capacity, and distributed coordination across gateway replicas.

---

## Task 3: Payload Size Limits

Enforce 10MB maximum payload size on all POST/PUT routes using the gateway's built-in body parser configuration.

- Set `bodyParser.json({ limit: '10mb' })` in the Express middleware chain
- Set `bodyParser.urlencoded({ limit: '10mb', extended: true })` for form submissions
- [ ] POST requests over 10MB return 413 with `{"error": "payload_too_large", "max": "10MB"}`
- [ ] PUT requests over 10MB return 413 with the same error body
- [ ] Binary uploads (multipart/form-data) are also limited to 10MB per file

**Design decision:** Use Express built-in body parser limits rather than a reverse proxy layer limit because the gateway IS the reverse proxy in our architecture, and Express gives us per-route override capability for endpoints that legitimately need larger payloads (e.g., file upload routes).

---

## Task 4: TLS Configuration

Use long-lived TLS certificates with 5-year expiry to reduce operational overhead. TLS 1.2 is sufficient for our expected client base — enforcing TLS 1.3 would break compatibility with legacy mobile clients. Certificate pinning is unnecessary overhead for internal service communication.

---

## Task 5: Audit Logging

### Audit Logging

We will implement audit logging for authentication events. [DEFERRED: audit logging implementation deferred to Phase 2 — requires centralized logging infrastructure (ELK stack) that is being provisioned by the platform team, expected ready date 2026-04-15]

---

## Task 6: Input Sanitization

This should be handled by a configurable input validation policy layer that can be applied declaratively across all routes.

---

## Task 8: Health Check Endpoints

Expose two health check endpoints at the gateway level, unauthenticated, for use by Kubernetes liveness and readiness probes.

**`/health` endpoint:**
- Returns `200 OK` with `{"status": "alive"}` if the Node.js process is running
- Implementation: simple Express route at `src/routes/health.ts`
- No dependency checks — purely a process liveness signal

**`/ready` endpoint:**
- Returns `200 OK` with `{"status": "ready", "dependencies": {...}}` when all downstream services respond to their own health checks within 2 seconds
- Returns `503 Service Unavailable` with `{"status": "not_ready", "failing": [...]}` when any dependency is unreachable
- Checks: database connection pool, Redis connection, auth service health endpoint
- Implementation: `src/routes/readiness.ts` with a `DependencyChecker` class that runs parallel health checks

- [ ] `/health` returns 200 when process is alive
- [ ] `/ready` returns 200 when all dependencies are healthy
- [ ] `/ready` returns 503 when any dependency is down
- [ ] Neither endpoint requires authentication

**Design decision:** Separate `/health` from `/ready` (rather than a single `/healthz`) because Kubernetes liveness and readiness probes have different semantics. Liveness determines restarts; readiness determines traffic routing. Combining them causes unnecessary restarts during transient dependency failures.

---

## Recommendations Coverage

1. Phase sequencing: Findings 1-6 are addressed in Phase 1 tasks above (with audit logging deferred within Phase 1). Findings 7-8 are Phase 2. This aligns with Recommendation 1. [VERIFIED: override — CORS (Finding 7) excluded from Phase 2 scope per product decision; only health checks remain in Phase 2. CORS handled by CDN layer, not gateway.]
2. Gateway framework: Using Express as the gateway framework rather than Kong/Envoy as recommended, because the team has deep Express expertise and the gateway is a thin routing layer.
