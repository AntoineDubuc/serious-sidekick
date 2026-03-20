---
skill: serious-research
slug: synthetic-api-gateway
status: done
created: 2026-03-20
---

# Synthetic API Gateway Security — Research

## Summary

This is a synthetic research artifact created for verifier testing (Task 5). It contains 8 numbered findings and 2 recommendations, designed to exercise all disposition types in the downstream plan.

## Findings

### Finding 1: JWT Token Validation Required at Gateway

All inbound requests must validate JWT tokens at the API gateway layer before routing to downstream services. Tokens must be checked for expiry, signature validity, and issuer claim. Unsigned or expired tokens must be rejected with 401.

### Finding 2: Rate Limiting on Public Endpoints

Public-facing endpoints must enforce rate limiting to prevent abuse. Recommended: 200 req/min per API key for standard tier, 1000 req/min for premium tier. Use sliding window algorithm with Redis-backed counters.

### Finding 3: Request Payload Size Limits

Enforce maximum payload size of 10MB on all POST/PUT endpoints. Oversized payloads must receive 413 response with a descriptive error body. This prevents memory exhaustion attacks on downstream services.

### Finding 4: TLS 1.3 Enforcement

All gateway traffic must use TLS 1.3 minimum. TLS 1.2 and below must be rejected at the handshake level. Certificate pinning should be implemented for service-to-service communication behind the gateway.

### Finding 5: Audit Logging of All Auth Events

Every authentication event (login, logout, token refresh, failed attempt) must be logged to a centralized audit log. Logs must include timestamp, user ID, IP address, event type, and outcome. Retention: 90 days minimum.

### Finding 6: Input Sanitization for SQL Injection

All user-supplied input must be sanitized before reaching any database query layer. Use parameterized queries exclusively — no string concatenation for SQL. Apply allowlist validation for enum-type fields.

### Finding 7: CORS Policy Configuration

The gateway must enforce a strict CORS policy. Allowed origins must be explicitly listed — no wildcard (`*`) in production. Preflight responses must include correct `Access-Control-Allow-Methods` and `Access-Control-Allow-Headers`.

### Finding 8: Health Check Endpoints

The gateway must expose `/health` and `/ready` endpoints for orchestration tooling. `/health` returns 200 if the process is alive. `/ready` returns 200 only when all downstream dependencies are reachable. Neither endpoint requires authentication.

## Recommendations

1. Implement findings 1-6 in the first phase; findings 7-8 in the second phase.
2. Use a dedicated API gateway framework (e.g., Kong, Envoy) rather than building custom middleware.
