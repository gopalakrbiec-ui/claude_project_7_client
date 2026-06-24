# CLAUDE.md — Project Brief

## Project

Thin Android client (Flutter) for an AI life-event editing app for rural India.

**User flow:** Phone OTP auth → top up credits via UPI → pick a template → enter event details + photo → pay per creation → download and share result to WhatsApp.

**Agent mode:** Local shopkeepers place orders on behalf of walk-in customers and see their commission earnings.

---

## API

- **Base URL:** `https://claudeproject7-production.up.railway.app`
- API request/response models are **generated** from the backend's OpenAPI spec (`/openapi.json`).
- **NEVER hand-write models that duplicate generated ones.**

---

## Tech Stack

Use exactly this unless you flag a strong reason to deviate:

| Concern | Choice |
|---|---|
| Framework | Flutter (stable), Dart, null-safe |
| State management | Riverpod |
| Networking | Dio + typed API client layer + JWT interceptor |
| Models | Generated from OpenAPI (freezed / json_serializable) |
| Routing | go_router |
| i18n | flutter_localizations + ARB files (English + Hindi + Telugu) |
| Secure token storage | flutter_secure_storage |
| Image caching | cached_network_image |

---

## Architecture

```
presentation (screens / widgets)
    ↓
controllers (Riverpod)
    ↓
repositories
    ↓
generated API client (Dio)
```

Keep layers strictly separate. No business logic in widgets.

---

## Non-Negotiable Rules

1. **Backend is truth.** Never compute price, never mark a payment successful, never trust a locally stored balance. Always read price / balance / order-status from the API.
2. **Thin client.** No on-device generation. Flow: capture input → call API → poll status → download result.
3. **Low-end first.** Keep APK small, memory low, assume slow/flaky networks. Every network call must have loading + error + retry states. Compress uploaded images before sending.
4. **Vernacular-first.** No hardcoded user-facing strings; everything via ARB. User picks language on first launch; it drives the whole UI and is sent with each order.
5. **WhatsApp sharing must be one tap** on the finished result screen.

---

## Contract Rules (enforce in code — generator can't capture these)

### Idempotency key on POST /orders
- Generate one UUID per order *attempt*.
- **Reuse** it on retry of that same attempt.
- **Never** regenerate on every tap.
- Prevents double-orders / double-charges on flaky networks.

### Razorpay key_id
- Initialise Razorpay with the `key_id` returned by `POST /payments/create-order`.
- **Never hardcode** the key. This lets us switch test/live without a new build.

### Auth on launch/resume
- Call `GET /auth/me` on every app launch and resume to refresh role + profile.
- Store role alongside the JWT; use it to gate the agent UI.

### Credits display
- Show credits using `balance_rupees` from `GET /credits/balance` (already formatted).
- Keep `balance_paise` only for internal logic.

---

## Style Guidelines

- Small, focused widgets; `const` wherever possible.
- Handle loading / error / empty states explicitly in every screen.
- Write a widget or unit test for each Riverpod controller.
