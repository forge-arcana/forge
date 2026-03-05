# KAIN! — BUILD SCOPE v1.0 — CONFIDENTIAL

**Kain!** | Metro Manila, Philippines

---

# FULL PLATFORM BUILD SCOPE — VERSION 1.0

Status: Draft · Zero-Markup Food Delivery · Launch Date: TBD

Chris & Pando, Co-Founders

---

> **VERSION 1.0 — MVP SCOPE**
>
> 1. A food delivery app that lists food at actual restaurant prices by outsourcing deliveries to existing platforms via API
> 2. React Native mobile app + React web portals + Node.js backend + PostgreSQL
> 3. Customer browses → orders → pays → restaurant accepts → rider dispatched via API → unique code handoff → delivery confirmed → rating
> 4. Customer, Restaurant Owner, Admin
> 5. PayMongo (GCash/Maya/card), Grab Express/Lalamove API, Firebase Auth, Semaphore SMS
> 6. MVP: core ordering flow, payments, real-time tracking, restaurant management. Deferred: scheduled orders, suggested orders, premium subscriptions, wallet, multi-restaurant orders

---

## TABLE OF CONTENTS

1. Strategic Foundation & Brand Purpose
2. Platform Positioning
3. User Roles & Access Control
4. Core Functional Modules
5. Primary Workflow & Lifecycle
6. Wallet / Payment / Billing System
7. Pricing, Fees & Discounts
8. Trust, Safety & Anti-Fraud
9. Compliance & Verification
10. Social & Community Features
11. Notification Architecture
12. Admin Portal
13. Technical Architecture
14. Real-Time Infrastructure
15. Authentication & Security
16. Data Model
17. Onboarding UX
18. Testing Strategy
19. CI/CD & Deployment
20. Regulatory Compliance
21. Build Phases (MVP → Phase 2 → Phase 3)
22. Long-Term Roadmap

---

## SECTION 1 — STRATEGIC FOUNDATION & BRAND PURPOSE

### 1.1 Brand Purpose

Make food delivery affordable by eliminating markup — customers pay the same price as walking into the restaurant.

### 1.2 Product Description

Kain! is a mobile food delivery app that lists food at actual restaurant prices. Unlike GrabFood and Foodpanda, which charge restaurants 25-30% commission (forcing price markups), Kain! charges zero commission on food. Deliveries are outsourced to existing delivery platforms via API, keeping operational costs near zero. Revenue comes from delivery fee margins and a small flat processing fee to restaurants.

### 1.3 Tagline

"Right place for the right price"

### 1.4 Target Audience

| Audience | Description |
|----------|-------------|
| **Customers** | Food delivery users in Metro Manila who are price-sensitive and currently skip delivery orders due to markups |
| **Restaurant Owners** | Restaurants losing online sales because delivery app commissions force them to raise prices |

### 1.5 Non-Negotiables

1. Food must ALWAYS display the actual restaurant price — zero markup, no exceptions
2. Multiple payment methods supported (GCash, Maya, card)
3. Customer support available from day one
4. Order history and receipts for every transaction
5. Real-time delivery tracking (with fallback to status updates if API doesn't support location)
6. Unique code confirmation system for every delivery
7. Restaurant menu must be at least 80% active at all times
8. Digital payments only — no cash for MVP
9. Weekly restaurant payouts with dispute settlement window
10. One restaurant per order (multi-restaurant is future scope)

---

## SECTION 2 — PLATFORM POSITIONING

### 2.1 Positioning Statement

Kain! is the only food delivery app in the Philippines where the price you see is the price you'd pay at the restaurant. We make this possible by outsourcing delivery to existing platforms and running with near-zero operations, passing all savings to the customer.

### 2.2 Competitor Comparison

| Dimension | GrabFood | Foodpanda | Walking to Restaurant | **Kain!** |
|-----------|----------|-----------|----------------------|-----------|
| Food pricing | Marked up 20-30% | Marked up 20-30% | Restaurant price | **Restaurant price** |
| Restaurant commission | 25-30% | 25-30% | None | **None (small processing fee only)** |
| Delivery fleet | Own riders (high opex) | Own riders (high opex) | N/A | **Outsourced via API (near-zero opex)** |
| Convenience | High | High | Low (travel required) | **High** |
| Customer incentive | Convenience only | Convenience only | Price | **Convenience + price** |
| Restaurant margin impact | Erodes margins | Erodes margins | Full margins | **Full margins preserved** |

### 2.3 Target Market

- **Geography:** Metro Manila (13M population)
- **Segment:** Existing food delivery users (~20-25% delivery penetration in metro areas)
- **Sweet spot:** Price-sensitive customers who currently abandon orders due to markup, and restaurants losing online sales to commission-driven price inflation

### 2.4 Key Insight

Delivery apps are operationally heavy — managing riders, onboarding drivers, fleet operations. That overhead forces restaurant commissions, which force markups. New delivery API availability (Grab Express, Lalamove) makes it possible for the first time to run a delivery platform without owning any of that infrastructure.

---

## SECTION 3 — USER ROLES & ACCESS CONTROL

### 3.1 Role Table

| Role | Platform | Access Level | Key Capabilities |
|------|----------|-------------|------------------|
| **Customer** | Mobile app (iOS/Android) | Self-register, immediate access | Browse restaurants, search food, order, pay, track delivery, view order history, rate restaurants, use promo codes |
| **Restaurant Owner** | Web portal | Apply/self-register → admin approval required | Manage menu & pricing, accept/decline orders, pause receiving orders, mark items unavailable, view sales & payouts, manage promo codes |
| **Admin** | Web dashboard | Internal accounts only | Approve restaurants, manage users, monitor orders, handle disputes, view analytics, manage restaurant scoring, system configuration, manual restaurant onboarding |

### 3.2 Multi-Role Architecture

A single person can hold multiple roles (e.g., a restaurant owner who also orders food as a customer). Roles are linked to one account but with separate interfaces and permissions.

### 3.3 Restaurant Owner Rules

- Menu must be at least 80% active at all times
- Items unavailable for 3 consecutive days are auto-removed from the menu
- 3-5 order declines in a single day → restaurant goes offline for the rest of the day and the following day
- Must pass verification (business permits, DTI registration) before going live

---

## SECTION 4 — CORE FUNCTIONAL MODULES

### 4.1 Customer App Modules

| Module | Description |
|--------|-------------|
| **Restaurant Browse** | Fresh, curated display of restaurants with a unique visual approach |
| **Food Search** | Keyword-based search across all restaurants and menu items |
| **Order Placement** | Cart → checkout → payment flow |
| **Payment** | GCash, Maya, card via PayMongo |
| **Real-Time Tracking** | Live rider location on map (via delivery API) with fallback to status updates |
| **Unique Code Confirmation** | System-generated code shown to customer, rider must collect it on delivery |
| **Order History** | Past orders with receipts and reorder capability |
| **Ratings & Reviews** | Rate food and restaurant after delivery |
| **Promo Codes** | Redeem restaurant-issued discount codes |
| **Customer Support** | In-app support channel for disputes and issues |

### 4.2 Restaurant Portal Modules

| Module | Description |
|--------|-------------|
| **Menu Management** | Add/edit/remove items, set prices (must match walk-in price), mark items unavailable |
| **Order Management** | View incoming orders, accept/decline, order status tracking |
| **Availability Control** | Pause receiving orders, set operating hours |
| **Sales Dashboard** | View order history, revenue, payout schedule |
| **Payout Management** | View weekly payout details, deductions, processing fees |
| **Promo Code Management** | Create and manage discount codes for customers |

### 4.3 Admin Dashboard Modules

| Module | Description |
|--------|-------------|
| **Restaurant Approvals** | Review applications, verify documents, approve/reject |
| **User Management** | View, suspend, manage customer and restaurant accounts |
| **Order Monitoring** | Real-time order feed, status tracking, intervention capability |
| **Dispute Resolution** | Handle refund requests, investigate delivery issues, process resolutions |
| **Analytics & Reporting** | Order volumes, revenue, restaurant performance, user growth |
| **Restaurant Scoring** | Manage scoring system, fee waiver eligibility |
| **System Configuration** | Platform settings, fee structure, delivery API management |
| **Manual Onboarding** | Directly add restaurants during campaigns |

---

## SECTION 5 — PRIMARY WORKFLOW & LIFECYCLE

### 5.1 Primary Workflow: Customer Orders Food

**Trigger:** Customer is hungry and opens Kain!

| Step | Actor | Action | On Failure |
|------|-------|--------|------------|
| 1 | Customer | Opens app, browses restaurants or searches for food by keyword | — |
| 2 | Customer | Selects items from ONE restaurant, adds to cart | — |
| 3 | Customer | Reviews cart, applies promo code (optional), proceeds to checkout | — |
| 4 | Customer | Confirms delivery address | Invalid address → prompt to correct |
| 5 | System | Sends order to restaurant | System error → notify customer, retry |
| 6 | Restaurant | Receives notification (push + sound), reviews order | — |
| 7a | Restaurant | **Accepts order** → proceed to step 8 | — |
| 7b | Restaurant | **Declines order** → customer notified with suggestions. Decline counter incremented. 3-5 declines/day → restaurant auto-offline for rest of day + next day | — |
| 8 | System | Charges customer via PayMongo (GCash/Maya/card) | Payment fails → notify customer, order cancelled |
| 9 | System | Generates unique delivery confirmation code | — |
| 10 | Customer | Receives confirmation with unique code | — |
| 11 | System | Books rider via outsourced delivery API (Grab Express/Lalamove). Unique code placed in delivery notes field | No rider available → notify customer with wait time. After wait time: option to cancel (full refund) or wait more |
| 12 | Restaurant | Prepares food | — |
| 13 | Rider | Arrives at restaurant, picks up food | Rider cancels → system re-books via API |
| 14 | Customer | Sees real-time rider tracking on map | If tracking unavailable → status updates: "Picked up", "On the way", "Nearby" |
| 15 | Rider | Arrives at customer location, asks for unique code | — |
| 16 | Customer | Provides unique code to rider, receives food | Code mismatch → do not hand over food, flag for support |
| 17 | System | Marks order as delivered | — |
| 18 | Customer | Rates food/restaurant | Optional — can skip |

### 5.2 Cancellation Policy

- Customer can cancel any time before a rider is booked (Step 11)
- After rider is booked → cancellation may not be possible (subject to refinement with data)
- Restaurant declines → automatic cancellation, no charge to customer

### 5.3 Background Jobs

| Job | Trigger | Action |
|-----|---------|--------|
| Decline counter reset | Daily at midnight | Reset all restaurant decline counters |
| Auto-offline enforcement | 3-5 declines in a day | Take restaurant offline, schedule re-activation for day after next |
| Menu item auto-removal | Item unavailable for 3 consecutive days | Remove item from active menu, notify restaurant owner |
| Menu completeness check | Item removed or marked unavailable | Verify restaurant still has 80% of menu active, warn if below threshold |
| Stale order cleanup | Order pending restaurant response > X minutes | Cancel order, notify customer, no charge |
| Weekly payout processing | Every Sunday/Monday | Calculate restaurant earnings minus deductions, initiate payout |

### 5.4 Secondary Workflows

- **Dispute/Refund flow:** Customer reports issue → admin reviews → refund issued or denied based on unique code evidence
- **Rating flow:** Post-delivery → customer rates restaurant (1-5 stars + optional comment)
- **Restaurant scoring update:** After each order → update restaurant score based on acceptance rate, order accuracy, ratings

---

## SECTION 6 — WALLET / PAYMENT / BILLING SYSTEM

### 6.1 Payment Architecture

- **No customer wallet for MVP** — direct payment per transaction to avoid BSP e-money regulations
- **Payment processor:** PayMongo (Philippine-focused, supports GCash, Maya, card)
- **Payment captured only after restaurant accepts order** — no pre-authorization

### 6.2 Payment Flow

1. Customer places order → order sent to restaurant (no charge yet)
2. Restaurant accepts → PayMongo charges customer
3. Funds held by Kain!
4. Weekly payout to restaurant (minus processing fee and any dispute deductions)

### 6.3 Supported Payment Methods

| Method | Provider | Notes |
|--------|----------|-------|
| GCash | Via PayMongo | Most popular Philippine e-wallet |
| Maya | Via PayMongo | Second largest e-wallet |
| Credit/Debit Card | Via PayMongo | Visa, Mastercard |

### 6.4 Restaurant Payouts

- **Frequency:** Weekly
- **Settlement window:** 7 days (allows time for dispute resolution)
- **Payout methods:** Bank transfer or GCash/Maya
- **Deductions:** Processing fees, refund chargebacks for restaurant-fault issues

---

## SECTION 7 — PRICING, FEES & DISCOUNTS

### 7.1 Pricing Model

| Fee Type | Paid By | Amount | Notes |
|----------|---------|--------|-------|
| Food price markup | — | ₱0 | Non-negotiable: food is always at restaurant price |
| Delivery fee | Customer | Variable (includes margin) | Based on distance/demand. Includes spread above outsourced delivery cost |
| Processing fee | Restaurant | Small flat fee per order | Deducted from weekly payout |
| Priority fee (tip) | Customer (optional) | Customer-defined amount | During peak hours to attract riders faster |

### 7.2 Restaurant Fee Waiver Program

- Restaurant scoring system based on: acceptance rate, order accuracy, ratings, menu completeness
- High-scoring restaurants get processing fee waived
- Incentivizes quality and reliability without raising food prices

### 7.3 Promo Codes

- Restaurant-issued only (Kain! does not subsidize food discounts)
- Restaurants create codes via their portal
- Applied at checkout by customer
- Discount deducted from restaurant's payout, not from Kain! revenue

---

## SECTION 8 — TRUST, SAFETY & ANTI-FRAUD

### 8.1 Fraud Prevention

| Threat | Prevention |
|--------|-----------|
| Fake restaurants | Verification process: business permits, DTI registration, admin approval required |
| False non-delivery claims | Unique code confirmation system — code entered = delivery confirmed = no refund |
| Ordering abuse | Rate limiting (max orders per account per hour), unusual pattern flagging |
| Fake accounts | Phone verification (OTP) required on signup |
| Duplicate transactions | Idempotency keys on all payment requests |

### 8.2 Dispute Resolution

| Scenario | Resolution | Cost Bearer |
|----------|-----------|-------------|
| Food not delivered (rider fault) | Refund customer immediately, recover from delivery platform via their dispute process | Delivery platform |
| Wrong order (restaurant fault) | Refund customer, deduct from restaurant's next weekly payout | Restaurant |
| Customer falsely claims non-delivery | Unique code was confirmed → no refund. Case closed | No cost |
| Food quality issue | Escalate to admin review, case-by-case resolution | Case dependent |

### 8.3 Dispute Buffer Fund

Small percentage of revenue set aside as a dispute/refund pool to ensure refunds don't impact cash flow.

### 8.4 Restaurant Discipline

- Decline counter: 3-5 declines per day → auto-offline for rest of day + next day
- Repeated offenses → admin review, potential suspension
- Menu items unavailable 3 consecutive days → auto-removed
- Menu must remain 80% active

---

## SECTION 9 — COMPLIANCE & VERIFICATION

### 9.1 Restaurant Verification

| Requirement | Purpose |
|-------------|---------|
| Valid business permit | Proves legitimate operation |
| DTI/SEC registration | Confirms legal business entity |
| Valid government ID of owner | Identity verification |
| Physical address verification | Confirms restaurant exists |

### 9.2 Customer Verification

- Phone number verification via OTP (required)
- Email verification (required)
- No KYC beyond this for MVP (no wallet = no e-money regulations)

### 9.3 Regulatory Requirements

| Regulation | Applicability | Status |
|-----------|---------------|--------|
| Data Privacy Act (RA 10173) | All user data handling | Must comply — NPC registration required |
| DTI Business Registration | Kain! as a business | Required before launch |
| BIR Tax Compliance | Revenue, receipts | Required — proper invoicing and tax filing |
| BSP E-Money Regulations | Only if wallet is implemented | **Not applicable for MVP** (no wallet) |
| Consumer Act (RA 7394) | Customer protection, refunds | Must comply — clear refund policy required |

### 9.4 Audit Trail

- All orders logged with full lifecycle timestamps
- All payment transactions logged with PayMongo reference IDs
- All dispute actions logged with admin ID and resolution
- All restaurant approval/rejection actions logged
- Logs retained per Data Privacy Act requirements

---

## SECTION 10 — SOCIAL & COMMUNITY FEATURES

Not applicable for MVP. No social features, group ordering, or customer-to-customer interactions planned for initial release.

**Future consideration:** Sharing favorite restaurants, referral programs, group ordering.

---

## SECTION 11 — NOTIFICATION ARCHITECTURE

### 11.1 Customer Notifications

| Event | Channel | Urgency |
|-------|---------|---------|
| Order received by restaurant | Push + In-app | Normal |
| Restaurant accepted order (code generated) | Push + In-app | High |
| Restaurant declined order | Push + In-app | High |
| Rider booked / on the way to restaurant | Push + In-app | Normal |
| Rider picked up food | Push + In-app | Normal |
| Rider arriving / nearby | Push + In-app | High |
| Delivery complete | Push + In-app | Normal |
| Refund issued | Push + In-app + Email | Normal |
| Promo code available | Push | Low |

### 11.2 Restaurant Notifications

| Event | Channel | Urgency |
|-------|---------|---------|
| New order received | Push + Sound + In-portal | Critical |
| Order cancelled by customer | Push + In-portal | High |
| Weekly payout processed | Push + Email | Normal |
| Decline counter warning (approaching limit) | Push + In-portal | High |
| Auto-offline triggered | Push + Email + In-portal | Critical |
| Menu item auto-removed (3-day rule) | Push + In-portal | Normal |
| Menu completeness below 80% | Push + In-portal | High |

### 11.3 Admin Alerts

| Event | Channel | Urgency |
|-------|---------|---------|
| New restaurant application | In-dashboard + Email | Normal |
| Dispute filed | In-dashboard | High |
| Restaurant auto-offlined | In-dashboard | Normal |
| Unusual activity flagged | In-dashboard + Email | High |

### 11.4 Delivery Stack

| Channel | Provider |
|---------|----------|
| Push notifications | Firebase Cloud Messaging (FCM) |
| SMS (OTP only) | Semaphore |
| Email | SendGrid or Resend |
| In-app / In-portal | WebSocket (real-time) |

---

## SECTION 12 — ADMIN PORTAL

### 12.1 Dashboard Modules

GrabFood-style admin dashboard with the following modules:

| Module | Key Features |
|--------|-------------|
| **Overview** | Real-time order count, revenue today/week/month, active restaurants, active users |
| **Restaurant Management** | Applications queue, approved list, suspended list, scoring overview, manual onboarding |
| **User Management** | Customer list, search, suspend/unsuspend, order history per user |
| **Order Monitoring** | Live order feed, status filters, intervention tools (cancel, reassign) |
| **Dispute Center** | Open disputes, evidence review (unique code status), resolution actions, refund processing |
| **Analytics** | Order volumes, revenue trends, restaurant performance, user growth, delivery API performance |
| **Restaurant Scoring** | Score breakdown per restaurant, fee waiver status, scoring criteria management |
| **Payouts** | Weekly payout batches, individual restaurant payout details, deduction logs |
| **Configuration** | Platform fees, delivery API settings, notification templates, system parameters |
| **Audit Log** | Searchable log of all admin actions, system events, dispute resolutions |

---

## SECTION 13 — TECHNICAL ARCHITECTURE

### 13.1 Recommended Tech Stack

| Layer | Technology | Justification |
|-------|-----------|---------------|
| **Mobile App** | React Native | Single codebase for iOS & Android. Large PH talent pool. Shared JavaScript ecosystem with backend. |
| **Restaurant Portal** | React (Web) | Consistent with React Native knowledge. Fast to build. Responsive for desktop use. |
| **Admin Dashboard** | React (Web) | Same tooling as restaurant portal. Consistent developer experience. |
| **Backend** | Node.js with NestJS | Structured, scalable framework. TypeScript across entire stack. Good for growing team. |
| **Database** | PostgreSQL | Robust relational database. Handles complex queries for orders, payments, scoring. Free tier available. |
| **Real-Time** | Socket.io | Rider tracking, order status updates, restaurant order alerts. Integrates naturally with Node.js. |
| **Auth** | Firebase Auth | Phone OTP, Google sign-in, email/password. Generous free tier. Battle-tested. |
| **Payments** | PayMongo | Philippine-focused. GCash, Maya, card support. Good API documentation. |
| **File Storage** | Cloudinary | Restaurant photos, menu images. Free tier for MVP. Image optimization built-in. |
| **Hosting** | Railway | Simple deployment for MVP. Easy scaling. Migrate to AWS when needed. |
| **Push Notifications** | Firebase Cloud Messaging (FCM) | Free. iOS and Android support. Reliable. |
| **SMS** | Semaphore | Philippine SMS provider. Affordable OTP delivery. |
| **Email** | SendGrid or Resend | Transactional emails (receipts, payouts, alerts). Free tier available. |
| **Delivery APIs** | Grab Express / Lalamove / Transportify | Multiple providers from day one. No single dependency. |

### 13.2 Architecture Pattern

- **Monolithic backend** for MVP — single deployable Node.js/NestJS application
- Split into microservices only when scaling demands it (likely after 10K+ daily orders)
- **REST API** for all standard operations
- **WebSocket** exclusively for real-time tracking and order status updates
- **Background job queue** (Bull/BullMQ with Redis) for: payout processing, decline counter resets, menu cleanup, stale order handling

### 13.3 Suggested Project Structure

```
kain/
├── mobile/                  # React Native customer app
│   ├── src/
│   │   ├── screens/
│   │   ├── components/
│   │   ├── services/        # API calls
│   │   ├── store/           # State management
│   │   ├── i18n/            # Translations
│   │   └── utils/
│   └── ...
├── web-restaurant/          # React restaurant portal
│   ├── src/
│   │   ├── pages/
│   │   ├── components/
│   │   └── services/
│   └── ...
├── web-admin/               # React admin dashboard
│   ├── src/
│   │   ├── pages/
│   │   ├── components/
│   │   └── services/
│   └── ...
├── backend/                 # NestJS API server
│   ├── src/
│   │   ├── modules/
│   │   │   ├── auth/
│   │   │   ├── users/
│   │   │   ├── restaurants/
│   │   │   ├── menu/
│   │   │   ├── orders/
│   │   │   ├── payments/
│   │   │   ├── delivery/
│   │   │   ├── disputes/
│   │   │   ├── notifications/
│   │   │   ├── scoring/
│   │   │   └── admin/
│   │   ├── common/
│   │   ├── config/
│   │   └── jobs/            # Background workers
│   └── ...
└── shared/                  # Shared types, constants
```

---

## SECTION 14 — REAL-TIME INFRASTRUCTURE

### 14.1 Real-Time Requirements

| Feature | Protocol | Source |
|---------|----------|--------|
| Rider location tracking | WebSocket (Socket.io) | Polled from delivery API → pushed to customer app |
| Order status updates | WebSocket (Socket.io) | Backend events → pushed to customer app and restaurant portal |
| New order alert for restaurant | WebSocket (Socket.io) + Push | Backend → restaurant portal (real-time) + FCM (if portal closed) |
| Admin live order feed | WebSocket (Socket.io) | Backend → admin dashboard |

### 14.2 Tracking Architecture

1. Backend polls outsourced delivery API for rider location at regular intervals (every 5-10 seconds)
2. Location data pushed to customer app via Socket.io
3. Customer sees rider position on map in real-time
4. If delivery API doesn't support location: fall back to status-only updates (Picked Up → On The Way → Nearby → Delivered)

### 14.3 Connection Management

- Auto-reconnect on connection drop
- Graceful degradation on slow networks (reduce update frequency)
- Connection only active during active order tracking (not always-on)

---

## SECTION 15 — AUTHENTICATION & SECURITY

### 15.1 Authentication Methods

| Method | Provider | Use Case |
|--------|----------|----------|
| Phone OTP | Firebase Auth + Semaphore | Primary signup/login for customers. Required for all accounts. |
| Google Sign-In | Firebase Auth | Quick login option for customers |
| Email/Password | Firebase Auth | Alternative login, required for restaurant owners |

### 15.2 Role-Based Access

| Role | Access |
|------|--------|
| Customer | Mobile app only. Own orders, own profile, own history. |
| Restaurant Owner | Restaurant portal. Own restaurant data, own orders, own payouts. |
| Admin | Admin dashboard. All data, all actions, system configuration. |

### 15.3 Security Hardening

| Measure | Implementation |
|---------|---------------|
| HTTPS | All communications encrypted via TLS |
| Rate limiting | Per-endpoint limits on API calls. Stricter on auth endpoints. |
| Input validation | Server-side validation on all inputs. Sanitize all user-provided text. |
| Session management | JWT with refresh tokens. Short-lived access tokens (15 min). Refresh tokens rotated on use. |
| Idempotency | Idempotency keys on all payment and order creation requests |
| SQL injection prevention | Parameterized queries via ORM (TypeORM/Prisma) |
| XSS prevention | React's built-in escaping + Content Security Policy headers |
| CORS | Whitelist only Kain! domains |
| API keys | Delivery API keys and PayMongo keys stored in environment variables, never in code |
| Account lockout | Temporary lockout after 5 failed login attempts |

---

## SECTION 16 — DATA MODEL

### 16.1 Core Entities

#### User
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| phone | String | Required, unique, verified via OTP |
| email | String | Optional for customers, required for restaurant owners |
| name | String | Display name |
| roles | Array | [customer, restaurant_owner, admin] — multi-role supported |
| avatar_url | String | Profile photo |
| status | Enum | active, suspended |
| created_at | Timestamp | |
| updated_at | Timestamp | |

#### Restaurant
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| owner_id | UUID | FK → User |
| name | String | Restaurant name |
| description | String | |
| address | String | Physical address |
| latitude | Decimal | For distance calculations |
| longitude | Decimal | |
| phone | String | Contact number |
| logo_url | String | |
| cover_image_url | String | |
| business_permit_url | String | Verification document |
| dti_registration_url | String | Verification document |
| status | Enum | pending_approval, approved, suspended, offline |
| is_paused | Boolean | Restaurant manually paused orders |
| decline_count_today | Integer | Resets daily at midnight |
| offline_until | Timestamp | If auto-offlined due to declines |
| score | Decimal | Restaurant quality score |
| processing_fee_waived | Boolean | Based on score |
| operating_hours | JSON | Open/close times per day |
| created_at | Timestamp | |
| updated_at | Timestamp | |

#### MenuItem
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| restaurant_id | UUID | FK → Restaurant |
| name | String | Item name |
| description | String | |
| price | Decimal | Must match walk-in restaurant price |
| image_url | String | |
| category | String | e.g., "Main", "Drinks", "Dessert" |
| is_available | Boolean | Can be toggled by restaurant |
| unavailable_since | Timestamp | Tracks consecutive unavailability for 3-day auto-removal |
| is_removed | Boolean | Auto-removed after 3 consecutive days unavailable |
| created_at | Timestamp | |
| updated_at | Timestamp | |

#### Order
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| customer_id | UUID | FK → User |
| restaurant_id | UUID | FK → Restaurant |
| status | Enum | pending_restaurant, accepted, declined, payment_processing, payment_failed, preparing, rider_booked, rider_picking_up, rider_delivering, delivered, cancelled, disputed |
| delivery_address | String | |
| delivery_latitude | Decimal | |
| delivery_longitude | Decimal | |
| unique_code | String | 6-digit code for delivery confirmation |
| subtotal | Decimal | Sum of item prices |
| delivery_fee | Decimal | Charged to customer |
| priority_fee | Decimal | Optional tip/peak hour fee |
| promo_discount | Decimal | If promo code applied |
| total | Decimal | subtotal + delivery_fee + priority_fee - promo_discount |
| promo_code_id | UUID | FK → PromoCode (nullable) |
| payment_id | UUID | FK → Payment |
| delivery_id | UUID | FK → Delivery |
| cancelled_by | Enum | customer, restaurant, system (nullable) |
| cancellation_reason | String | (nullable) |
| rated | Boolean | Whether customer has rated |
| created_at | Timestamp | |
| updated_at | Timestamp | |

#### OrderItem
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| order_id | UUID | FK → Order |
| menu_item_id | UUID | FK → MenuItem |
| item_name | String | Snapshot at time of order |
| item_price | Decimal | Snapshot at time of order |
| quantity | Integer | |
| special_instructions | String | Customer notes for this item |

#### Payment
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| order_id | UUID | FK → Order |
| paymongo_payment_id | String | PayMongo reference |
| method | Enum | gcash, maya, card |
| amount | Decimal | Total charged |
| status | Enum | pending, paid, refunded, partially_refunded, failed |
| refund_amount | Decimal | If refunded (nullable) |
| refund_reason | String | (nullable) |
| idempotency_key | String | Unique per payment attempt |
| created_at | Timestamp | |
| updated_at | Timestamp | |

#### Delivery
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| order_id | UUID | FK → Order |
| provider | Enum | grab_express, lalamove, transportify |
| provider_booking_id | String | External reference ID |
| rider_name | String | From delivery API (nullable) |
| rider_phone | String | From delivery API (nullable) |
| rider_latitude | Decimal | Real-time location (nullable) |
| rider_longitude | Decimal | Real-time location (nullable) |
| status | Enum | booking, booked, picking_up, delivering, delivered, cancelled, no_rider |
| estimated_pickup_time | Timestamp | |
| estimated_delivery_time | Timestamp | |
| actual_delivery_time | Timestamp | (nullable) |
| delivery_cost | Decimal | Actual cost paid to provider |
| unique_code_confirmed | Boolean | Rider collected the code |
| created_at | Timestamp | |
| updated_at | Timestamp | |

#### Dispute
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| order_id | UUID | FK → Order |
| filed_by | UUID | FK → User |
| type | Enum | non_delivery, wrong_order, food_quality, other |
| description | String | Customer's complaint |
| evidence | JSON | Unique code status, delivery status, timestamps |
| status | Enum | open, investigating, resolved, denied |
| resolution | String | Admin resolution notes (nullable) |
| refund_issued | Boolean | |
| refund_amount | Decimal | (nullable) |
| resolved_by | UUID | FK → User (admin) (nullable) |
| created_at | Timestamp | |
| resolved_at | Timestamp | (nullable) |

#### RestaurantPayout
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| restaurant_id | UUID | FK → Restaurant |
| period_start | Date | Payout period start |
| period_end | Date | Payout period end |
| gross_amount | Decimal | Total order revenue |
| processing_fees | Decimal | Total fees deducted |
| dispute_deductions | Decimal | Refunds charged back to restaurant |
| net_amount | Decimal | Amount paid out |
| payout_method | Enum | bank_transfer, gcash, maya |
| payout_reference | String | Transaction reference |
| status | Enum | pending, processing, completed, failed |
| created_at | Timestamp | |
| processed_at | Timestamp | (nullable) |

#### Rating
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| order_id | UUID | FK → Order |
| customer_id | UUID | FK → User |
| restaurant_id | UUID | FK → Restaurant |
| stars | Integer | 1-5 |
| comment | String | Optional review text |
| created_at | Timestamp | |

#### PromoCode
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| restaurant_id | UUID | FK → Restaurant |
| code | String | Unique code string |
| discount_type | Enum | fixed_amount, percentage |
| discount_value | Decimal | Amount or percentage |
| max_discount | Decimal | Cap for percentage discounts (nullable) |
| min_order_amount | Decimal | Minimum order to apply (nullable) |
| usage_limit | Integer | Max total redemptions (nullable) |
| usage_count | Integer | Current redemptions |
| valid_from | Timestamp | |
| valid_until | Timestamp | |
| is_active | Boolean | |
| created_at | Timestamp | |

#### RestaurantScore
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| restaurant_id | UUID | FK → Restaurant |
| acceptance_rate | Decimal | % of orders accepted |
| average_rating | Decimal | Average customer rating |
| menu_completeness | Decimal | % of menu items active |
| total_orders | Integer | Lifetime order count |
| overall_score | Decimal | Weighted composite score |
| fee_waiver_eligible | Boolean | Based on score threshold |
| last_calculated | Timestamp | |

#### Notification
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| recipient_id | UUID | FK → User |
| type | Enum | order_update, payment, payout, system, promo |
| title | String | |
| body | String | |
| channel | Enum | push, email, sms, in_app |
| read | Boolean | For in-app notifications |
| data | JSON | Additional context (order_id, etc.) |
| created_at | Timestamp | |

#### AuditLog
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| actor_id | UUID | FK → User (who performed action) |
| action | String | e.g., "restaurant_approved", "dispute_resolved", "refund_issued" |
| target_type | String | e.g., "restaurant", "order", "user" |
| target_id | UUID | ID of affected entity |
| details | JSON | Additional context |
| created_at | Timestamp | |

---

## SECTION 17 — ONBOARDING UX

### 17.1 Customer Onboarding

| Step | Screen | Action |
|------|--------|--------|
| 1 | Welcome | App intro — "Right place for the right price" |
| 2 | Sign Up | Phone number input → OTP verification. Or Google sign-in. |
| 3 | Profile | Name, email (optional), delivery address |
| 4 | Browse | Land on restaurant listing — immediately see food at restaurant prices |

**Aha moment:** Seeing familiar restaurant food at the exact walk-in price. This should happen within 30 seconds of opening the app.

### 17.2 Restaurant Owner Onboarding

| Step | Screen | Action |
|------|--------|--------|
| 1 | Apply | Business name, owner name, contact details |
| 2 | Verify | Upload business permit, DTI registration, government ID |
| 3 | Wait | Application reviewed by admin (target: 24-48 hours) |
| 4 | Approved | Email/SMS notification with portal access |
| 5 | Menu Setup | Add menu items with photos, prices (must match walk-in prices), categories |
| 6 | Go Live | Confirm operating hours, activate restaurant |

### 17.3 Design System Preferences

- Clean, food-focused UI — large food images, minimal text
- Fresh visual approach to restaurant display (differentiate from GrabFood's standard grid)
- Brand colors and visual identity: TBD
- Filipino + English language support from day one via i18n

---

## SECTION 18 — TESTING STRATEGY

### 18.1 Testing Layers

| Layer | Scope | Tools |
|-------|-------|-------|
| **Unit Tests** | Business logic: order flow, payment processing, scoring calculations, fee computation, decline counter logic | Jest |
| **Integration Tests** | API endpoints, database operations, PayMongo integration, delivery API integration | Jest + Supertest |
| **End-to-End Simulation** | Full order lifecycle: browse → order → pay → accept → deliver → confirm → rate | Detox (mobile) or Cypress (web) |
| **API Contract Tests** | Delivery API response handling, PayMongo webhook processing | Jest |

### 18.2 Critical Test Scenarios

1. Complete happy path: order placed → restaurant accepts → payment charged → rider booked → delivered → code confirmed
2. Restaurant declines → customer notified → no charge
3. Payment fails → order cancelled → customer notified
4. No rider available → customer notified → wait → cancel → full refund
5. Decline counter reaches limit → restaurant auto-offlined
6. Menu item unavailable 3 days → auto-removed
7. Dispute filed → unique code evidence checked → resolution
8. Weekly payout calculation with fee deductions and dispute chargebacks
9. Concurrent orders to same restaurant
10. Delivery API timeout / failure → graceful fallback

### 18.3 Pre-Launch Simulation

Full simulation of order lifecycle with mock delivery API responses before connecting to live delivery platforms. Covers:
- Normal flow
- All failure scenarios
- Load testing with simulated concurrent users
- Payment flow with PayMongo test mode

---

## SECTION 19 — CI/CD & DEPLOYMENT

### 19.1 Pipeline

| Stage | Trigger | Action |
|-------|---------|--------|
| **Lint & Type Check** | Every push | ESLint + TypeScript compiler |
| **Unit Tests** | Every push | Jest test suite |
| **Integration Tests** | Every push | Jest + test database |
| **Build** | Tests pass | Build all apps (mobile, web-restaurant, web-admin, backend) |
| **Deploy to Staging** | Merge to develop | Auto-deploy to staging environment |
| **Deploy to Production** | Manual promotion | Deploy to production after staging verification |

### 19.2 Environment Profiles

| Environment | Purpose | Database | Delivery API | Payments |
|-------------|---------|----------|-------------|----------|
| **Local** | Development | Local PostgreSQL | Mock API | PayMongo test mode |
| **Staging** | Pre-production testing | Staging PostgreSQL | Sandbox/test API | PayMongo test mode |
| **Production** | Live | Production PostgreSQL | Live API | PayMongo live mode |

### 19.3 Deployment

- **Backend:** Railway (MVP) → AWS ECS (scale)
- **Web apps:** Vercel or Railway
- **Mobile:** App Store (iOS) + Google Play Store (Android)
- **Database:** Railway PostgreSQL (MVP) → AWS RDS (scale)
- **Redis:** Railway Redis (MVP) → AWS ElastiCache (scale)

---

## SECTION 20 — REGULATORY COMPLIANCE

### 20.1 Pre-Launch Checklist

| Requirement | Status | Notes |
|-------------|--------|-------|
| DTI Business Registration | Required | Register "Kain!" as business name |
| BIR Registration | Required | Tax identification, official receipts |
| SEC Registration | If incorporating | Required for corporate entity |
| NPC Registration | Required | Data Privacy Act compliance for user data |
| Terms of Service | Required | Legal agreement for customers and restaurants |
| Privacy Policy | Required | Data collection, usage, retention policies |
| Refund Policy | Required | Clear policy aligned with Consumer Act |
| Restaurant Partner Agreement | Required | Terms for processing fees, payouts, quality standards |
| PayMongo Merchant Account | Required | KYC for payment processing |
| Delivery API Agreements | Required | Terms of service compliance for Grab Express / Lalamove APIs |

### 20.2 Ongoing Compliance

- BIR tax filing (monthly/quarterly)
- Data Privacy Act compliance (annual NPC registration, breach notification procedures)
- Consumer Act compliance (refund processing, fair practices)
- Monitor delivery API terms of service for changes

---

## SECTION 21 — BUILD PHASES (MVP → Phase 2 → Phase 3)

### Phase 1 — MVP

**Goal:** Launch core ordering flow in Metro Manila. Prove that zero-markup pricing drives order volume.

| Module | Scope |
|--------|-------|
| Customer App | Browse, search, order from one restaurant, pay (GCash/Maya/card), real-time tracking, unique code confirmation, order history, ratings, promo codes, customer support |
| Restaurant Portal | Register/apply, menu management (80% rule, 3-day auto-removal), accept/decline orders, pause orders, view sales, weekly payouts, promo code management |
| Admin Dashboard | Restaurant approvals, user management, order monitoring, dispute resolution, analytics, restaurant scoring, payout management, configuration, audit logs |
| Backend | Full order lifecycle, payment processing, delivery API integration (multiple providers), notification system, background jobs, scoring engine |
| Infrastructure | CI/CD pipeline, staging + production environments, monitoring, automated tests |
| i18n | English + Filipino |

### Phase 2 — Growth Features

**Goal:** Increase retention and order frequency. Improve personalization.

| Feature | Description |
|---------|-------------|
| Suggested Orders | Personalized recommendations based on order history |
| Scheduled Orders | Order now, deliver at a specified time |
| Premium Subscription | Monthly plan for discounted/free delivery |
| Advanced Restaurant Analytics | Deeper sales insights, peak hours, popular items |
| Native Dialect Support | Additional Philippine language options |

### Phase 3 — Expansion & Diversification

**Goal:** Scale beyond Metro Manila. Expand product offering.

| Feature | Description |
|---------|-------------|
| Geographic Expansion | Cebu, Davao, and other metro areas based on delivery API availability and user data |
| Non-Restaurant Food Items | Specialty foods, groceries, home-cooked meals |
| Multi-Restaurant Orders | Order from multiple restaurants in one transaction |
| Customer Wallet | In-app balance (requires BSP compliance work) |
| Additional Delivery APIs | New delivery partners as they become available |
| Restaurant Promotion Tools | Paid visibility, featured listings, promotional placements |
| Cash Payment Option | If demand and operational model support it |

---

## SECTION 22 — LONG-TERM ROADMAP

| Milestone | Timeline | Target |
|-----------|----------|--------|
| MVP Launch (Metro Manila) | Phase 1 | Live app with restaurants, core ordering flow, payments, tracking |
| Operational Profitability | Month 12 | Revenue exceeds operating costs |
| Revenue Doubling | Month 18 | 2x revenue from Month 12 baseline |
| Geographic Expansion | Year 2 | 2-3 additional Philippine cities |
| Product Diversification | Year 2-3 | Non-restaurant food items, premium subscriptions |
| Market Leadership | Year 3-5 | Kain! on every Filipino's phone as the affordable delivery platform |
| Category Expansion | Year 3+ | Apply zero-markup model to other daily services beyond food |

---

## CONSUMPTION GUIDE — FOR BUILDING AGENTS

When an AI agent receives this Product Blueprint for implementation:

1. **Start with Section 5** (Primary Workflow) — this is the product's core. Build this first.
2. **Section 16** (Data Model) defines your schema. Implement before any routes.
3. **Section 13** (Technical Architecture) dictates stack choices. Don't deviate without justification.
4. **Section 3** (Roles) + **Section 15** (Auth) define the auth system. Implement early — everything depends on it.
5. **Section 21** (Build Phases) defines what's MVP. Build ONLY MVP features first. Defer everything else.
6. **Sections 1-2** (Vision) are for product decisions when the spec is ambiguous. When in doubt, re-read the non-negotiables.
7. **Section 8** (Trust/Safety) and **Section 9** (Compliance) are often skipped by builders. Don't skip them — they're in the spec for a reason.

---

*KAIN! — BUILD SCOPE v1.0 — CONFIDENTIAL*
*Generated March 2026*
