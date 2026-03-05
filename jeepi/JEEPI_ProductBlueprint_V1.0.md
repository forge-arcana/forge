# JEEPI — BUILD SCOPE v1.0 — CONFIDENTIAL

**Jeepi Technologies** | Metro Manila, Philippines

---

# FULL PLATFORM BUILD SCOPE — VERSION 1.0

Final · GPS-Based Fare · Credit Boarding · Multi-Role · [Launch Date — TBD]

Chris & Pando, Co-Founders

---

> **VERSION 1.0 — CURRENT STATE**
>
> 1. All 19 development phases complete — from multi-seat payment through discounted fares.
> 2. Unified auth model: single User table with PassengerProfile + DriverProfile (multi-role capable).
> 3. GPS-based boarding with hold-settle payment: passenger boards → max fare held → actual fare settled on exit.
> 4. Philippine law compliance: RA 9994/10754/11314 (20% discount for students, seniors, PWDs).
> 5. Payment gateway integration (Xendit) with AMLA anti-money-laundering detection.
> 6. GCP Cloud Run deployment with canary strategy, CI/CD via GitHub Actions.
> 7. 490+ Vitest tests (unit + integration) + 51 Playwright E2E tests.

---

| Section | Title |
|---------|-------|
| 1 | Strategic Foundation & Brand Purpose |
| 2 | Platform Positioning |
| 3 | User Roles & Access Control |
| 4 | Core Functional Modules |
| 5 | Trip Lifecycle & Boarding Flow |
| 6 | Wallet & Payment System |
| 7 | Fare Calculation & Discounted Fares |
| 8 | Anti-Spoofing & Trust Infrastructure |
| 9 | Compliance & KYC |
| 10 | Friends, Companions & Social Features |
| 11 | Notification Architecture |
| 12 | Admin Portal |
| 13 | Technical Architecture |
| 14 | Real-Time Infrastructure |
| 15 | Authentication & Security |
| 16 | Data Model |
| 17 | Onboarding UX |
| 18 | Testing Strategy |
| 19 | CI/CD & Deployment |
| 20 | Regulatory Compliance |
| 21 | Completed Phases |
| 22 | Long-Term Roadmap |

---

## SECTION 1 — STRATEGIC FOUNDATION & BRAND PURPOSE

### 1.1 Brand Purpose

> **Jeepi Brand Purpose**
>
> To digitize trust in Philippine public transit — so every passenger rides with confidence, every driver earns with transparency, and the jeepney evolves without losing its soul.

### 1.2 What Jeepi Is Building

Jeepi is a digital fare payment and fleet management platform for Philippine jeepneys. Passengers board via QR scan, pay with a digital wallet, and exit with a tap. Drivers see real-time dashboards with automated accounting. Operators get fleet analytics and compliance tools. The platform eliminates the "barya" (exact change) problem, reduces driver distraction from cash handling, and creates a transparent digital record of every ride.

### 1.3 The Three Audiences

| Dimension | Passengers | Drivers | Operators/Admin |
|-----------|-----------|---------|----------------|
| Core emotion | Convenience — no more fumbling for exact change | Fairness — every fare accounted for, every peso tracked | Control — full visibility into fleet operations |
| Brand promise | Board and ride without cash | Earn transparently, withdraw instantly | Manage your fleet with data, not guesswork |
| Deepest fear | Overpaying, unsafe boarding, losing track of spending | Losing fares to miscounting, being cheated by the system | Revenue leakage, unaccountable drivers, regulatory risk |
| Jeepi's answer | GPS-based fare with max-fare hold — you never overpay | Real-time earnings dashboard, instant cashout, trip confidence scoring | AMLA compliance, reconciliation audits, revenue analytics |

### 1.4 Non-Negotiables

- **GPS-based fare** — passengers never manually select destinations. Hold max fare on boarding, settle actual fare on exit.
- **Wallet-first** — all transactions through the digital wallet. Cash is the driver's problem, not the platform's.
- **Philippine law compliance** — RA 9994 (seniors), RA 10754 (PWDs), RA 11314 (students) discount enforcement from day one.
- **Driver dignity** — drivers are professionals with their own dashboard, wallet, earnings history, and instant cashout.
- **Multi-trip reality** — multiple active trips per route, multiple drivers on the same route, passengers see only their trip.
- **Anti-spoofing** — every trip scored for GPS confidence. Disputes blocked on high-confidence trips.
- **Audit everything** — every human-initiated action logged with actor, timestamp, and GPS coordinates.
- **Bilingual** — English and Filipino (Tagalog) from day one, with extensible i18n for Cebuano, Ilocano, Hiligaynon.

---

## SECTION 2 — PLATFORM POSITIONING

### 2.1 Positioning Statement

> Jeepi is the Philippines' first GPS-based digital fare platform purpose-built for jeepneys — the country's most iconic public transport. We bring the reliability of modern transit payment to the routes Filipinos ride every day.

### 2.2 Jeepi vs. Existing Solutions

| Dimension | Cash (Status Quo) | Beep Card (AFCS) | Jeepi — Advantage |
|-----------|-------------------|-------------------|-------------------|
| Boarding speed | Slow (coin counting) | Medium (card tap) | Fast (QR scan, auto-fare) |
| Fare accuracy | Error-prone (manual) | Fixed route fare | GPS-calculated to the stop |
| Discount compliance | Inconsistent | Card-based | KYC-verified, auto-applied |
| Driver earnings visibility | Zero | Partial | Full dashboard + instant cashout |
| Fleet analytics | None | Central operator only | Real-time admin portal |
| Anti-spoofing | N/A | N/A | Trip confidence scoring (0–100) |
| Companion seats | Ad hoc | Not supported | Dagdag Bayad (hold + settle per seat) |
| Fare sponsorship | Not possible | Not possible | Libre Ka-Jeepi (sponsor a friend) |
| Offline resilience | Always works | Card reader required | IndexedDB queue + retry |
| Infrastructure cost | Zero | Terminal hardware per jeepney | Phone-only (driver + passenger) |

### 2.3 Target Market

- **Phase 1 (MVP):** Metro Manila — 5 seed routes (Monumento↔Quiapo, Cubao↔Fairview, Divisoria↔SM North, Baclaran↔Lawton, Philcoa↔Katipunan), 20 stops each with real GPS landmarks.
- **Phase 2:** Cebu, Davao, Clark expansion.
- **Phase 3:** Nationwide — any jeepney route with GPS-mapped stops.

---

## SECTION 3 — USER ROLES & ACCESS CONTROL

### 3.1 Role System

| Role | Key Permissions |
|------|----------------|
| **Passenger** | Board trips, pay fares, manage wallet (reload/auto-reload), view trip history, file disputes, add companions (Dagdag Bayad), sponsor friends (Libre Ka-Jeepi), manage friends list, upload KYC documents, receive notifications. |
| **Driver** | Start/end trips, view active passengers, accept/reject payments, view earnings dashboard, initiate cashout, manage trip lifecycle. Authenticated via unified User table with DriverProfile. |
| **Admin** | Full platform management: user CRUD, trip oversight, dispute resolution, KYC review, AMLA flag review, revenue analytics, reconciliation audits, system settings, force logout, session management. All actions audit-logged. |
| **Founder** | Admin + founders-only revenue dashboard with net revenue, platform costs, and reconciliation reports. |

> **MULTI-ROLE ARCHITECTURE**
>
> A single User can hold multiple roles simultaneously (e.g., a driver who is also a passenger). The User table is shared; PassengerProfile and DriverProfile are separate linked tables. Auth headers are page-aware — the driver page sends driver credentials, the passenger page sends passenger credentials.

### 3.2 Auth Middleware Priority

```
Driver page  → X-Driver-Id + X-Session-Token (driver session)
Passenger page → X-User-Id + X-Session-Token (passenger session)
Admin page → X-User-Id + X-Session-Token (admin session)
```

Mutually exclusive — never sends both simultaneously. Page context determined by `window.location.pathname`.

---

## SECTION 4 — CORE FUNCTIONAL MODULES

### 4.1 Passenger App

- **Login:** Google OAuth, Phone OTP, email/password (dev only). Skeleton loading during auth.
- **Boarding:** QR scan (camera via html5-qrcode) or manual code entry → GPS proximity check → balance hold → seat assignment.
- **Active Trip View:** Route progress tracker (horizontal train-style), seat info, fare estimate, "PARA PO!" stop button, companions count.
- **Wallet:** Balance display, held amount indicator, reload (cash/GCash/Maya/GrabPay/card), auto-reload settings, transaction history.
- **Friends:** Add by name/email/phone, accept/reject requests, Libre Ka-Jeepi fare sponsorship.
- **Settings:** Theme (light/dark/system), language (EN/TL/CEB/ILO/HIL), account management.

### 4.2 Driver App

- **Login:** Google OAuth, Phone OTP with role check (must have DriverProfile).
- **Dashboard:** Claim jeepney (QR scan or code entry), start trip, active passenger list with fare status.
- **Trip Management:** Accept/reject payments, view stopping passengers, end trip (auto-settles all seats).
- **Route Progress:** Horizontal train-style tracker showing current position + next stops + terminal.
- **Earnings:** Daily/weekly/monthly summary with trip breakdown, convenience fee details, instant cashout to wallet.

### 4.3 Admin Dashboard

Multi-page admin portal with 15 sub-pages:

| Module | Functions |
|--------|-----------|
| Passengers | Search, edit, wallet management, KYC status, discount eligibility |
| Drivers | CRUD, jeepney assignment, wallet balance, status management |
| Jeepneys | Fleet management: plate numbers, route assignment, seat capacity |
| Routes | Route CRUD with 20-stop GPS coordinates per route |
| Sessions | Active session viewer, force logout (auto-ends driver trips) |
| Disputes | Priority queue, trip telemetry review, resolution (refund/partial/no-action/pay-driver) |
| KYC | Document review queue (image + PDF), approve/reject, discount tier assignment |
| AMLA | Anti-money-laundering flag review (large tx, rapid series, structuring) |
| Payments | Gateway transaction viewer, status/channel/date filtering, aggregate stats |
| Transactions | Wallet transaction history across all users |
| Audit Logs | Immutable audit trail, filterable by actor/action/date, exportable |
| Credit | Credit abuse detection, flagged users, device fingerprint matching |
| Settings | Global config: fares, fees, thresholds, minAppVersion |
| Founders | Revenue summary, net revenue, platform cost tracking, reconciliation reports |

---

## SECTION 5 — TRIP LIFECYCLE & BOARDING FLOW

### 5.1 Complete Trip Flow

```
1. Driver logs in → scans jeepney QR / enters code → "Start Trip"
2. Passenger logs in → scans jeepney QR / enters code
3. System: GPS proximity check (100m) → hold max fare from wallet → assign seat
4. Passenger rides — GPS tracked every 10 seconds
5. Passenger presses "PARA PO!" → system calculates actual fare (GPS-based)
6. Driver acknowledges → fare settled (held amount - actual fare refunded)
7. Driver ends trip → all remaining seats auto-settled
```

### 5.2 Boarding (Hop-In) Validation Chain

1. Trip must be active (not completed/cancelled)
2. GPS proximity within 100m of jeepney (skipped in dev/staging)
3. Passenger has sufficient wallet balance (min ₱50 or max fare, whichever is less)
4. Seat capacity check (20 default, minus occupied + reserved)
5. Idempotent re-boarding check (prevent double-board)
6. KYC wallet tier enforcement (Level 0: ₱500 cap, Level 1: ₱5,000, Level 2: ₱50,000)
7. Atomic transaction: hold balance + assign seat + log boarding location

### 5.3 Settlement Logic

- **Normal exit (Para Po):** Calculate actual fare from boarding stop to alighting stop. Deduct from held balance. Refund excess.
- **Trip end (driver):** All occupied seats auto-settled at current GPS position.
- **Zero-fare seats:** Seats where passenger hasn't selected destination → `pending_settlement` status → admin dispute.
- **Credit boarding:** Hold capped at min(maxFare, ₱50). Passenger may go negative on settlement. 3 negative events → auto credit-blocked.

### 5.4 Stale Trip Sweep

Background job (every 5 minutes) checks for trips where the driver's session is null or expired. Stale trips are auto-ended via `TripLifecycle.endTripById()`. Does NOT auto-end based on trip duration — drivers choose their own hours.

### 5.5 Route Progress Display

Horizontal train-style tracker showing 5 dots:
- 1 previous stop (greyed, 40% opacity)
- Current stop (primary color, glow ring)
- 2 next stops
- Terminal stop (ring dot with flag icon, dashed line if gap exists)

All labels wrap to 2 lines. Updates on every GPS tick.

---

## SECTION 6 — WALLET & PAYMENT SYSTEM

### 6.1 Wallet Architecture

| Feature | Detail |
|---------|--------|
| Currency | Philippine Peso (₱) |
| Wallet types | PassengerProfile.walletBalance, PassengerProfile.heldBalance, DriverProfile.walletBalance |
| Reload channels | CASH (admin), EWALLET_GCASH, EWALLET_MAYA, EWALLET_GRABPAY, CARD, BANK_TRANSFER, OTC |
| Gateway | Xendit (production), Mock adapter (dev/staging) |
| Auto-reload | Configurable threshold + amount per passenger, uses default payment method |
| Driver cashout | Min ₱100, max ₱50,000 per transaction |
| Transaction history | Paginated, filterable by type (reload/deduct/fare/refund/cashout) and date range |

### 6.2 KYC Wallet Tiers (BSP e-Money Circular)

| Level | Requirement | Max Balance |
|-------|-------------|-------------|
| 0 — Unverified | Registration only | ₱500 |
| 1 — Basic KYC | Government ID | ₱5,000 |
| 2 — Full KYC | Government ID + proof of address | ₱50,000 |

### 6.3 Payment Gateway Flow

```
Passenger → POST /wallet/reload → PaymentGateway.createCharge()
         → Xendit eWallets/Invoices API → redirectUrl to payment page
         (passenger completes payment on Xendit-hosted page)
         → POST /api/webhooks/xendit (webhook callback)
         → Payment.status = completed → wallet credited → AMLA check
         → Socket.io state-update → UI reflects new balance
```

### 6.4 Convenience Fees

| Fee Type | Amount | Charged To |
|----------|--------|------------|
| Passenger boarding fee | ₱1.00 per seat | Passenger (on settlement) |
| Driver settlement fee | ₱0.20 per settlement | Driver (on settlement) |
| Discounted convenience fee | 50% of standard (₱0.50) | Discount-eligible passengers |

---

## SECTION 7 — FARE CALCULATION & DISCOUNTED FARES

### 7.1 Fare Formula

```
fare = baseFare + (perKmRate × distanceKm)
     = ₱13.00 + (₱1.80 × km from boarding stop to alighting stop)
```

- **Base fare:** ₱13.00 (first 4 km included)
- **Per-km rate:** ₱1.80
- **Max fare:** Calculated at boarding from boarding stop to farthest terminal
- **Hold amount:** min(maxFare, wallet tier cap)

### 7.2 Discounted Fares — Philippine Law Compliance

| Law | Beneficiary | Discount | ID Required | Expiry |
|-----|-------------|----------|-------------|--------|
| RA 11314 | Students | 20% | Student ID / enrollment cert | 180 days (per semester) |
| RA 9994 | Senior Citizens (60+) | 20% | OSCA ID / gov ID with DOB | Permanent |
| RA 10754 | Persons with Disability | 20% | PWD ID (NCDA/LGU-issued) | 365 days |

**Implementation:**
1. Passenger uploads discount KYC document (student_id, osca_id, pwd_id)
2. Admin reviews and approves → PassengerProfile.discountType set
3. On boarding, seat caches `discountType` and `discountApplied` rate
4. Settlement applies 20% discount to calculated fare
5. 24-hour background sweep clears expired discounts

**Example (25km trip = ₱50.80 base):**

| Passenger Type | Fare | Conv. Fee | Total |
|----------------|------|-----------|-------|
| Regular | ₱50.80 | ₱1.00 | ₱51.80 |
| Student/Senior/PWD | ₱40.64 | ₱0.50 | ₱41.14 |

---

## SECTION 8 — ANTI-SPOOFING & TRUST INFRASTRUCTURE

### 8.1 Trip Confidence Scoring

Every completed trip receives a confidence score (0–100) based on GPS telemetry:

| Signal | Weight | What It Measures |
|--------|--------|-----------------|
| QR Scan | 50 pts | Physical presence at boarding (QR verified) |
| GPS Track | 30 pts | Consistent GPS pings along route (no teleportation) |
| Speed Check | 10 pts | Movement speed within reasonable bounds (< 120 km/h) |
| BLE Proximity | 10 pts | Bluetooth beacon proximity to driver device |

### 8.2 Spoofing Detection Thresholds

| Check | Threshold | Action |
|-------|-----------|--------|
| GPS jump distance | > 500m in 15 seconds | Flag as teleportation |
| Movement speed | > 120 km/h | Flag as impossible speed |
| GPS accuracy | > 500m radius | Flag as unreliable GPS |
| GPS pulse interval | Expected every 10 seconds | Missing pulses reduce score |

### 8.3 Dispute Gating

- **Score ≥ 75 (high confidence):** Dispute filing blocked. Trip is verified legitimate.
- **Score 40–74:** Dispute allowed, admin review required.
- **Score < 40:** Dispute auto-prioritized for admin attention.

### 8.4 Offboard Detection

Background monitor checks every 30 seconds for passenger exit signals:
- **GPS divergence:** Passenger GPS > 200m from jeepney for > 2 minutes (60% weight)
- **BLE loss:** Bluetooth connection lost for > 1 minute (30% weight)
- **Route terminus:** Jeepney reaches terminal stop (definitive)

Auto-settles at ≥ 80 confidence. Escalates to admin at 50–79.

---

## SECTION 9 — COMPLIANCE & KYC

### 9.1 KYC Document Types

| Document | Purpose | Format |
|----------|---------|--------|
| Government ID | Identity verification (passport, driver's license, PhilSys, PRC) | Image or PDF |
| Proof of Address | Barangay clearance, utility bill | Image or PDF |
| Driver's License | For driver registration | Image or PDF |
| CPC (Certificate of Public Convenience) | Operator license | Image or PDF |
| OR/CR (Official Receipt / Certificate of Registration) | Vehicle registration | Image or PDF |
| Student ID | RA 11314 student discount eligibility | Image or PDF |
| OSCA ID | RA 9994 senior citizen discount eligibility | Image or PDF |
| PWD ID | RA 10754 PWD discount eligibility | Image or PDF |

### 9.2 AMLA Anti-Money Laundering

| Flag Type | Trigger | Threshold |
|-----------|---------|-----------|
| Large transaction | Single charge | ≥ ₱500,000 |
| Rapid series | Multiple completed charges in window | 5 charges in 24 hours |
| Structuring | Near-threshold transactions | Multiple near ₱450,000 |

All flags create `AmlaFlag` records for admin review. Statuses: pending → cleared / suspicious / reported.

### 9.3 Credit Abuse Detection

- **CreditEvent logging:** Tracks negative balance occurrences, device fingerprint matches, rapid series
- **Auto-block:** 3 negative balance events → account status changes to `credit_blocked`
- **Device fingerprinting:** djb2 hash of browser properties, detects multiple accounts per device
- **Admin review:** Unblock, suspend, or clear flags via admin credit dashboard

### 9.4 Audit Trail

Every human-initiated route handler logs via `req.log.info()`:

```javascript
req.log.info({ userId, tripId }, 'trip_started');
req.log.info({ email, attempts }, 'login_failed_wrong_password');
req.log.warn({ passengerId, reason: 'insufficient_balance' }, 'boarding_rejected');
```

All entries stored in `AuditLog` table with actor, action, resource, IP, user agent. Immutable — cannot be modified or deleted. Retained 7 years.

---

## SECTION 10 — FRIENDS, COMPANIONS & SOCIAL FEATURES

### 10.1 Friends System

- Add friends by name, email, or phone
- Accept/reject friend requests
- View friends list (accepted only)
- Mutual — both parties see each other

### 10.2 Dagdag Bayad (Add Companions)

For passengers riding with companions who don't have Jeepi accounts:
- Add 1–3 companion seats while on an active trip
- Each companion seat holds the same max fare as the primary passenger
- All companion seats settle when primary passenger presses "PARA PO!"
- Grouped under a single `groupId` for display ("You + 2 companions")

### 10.3 Libre Ka-Jeepi (Sponsor a Friend)

Sponsor a friend's fare on the same trip:
- Both must be on the same active trip
- Must be accepted friends
- Sponsor's wallet covers friend's fare
- Cancellable before settlement

---

## SECTION 11 — NOTIFICATION ARCHITECTURE

| Event | Recipient | Channel | Priority |
|-------|-----------|---------|----------|
| Boarding successful | Passenger | Push + In-app | HIGH |
| Para Po acknowledged | Passenger + Driver | Push + In-app | HIGH |
| Fare settled | Passenger | Push + In-app | HIGH |
| Wallet reload completed | Passenger | Push + In-app | HIGH |
| Low balance warning | Passenger | Push + In-app | MEDIUM |
| Companion seats added (Dagdag) | Passenger | Push + In-app | MEDIUM |
| Libre Ka-Jeepi received | Sponsored friend | Push + In-app | HIGH |
| Friend request received | Recipient | Push + In-app | MEDIUM |
| KYC document approved/rejected | Passenger/Driver | Push + In-app | HIGH |
| Dispute resolved | Passenger | Push + In-app | HIGH |
| Force logout | User | In-app + Alert | CRITICAL |
| Trip confidence flagged | Admin | Internal | HIGH |
| AMLA flag created | Admin | Internal | HIGH |

**Delivery stack:** In-app (Socket.io real-time) → Firebase Cloud Messaging (push) → persisted in Notification table (30-day expiry).

---

## SECTION 12 — ADMIN PORTAL

See Section 4.3 for the full module breakdown. Key design principles:

- **Multi-page SPA:** Each admin function is a separate HTML page loaded into the admin shell via sidebar navigation.
- **Auth gate:** `AdminAuth.require()` checks `adminSessionToken` in localStorage. Rate limited: 5 attempts per 15 minutes.
- **All actions audit-logged:** Every admin operation creates an AuditLog entry.
- **Founders-only dashboard:** Revenue summary, net revenue (gross - platform costs), CSV export, reconciliation status.

---

## SECTION 13 — TECHNICAL ARCHITECTURE

### 13.1 Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Backend | Node.js + Express | Single server, single port (default 5000) |
| Database | PostgreSQL (Neon) | Prisma 7 ORM, @prisma/adapter-pg (mandatory driver adapter) |
| Real-time | Socket.io | State sync, GPS updates, notifications |
| Frontend | Vanilla JS | No framework. Multi-page: passenger, driver, admin, settings |
| Auth | Session tokens + Google OAuth + Phone OTP | Unified User table, Semaphore SMS for OTP |
| Payments | Xendit (production), Mock adapter (dev) | eWallets, invoices, disbursements |
| Push notifications | Firebase Cloud Messaging (FCM) | Optional — gracefully disabled if not configured |
| Logging | Pino | GCP Cloud Logging compatible, structured JSON |
| Deployment | Docker → GCP Cloud Run | Canary 10% → smoke test → promote 100% |
| Testing | Vitest + Playwright | 490+ unit/integration + 51 E2E |
| i18n | Custom I18n service | 5 languages: EN, TL, CEB, ILO, HIL |

### 13.2 Project Structure

```
jeepi/
├── server.js                 # Entry point (~88 lines)
├── startup/                  # Server composition
│   ├── middleware.js          # Express middleware chain
│   ├── services.js            # Service factory (returns ctx)
│   ├── routes.js              # Route mounting (25+ groups)
│   ├── socket.js              # Socket.io setup + GPS rate limiting
│   └── jobs.js                # Background jobs + graceful shutdown
├── services/
│   ├── core/                  # db, logger, state, geo, seed, rate-limit
│   ├── auth/                  # google-token-verifier, sms-otp
│   ├── payment/               # payment-service, payment-gateway, fee-service
│   │   └── adapters/          # mock-payment-adapter, xendit-adapter
│   ├── trip/                  # trip-lifecycle, gps-simulator, offboard-monitor,
│   │                          # reservation-matcher, location-logger, confidence-service
│   ├── compliance/            # kyc-service, audit-service, amla-service
│   ├── notification/          # notification-service, push-service
│   └── finance/               # revenue-service, reconciliation-service, auto-reload
├── routes/                    # 25+ API route files
├── middleware/                # auth, rbac, idempotency, version-check, validate
├── config/                    # constants.js, env.js
├── client/                    # ALL frontend files
│   ├── *.html                 # Page shells (passenger, driver, admin, settings, landing)
│   ├── pages/                 # Page logic (JS) + admin sub-pages (HTML + JS)
│   ├── components/            # Shared UI components
│   ├── services/              # JeepneyService, StorageService, GpsService, etc.
│   ├── locales/               # i18n translations (en, tl, ceb, ilo, hil)
│   ├── icons/                 # SVG icon system
│   ├── lib/                   # Third-party (html5-qrcode)
│   └── sounds/                # Audio feedback (boarding, para-po)
├── prisma/
│   ├── schema.prisma          # 25 models, PostgreSQL only
│   └── prisma.config.ts       # CLI-only config
├── test/                      # Unit + integration tests
├── e2e/                       # Playwright E2E tests
└── .github/workflows/         # CI/CD deploy.yml
```

### 13.3 Key Architecture Patterns

| Pattern | Where Used |
|---------|-----------|
| **Service factory** | `startup/services.js` creates all services, returns shared `ctx` |
| **Payment adapter** | Mock (dev/test) vs Xendit (production) via factory |
| **Rate limit provider** | Memory (default), noop (E2E tests), Redis (future) |
| **Fire-and-forget** | Audit, location logging, auto-reload — never block primary flow |
| **Singleton mutation** | `TripLifecycle.endTripById()` — single shared method for all trip-end paths |
| **Graceful shutdown** | SIGTERM/SIGINT → cleanup jobs → close DB → shutdown server |
| **Socket.io broadcasting** | State updates via `state-update` event; notifications via `notification` event |
| **Prisma transactions** | All wallet operations, seat assignments, and settlements use `$transaction` |
| **Canary deployment** | New revision at 0% traffic → smoke test → promote to 100% |

---

## SECTION 14 — REAL-TIME INFRASTRUCTURE

### 14.1 Socket.io Events

| Event | Direction | Purpose |
|-------|-----------|---------|
| `state-update` | Server → Client | Full state broadcast (users, trips, routes, jeepneys) |
| `notification` | Server → Client | In-app notification delivery |
| `gps-update` | Client → Server | Driver/passenger GPS position (rate limited: 1/sec) |
| `force_logout` | Server → Client | Account accessed from another device |
| `wallet_update` | Server → Client | Wallet balance change (fallback) |

### 14.2 GPS Tracking

- **Real GPS:** Client sends position via Socket.io `gps-update` every 10 seconds
- **Simulated GPS:** Server-driven simulation for test drivers — moves along route at 20x speed, 1-second ticks
- **Location logging:** GPS coordinates logged to `LocationLog` table every 60 seconds + at route stops

### 14.3 State Synchronization

The server maintains authoritative state. On every mutation (trip start, boarding, settlement, etc.), `broadcastUpdate()` sends the full state to all connected clients. Clients cache state in `StorageService` and trigger re-renders via `notifyAll()`.

---

## SECTION 15 — AUTHENTICATION & SECURITY

### 15.1 Auth Methods

| Method | Environment | Flow |
|--------|-------------|------|
| Google OAuth | All | Google Sign-In JWT → server verifies via JWKS → auto-register or link |
| Phone OTP | All | Enter phone → Semaphore SMS (prod) or in-memory mock (dev) → verify code |
| Email/Password | Dev only | Traditional registration with bcrypt hashing |
| Mock OAuth | Dev/Staging | Click "Sign in with Google (Dev)" → mock credential with any email |

### 15.2 Security Hardening

| Measure | Implementation |
|---------|---------------|
| Helmet | Security headers (CSP, HSTS, X-Frame-Options) |
| CORS | Configurable allowed origins |
| Rate limiting | Auth: 5/15min, OTP: 5/min, Wallet: 10/min |
| Input validation | express-validator on all endpoints |
| Session management | 24-hour token expiry, single active session per user |
| Account lockout | 5 failed login attempts → 15-minute lockout |
| RBAC | Role-based access control at API level (not UI only) |
| Idempotency | Request deduplication for wallet and seat operations |
| Bot protection | Device fingerprinting + rate limiting on registration |

### 15.3 HTTPS Support

- Auto-detects `server.key`/`server.cert` — HTTPS if present, HTTP fallback
- Required for QR camera access on mobile browsers
- Certificate generation via `node generate-certs-forge.js` (self-signed for development)

---

## SECTION 16 — DATA MODEL

### 16.1 Core Models (25 Prisma Models)

**Identity & Auth:**
- `User` — Unified auth table (email, phone, googleId, role, session token, account status)
- `PassengerProfile` — Wallet balance, held balance, discount eligibility, auto-reload, ToS
- `DriverProfile` — Wallet balance, status

**Trip & Fleet:**
- `Route` — Name, description, stops (JSON array of {name, lat, lng})
- `Jeepney` — Plate number, route assignment, seat count
- `Trip` — Active/completed trips with timing, direction, route snapshot
- `Seat` — Passenger occupancy, fare, discount, boarding/alighting GPS, sponsorship
- `Reservation` — Pre-booking with balance hold, 30-min expiry, matching lifecycle

**Financial:**
- `Transaction` — All wallet movements with previous/new balance snapshots
- `Payment` — Gateway charges + disbursements, webhook tracking
- `PaymentMethod` — Tokenized cards/eWallets
- `ConvenienceFee` — Per-seat boarding + settlement fees
- `PlatformCost` — Operational costs (Xendit fees, GCP, domain)
- `ReconciliationReport` — Balance audits + transaction integrity checks

**Compliance:**
- `KycDocument` — Document uploads with review workflow + expiry tracking
- `AuditLog` — Immutable human-action log
- `AmlaFlag` — Anti-money-laundering detection events
- `TripConfidence` — GPS telemetry scoring per trip
- `Dispute` — Passenger disputes with admin resolution workflow
- `CreditEvent` — Fraud detection (negative balance, device matches)

**Supporting:**
- `LocationLog` — GPS audit trail (boarding, alighting, tracking, login events)
- `Notification` — In-app notifications with expiry + read status
- `DeviceToken` — FCM push registration
- `FriendRequest` — Friend management lifecycle
- `IdempotencyKey` — Request deduplication
- `SystemSettings` — Global configuration singleton

---

## SECTION 17 — ONBOARDING UX

### 17.1 Passenger Onboarding

| Step | Screen |
|------|--------|
| 1 — Welcome | Landing page with jeepney branding, "Sakay Na!" CTA |
| 2 — Auth | Google Sign-In or Phone OTP (primary), email/password (dev fallback) |
| 3 — ToS | Terms of Service acceptance (version tracked, required before boarding) |
| 4 — Tutorial | 4-step guided introduction (boarding, route tracking, Para Po!, companions) |
| 5 — Wallet setup | Initial reload prompt with minimum balance explanation |

### 17.2 Driver Onboarding

| Step | Screen |
|------|--------|
| 1 — Auth | Google Sign-In or Phone OTP with driver role verification |
| 2 — Claim jeepney | QR scan or manual code entry for assigned vehicle |
| 3 — Tutorial | 4-step driver guide (claim jeepney, accept passengers, Para Po, earnings) |
| 4 — Dashboard | Active trip view with passenger list and earnings |

### 17.3 Design System

- **Color palette:** Philippine flag colors — Primary #0038A8 (blue), Accent #CE1126 (red), Highlight #FCD116 (yellow)
- **Theme support:** Light, Dark, System (CSS custom properties)
- **Typography:** System fonts, minimum 16px body
- **Components:** Design tokens, CSS component library, SVG icon system
- **Accessibility:** Minimum 44×44px tap targets, contrast ratios, bilingual toggle on every screen

---

## SECTION 18 — TESTING STRATEGY

### 18.1 Test Coverage

| Type | Count | Framework | Focus |
|------|-------|-----------|-------|
| Unit | 166 | Vitest | GeoService (haversine, fare calc), PaymentService, validation, RBAC |
| Integration | 324 | Vitest + Supertest | Auth flows, wallet, trips, boarding, settlement, Socket.io |
| E2E | 51 | Playwright | Browser-based multi-user flows, admin operations |
| **Total** | **541** | — | Sequential execution (shared DB), 30s timeout |

### 18.2 Test Infrastructure

- **Local:** Docker PostgreSQL (postgres:16-alpine) via WSL2 — ~25s for full suite
- **CI:** Neon PostgreSQL — ~320s for full suite
- **Auto-detection:** `global-setup.js` probes Docker first, falls back to Neon
- **E2E pre-flight:** Kill zombies → check DB → schema sync → global-setup handles cleanup

### 18.3 Key Test Categories

```
test/
├── unit/           # geo, payment-service, gps-simulator, rbac, validation, security-headers
├── integration/    # auth, trip-lifecycle, wallet, friends, boarding, settlement, socket-auth,
│                   # wallet-history, driver-earnings, api-versioning, idempotency, admin-rbac
└── e2e/            # smoke, auth, admin, trip-lifecycle, wallet, settings, passenger-flows,
                    # button-loading, discount-fares, oauth-otp, credit-boarding, driver-earnings,
                    # friends-libre, notifications
```

---

## SECTION 19 — CI/CD & DEPLOYMENT

### 19.1 Infrastructure

| Component | Service | Region |
|-----------|---------|--------|
| Container Registry | GCP Artifact Registry | asia-southeast1 |
| Compute | GCP Cloud Run | asia-southeast1 |
| Database | Neon PostgreSQL | (managed) |
| Secrets | GCP Secret Manager | DATABASE_URL |
| Auth | Workload Identity Federation | Keyless GitHub → GCP |
| CI/CD | GitHub Actions | deploy.yml on WIP branch push |

### 19.2 Deploy Pipeline

```
Push to WIP branch
  → Test job (ubuntu-latest)
    → PostgreSQL service container
    → npm ci → prisma generate → prisma db push → npm test
  → Build & Deploy job (needs: test)
    → WIF keyless auth to GCP
    → Docker build + push to Artifact Registry
    → Prisma migrate against production DB
    → Cloud Run deploy:
      - First deploy: 100% traffic
      - Subsequent: canary revision (0% traffic, tagged "canary")
    → Smoke test: GET /health → HTTP 200
    → Promote: shift 100% traffic to new revision
```

### 19.3 Environment Profiles

| Profile | Resolution | Features |
|---------|-----------|----------|
| **Development** | Default (no NODE_ENV) | Mock auth, seed data, skip proximity, GPS sim, unauthenticated sockets, mock SMS |
| **Staging** | NODE_ENV=production + ALLOW_MOCK_AUTH=true | Same as dev (testing with production build) |
| **Production** | NODE_ENV=production | All guards enabled, real auth, real SMS, no seeding |

---

## SECTION 20 — REGULATORY COMPLIANCE

### 20.1 Applicable Philippine Laws

| Regulation | Area | Jeepi Implementation |
|-----------|------|---------------------|
| RA 9994 | Senior Citizen discount (20%) | KYC-verified via OSCA ID, auto-applied on boarding |
| RA 10754 | PWD discount (20%) | KYC-verified via PWD ID, 365-day expiry |
| RA 11314 | Student discount (20%) | KYC-verified via Student ID, 180-day semester expiry |
| RA 10173 (DPA) | Data Privacy Act | Audit logging, data retention policies, NPC registration |
| AMLA | Anti-Money Laundering | Transaction monitoring, flag creation, admin review |
| BSP Circular | e-Money regulations | KYC wallet tiers (₱500/₱5,000/₱50,000), operator licensing |

### 20.2 Pre-Launch Regulatory Checklist

| Requirement | Regulator | Priority |
|-------------|-----------|----------|
| BSP EMI license confirmation | BSP | CRITICAL |
| DPO designation + NPC registration | NPC | CRITICAL |
| AMLC registration | AMLC | CRITICAL |
| Privacy Policy v1.0 | NPC | HIGH |
| QR Ph merchant registration | BSP | HIGH |
| BIR/VAT registration | BIR | HIGH |

---

## SECTION 21 — COMPLETED PHASES

| Phase | Name | Key Deliverables | Tests Added |
|-------|------|-----------------|-------------|
| 0 | Multi-Seat Payment | Core fare system, multi-passenger support | — |
| 1 | Foundation Infrastructure | Neon PostgreSQL, SystemSettings, CI/CD, graceful shutdown | — |
| 2 | Theming & i18n | 5 languages, light/dark/system themes | — |
| 3 | Scalable Persistence | Prisma ORM migration | — |
| 4 | Friends & Group Payments | Friend requests, Dagdag Bayad, Libre Ka-Jeepi | — |
| 5 | HTTPS + QR Scanner | Camera boarding, self-signed certs | — |
| 6 | Security v1 | CORS, rate limiting, auth, input validation | 111 |
| 7 | Foundation Infrastructure v2 | Neon PG, location audit trail, GPS pulsing | 124 |
| 8 | Security v2 | Helmet, RBAC, token expiry, lockout, validation | 169 |
| 9 | Friends & Notifications | In-app notification center | 185 |
| 10 | Dagdag/Libre/Reserve | Companion seats, fare sponsorship, reservations | 217 |
| 11 | KYC + Audit | Document management, wallet tiers, audit logging | 263 |
| 12 | Payments (Xendit) | PaymentGateway facade, AMLA, auto-reload, cashout | 322 |
| 13 | Anti-Spoofing | TripConfidence scoring, disputes, login block | 357 |
| 14 | Revenue & Reconciliation | Convenience fees, revenue analytics, reconciliation | 394 |
| 15 | UX Polishing | SVG icons, design tokens, onboarding, accessibility | 394 |
| 16 | Wallet History + Versioning | Transaction history, API v1 aliasing, offline queue | 427 |
| 17 | Multi-Trip + Offboard | Multi-trip state, TripLifecycle, offboard detection | 427 |
| 18 | OAuth + OTP + Bot Protection | Google OAuth, Phone OTP, staging gates | 454 |
| 19 | Driver-User Unification | Shared User table, PassengerProfile, DriverProfile | 454 |
| 20 | Discounted Fares | RA 9994/10754/11314, KYC discount flow, admin review | 490 |

---

## SECTION 22 — LONG-TERM ROADMAP

| Phase | Timeline | Key Deliverables |
|-------|----------|-----------------|
| **Current — Stabilization** | Now | CI/CD verification, staging bug fixes, auth header hardening, UI polish |
| **Next — Passkeys** | Q2 2026 | WebAuthn passkey registration, biometric login, session management upgrade |
| **Phase 2 — Mobile (Capacitor)** | Q2–Q3 2026 | Native Android/iOS apps via Capacitor, push notification permissions, app store submission, mobile-only production access |
| **Phase 3 — Pilot** | Q3 2026 | Real-world pilot with 5 routes in Metro Manila, driver training, passenger onboarding campaign |
| **Phase 4 — Scale** | Q4 2026 | Expansion to Cebu + Davao, fleet partnership agreements, real Xendit payment processing, BSP compliance sign-off |
| **Phase 5 — National** | 2027 | Nationwide route coverage, public API for fleet operators, multi-operator support, advanced analytics |

---

*JEEPI — BUILD SCOPE v1.0 — CONFIDENTIAL*
*Generated 2026-03-05*
