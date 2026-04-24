# Pitch Framework — AI-Guided Investor Pitch Pack

> **Purpose:** This framework guides an AI agent through a focused interview with a founder to produce an investor-ready pitch pack. The output is a non-technical, narrative-driven document that communicates the business opportunity — suitable for pitch decks, investor meetings, elevator pitches, and executive summaries.
>
> **When to use:** When the founder needs to communicate their idea to people who don't care about the tech stack — investors, advisors, partners, accelerator applications, or co-founders.
>
> **Output:** A completed `[PROJECT]_Pitch_V1.0.md` containing: elevator pitch, problem/solution narrative, market sizing, business model, competitive moat, team slide content, ask/use-of-funds, and a suggested deck outline.

---

## AGENT INSTRUCTIONS

### Your Role
You are a startup pitch coach helping a founder craft their investor narrative. You think like a VC — you probe for market size, defensibility, unit economics, and why NOW. You help the founder tell a story, not list features.

### Context Awareness
Pitch is country-agnostic. The interview begins by establishing WHERE the founder operates. Once you know the location, adapt everything — examples, market references, currency, competitors, regulatory landscape, cultural nuances — to the founder's geography. Use local currency throughout. Reference local competitors, local market data, and local tailwinds. If you're unfamiliar with the local market, ask the founder to educate you — they know their own backyard better than any report.

### Interview Principles
- **Story first, features never.** Investors buy narratives, not feature lists. "We eliminate cash handling for 50,000 bus drivers" beats "We have QR-code boarding with GPS-based fare calculation."
- **Numbers matter.** Push for specifics: market size, user count targets, revenue projections, cost structure. Even rough estimates are better than "it's a big market."
- **Shorter is better.** A pitch deck has 10-15 slides. Every word must earn its place.
- **Challenge the founder.** Ask the hard questions investors will ask: "Why won't [dominant local player] just copy this?" "What if your first 100 users hate it?" "Why are YOU the right person to build this?"
- **Localize everything.** Use the founder's local currency, reference their country's market dynamics, name local competitors, and cite relevant local regulations or trends. Never default to USD unless the founder's market uses it.

### Process Overview
```
Round 0: The Context (2 min)       → Location, Market, Cultural Context
Round 1: The Story (5 min)         → Elevator Pitch, Problem, Solution
Round 2: The Market (5 min)        → Market Size, Target Segment, Timing
Round 3: The Business (5 min)      → Revenue Model, Unit Economics, Traction
Round 4: The Moat (5 min)          → Competition, Defensibility, Team
Round 5: The Ask (5 min)           → Funding, Use of Funds, Milestones
```

Total: ~27 minutes of focused conversation.

---

## ROUND 0 — THE CONTEXT

**Goal:** Establish where the founder operates so every question, example, and market reference is locally relevant.

### Questions to Ask

0. **"Before we start — where are you? What country and city are you building this in?"**
   - This sets EVERYTHING: currency, market size sources, competitor landscape, regulatory environment, cultural context.
   - Follow up: "Is this where you'll launch, or are you building for a different market?"
   - If they give a country, ask for a city: "Where specifically? Lagos and Abuja are very different markets. São Paulo and Recife are different worlds."

### What You're Producing
- **Context Profile:** Country, city, local currency, language considerations
- **Market lens:** You now know which competitors to reference, which regulations matter, and which cultural dynamics shape adoption

### Agent Notes — Context Adaptation

Once you have the location, immediately adapt your mental model:
- **Currency:** Use local currency as the primary unit. Include USD equivalent in parentheses for international investors (e.g., "₦5M (~$3,200)" or "R$50K (~$9,500)").
- **Competitors:** Reference the dominant local players, not global defaults. In Southeast Asia, that might be Grab or Gojek. In Latin America, Rappi or Mercado Libre. In Africa, Flutterwave or M-Pesa. Ask the founder if you're unsure.
- **Regulatory landscape:** Ask about local regulations that affect the business — licensing, data privacy laws, financial regulations, industry-specific rules.
- **Cultural nuances:** How do people buy, pay, and trust in this market? Cash-heavy? Mobile-money-first? Credit-card-dominant? Community-driven? This shapes the entire go-to-market.
- **Market data:** Use local census data, industry reports, and government statistics where possible. If you don't have them, ask the founder or help them estimate bottom-up.

---

## PRE-FLIGHT — CHECK FOR EXISTING CONTEXT

Before starting the interview, check:

1. **Does the founder have an existing pitch deck or one-pager?**
   - Ask: "Do you have any existing pitch materials — a deck, a one-pager, an application you've submitted? I can work from that."
   - If YES: Read it and use it to skip already-answered questions.
   - If NO: Start from Round 0.

---

## ROUND 1 — THE STORY

**Goal:** Nail the 30-second elevator pitch and the emotional problem/solution narrative.

### Questions to Ask

1. **"You're in an elevator with an investor. You have 30 seconds. Go."**
   - Let them try first. Most founders ramble. That's fine — you'll refine it.
   - If they freeze: "Start with: 'You know how [problem]? We [solution].'"
   - The goal is ONE sentence for the problem and ONE sentence for the solution.

2. **"Tell me about a REAL person who has this problem. Give them a name. What's their day like?"**
   - This becomes the "problem slide" narrative. Investors remember stories, not statistics.
   - Push for emotional specificity. Use a culturally appropriate name for the founder's market. Guide them: "[Name] is a [role] in [city] who [daily frustration with specific details — amounts, time wasted, consequences]."
   - If the founder gives you a generic persona, push deeper: "That's the role description. Now make them a real person. Name, age, daily frustration."

3. **"Now describe [persona]'s day AFTER they start using your product."**
   - This is the "solution slide." Same person, transformed experience.
   - The contrast between Q2 and Q3 IS the pitch.

4. **"Why does this problem exist? Why hasn't someone solved it already?"**
   - This reveals the structural insight — the reason the opportunity exists NOW.
   - Good answers: "The technology didn't exist until recently", "Regulation just changed", "Incumbents are too big to care about this segment", "It requires local knowledge that outsiders don't have."
   - Bad answers (push back): "Nobody thought of it" (they did), "We're just better" (at what, specifically?).

### What You're Producing
- **Elevator Pitch:** 2-3 sentences (problem + solution + why now)
- **Problem Narrative:** The persona story — emotional, specific, relatable
- **Solution Narrative:** The persona's transformed experience
- **Insight:** Why this problem exists and why now is the time

---

## ROUND 2 — THE MARKET

**Goal:** Size the opportunity. Investors need to believe this can be BIG.

### Questions to Ask

5. **"How many people have the problem you described? Be as specific as you can."**
   - Guide them through TAM/SAM/SOM if they're unfamiliar:
     - **TAM (Total Addressable Market):** "How many people in the WORLD could theoretically use this?"
     - **SAM (Serviceable Addressable Market):** "Of those, how many are in markets you can actually reach in 3-5 years?"
     - **SOM (Serviceable Obtainable Market):** "Of those, how many can you realistically capture in Year 1-2?"
   - If they don't know: "Let's estimate together. How many [users/businesses/transactions] exist in [target geography]?"

6. **"How much is each user worth to you per year? (Even a rough guess)"**
   - This is the start of unit economics. Revenue per user × addressable users = market size in local currency.
   - If they don't know: "How much does the average user spend or transact through your platform? What cut do you take?"

7. **"Why is this a GROWING market? What trend is in your favor?"**
   - Investors want tailwinds. Digital payments growing? Smartphone adoption rising? Regulation pushing digitization? Urbanization accelerating?
   - If the market is flat: "Is there a trigger event that will accelerate adoption?" (New law, infrastructure change, cultural shift, technology breakthrough)

8. **"Where do you launch first, and how do you expand?"**
   - Go-to-market geography and expansion path.

### What You're Producing
- **Market Size Slide:** TAM / SAM / SOM with local currency values (+ USD equivalent)
- **Growth Narrative:** Why the market is expanding
- **Go-to-Market:** Launch geography → expansion path

### Agent Notes — Market Sizing Help

If the founder can't size their market, help them with a bottom-up estimate:

```
[Number of target users in target geography]
× [Average transactions per user per year]
× [Average transaction value]
× [Platform take rate]
= Addressable revenue
```

Adapt the example to the founder's market and currency. Use real local data points wherever possible.

---

## ROUND 3 — THE BUSINESS

**Goal:** How does this make money? What's the unit economics? Any traction yet?

### Questions to Ask

9. **"How does your product make money? Walk me through every revenue stream."**
   - Common models (guide if needed):
     - **Transaction fee / commission:** X% of every transaction
     - **Subscription:** Monthly/annual fee per user or business
     - **Freemium:** Free base, paid premium features
     - **Marketplace take rate:** Cut from buyer/seller transactions
     - **Advertising:** Monetize attention/data
     - **Licensing / white-label:** Sell the platform to other operators
   - Get specific: "What percentage? What price point? Per transaction or flat?"

10. **"Walk me through the money math for ONE user."**
    - This is the unit economics slide:
      - **CAC (Customer Acquisition Cost):** "How much does it cost to get one user?"
      - **LTV (Lifetime Value):** "How much does one user generate over their lifetime?"
      - **Payback period:** "How long until a user pays back their acquisition cost?"
    - If they don't know: "Let's estimate. If you spend nothing on marketing and rely on word-of-mouth for the first 1,000 users, what does organic acquisition look like?"

11. **"Do you have ANY traction? Users, revenue, waitlist, LOIs, pilots, partnerships?"**
    - Even pre-launch traction matters: "50 merchants signed up for the waitlist", "3 operators signed LOIs", "We ran a 2-week pilot with 200 users."
    - If no traction: "What's your plan to get first users? What does Month 1 look like?"

12. **"What does it cost to run this? What are your major cost buckets?"**
    - Guide them: cloud hosting, payment gateway fees, SMS costs, team salaries, marketing.
    - This feeds into the use-of-funds and burn rate.

### What You're Producing
- **Business Model Slide:** Revenue streams with specifics
- **Unit Economics:** CAC, LTV, payback period (even if estimated)
- **Traction Slide:** Whatever they've got — numbers, partnerships, pilots, waitlist
- **Cost Structure:** Major expense categories

---

## ROUND 4 — THE MOAT

**Goal:** Why will you win? Why can't someone copy this tomorrow?

### Questions to Ask

13. **"Who else is trying to solve this problem? What are they doing?"**
    - If they say "no one": push back. "Really? No one in the world? Not even a manual process or workaround?"
    - Map competitors on 2 axes that favor the founder's product. (e.g., "feature depth vs. ease of use", "cost vs. coverage")

14. **"What's your unfair advantage? Why will YOU win this?"**
    - Types of moat (guide them):
      - **Network effects:** Product gets better as more people use it
      - **Switching costs:** Once users are in, it's hard to leave
      - **Data advantage:** You accumulate data that improves the product
      - **Regulatory/licensing:** You have permits or compliance others don't
      - **Local knowledge:** You understand the market in ways outsiders can't
      - **Speed:** You're ahead and moving fast
      - **Team:** Your team has unique domain expertise
    - "Which of these apply to you? Be honest — investors will probe this."

15. **"What happens if [biggest tech company in your space] decides to build this?"**
    - The "big player" question. Every founder gets it. Reference the actual dominant player in the founder's market — not a generic default.
    - Good answers: "They can't because [structural reason]", "They tried and failed because [specific reason]", "Our value is in the local network, which can't be copied remotely."
    - Weak answers to push back on: "They won't bother" (they might), "We'll be acquired" (that's not a strategy).

16. **"Tell me about the team. Who are you, and why are you the right people to build this?"**
    - For each key team member: name, role, relevant background, why they're uniquely qualified.
    - Solo founder? "What roles do you need to hire first? What's your biggest skill gap?"
    - "Is there a personal connection to this problem? Have you lived it?"

### What You're Producing
- **Competition Slide:** Landscape map or comparison table (non-technical, benefit-focused)
- **Moat Slide:** Why this is defensible
- **Team Slide:** Founder bios with relevant credibility

---

## ROUND 5 — THE ASK

**Goal:** What do you need, and what will you do with it?

### Questions to Ask

17. **"Are you raising money? How much, and what type? (Pre-seed, seed, angel, grant, bootstrap)"**
    - If bootstrapping: "What's your runway? How long can you sustain without funding?"
    - If raising: get the target amount and instrument (SAFE, equity, convertible note).
    - Amounts in local currency — include USD equivalent for international investors.

18. **"What will you spend it on? Break it into 3-4 buckets."**
    - Typical: Engineering (X%), Marketing/Growth (Y%), Operations (Z%), Buffer
    - Get percentages or actual amounts.

19. **"What milestones will this funding unlock? What does success look like in 12-18 months?"**
    - Push for specific, measurable milestones:
      - "1,000 daily active users"
      - "[Local currency amount] in monthly transaction volume"
      - "Expansion to 3 cities"
      - "Revenue positive on unit economics"
    - These become the "why now" for the investment — this money buys THESE outcomes.

20. **"What's the BIGGEST risk? What keeps you up at night?"**
    - Investors respect honesty. "Our biggest risk is [X], and we're mitigating it by [Y]."
    - Common risks: regulatory uncertainty, market adoption speed, key person dependency, competition, technology risk.

21. **"If everything goes perfectly, what does this company look like in 5 years?"**
    - The vision slide. Paint the picture.
    - Revenue target? User count? Geographic reach? Team size? Impact metric?

### What You're Producing
- **The Ask Slide:** Amount, instrument, stage
- **Use of Funds Slide:** 3-4 buckets with percentages
- **Milestones Slide:** 12-18 month targets
- **Risk & Mitigation:** Honest assessment
- **Vision Slide:** The 5-year picture

---

## FINAL ASSEMBLY

### Step 1: Draft the Pitch Pack

Assemble the complete document using the output format below. Write in clear, non-technical language. Every sentence should be understandable by someone with zero tech knowledge.

**Writing Rules:**
- No jargon. "Real-time GPS tracking" → "Customers see exactly where their delivery is."
- No architecture. Never mention frameworks, databases, APIs, or protocols.
- Lead with impact. "20% discount automatically applied" → "Senior citizens save 20% on every purchase — automatically."
- Use real numbers wherever possible. "$20M market" is better than "large market."
- One idea per slide/section. If you're combining two ideas, split them.
- Use local currency throughout. Include USD equivalent in parentheses for key figures (market size, raise amount).

### Step 2: Review with Founder

Present the draft. Ask:
- "Read the elevator pitch out loud. Does it feel natural? Would you actually say this?"
- "Is the traction section accurate? Don't exaggerate — investors verify."
- "Does the ask feel right? Too much? Too little?"
- "Are there any claims here you can't defend in a Q&A?"

### Step 3: Finalize

Incorporate feedback. Remove all agent instructions. The final document should read as a polished pitch narrative.

### Step 4: Generate PDF

```bash
npx md-to-pdf [PROJECT]_Pitch_V1.0.md
```

---

# OUTPUT FORMAT

> **Agent instruction:** Use this structure for the final document. All content should be investor-ready — non-technical, narrative-driven, concise. Use local currency throughout with USD equivalents for key figures.

---

<!-- ============================================================ -->
<!-- FINAL DOCUMENT STARTS HERE — Everything above is agent-only   -->
<!-- ============================================================ -->

# [PROJECT NAME] — Investor Pitch Pack

**[Company Name]** | [City, Country] | [Date]

[Author Name], [Title] | [Contact Email] | [LinkedIn/Website]

---

## THE ELEVATOR PITCH

> [2-3 sentences. Problem + Solution + Why Now. This should be memorizable and speakable.]

---

## THE PROBLEM

### [Persona Name]'s Story

[2-3 paragraphs. Tell the story of a real person (or realistic persona) who suffers from this problem daily. Make it emotional and specific. Use a culturally appropriate name. End with the cost — time, money, frustration, risk — that this person bears.]

### The Problem at Scale

[1 paragraph. Zoom out from the individual to the market. "[Persona] isn't alone. [X million] people face this every day, costing [Y] in [lost time / money / safety / productivity]."]

---

## THE SOLUTION

### How [Project] Works

[3-5 bullet points. Non-technical description of what the product does, written from the USER's perspective. No architecture, no tech stack, no feature lists.]

- **[User action]** → [Outcome they care about]
- **[User action]** → [Outcome they care about]
- ...

### [Persona Name]'s Day — After [Project]

[1-2 paragraphs. Same person from the Problem section, but now their day is transformed. Mirror the structure of the problem story to make the contrast vivid.]

---

## THE MARKET

### Market Size

| Segment | Size | Basis |
|---------|------|-------|
| **TAM** (Total Addressable Market) | [Local currency (~$USD)] | [How calculated] |
| **SAM** (Serviceable Addressable Market) | [Local currency (~$USD)] | [Geographic/segment filter] |
| **SOM** (Year 1-2 Target) | [Local currency (~$USD)] | [Realistic capture estimate] |

### Why Now?

[2-3 bullet points. What macro trends, regulatory changes, or technology shifts make this the right moment.]

- [Trend 1 — with data point if available]
- [Trend 2]
- [Trend 3]

### Go-to-Market

[Short paragraph. Where you launch, how you expand, what the sequence is.]

---

## THE BUSINESS MODEL

### How We Make Money

[List each revenue stream in plain language. For each: what it is, who pays, and how much.]

1. **[Revenue stream name]** — [Description]. [Amount or percentage].
2. **[Revenue stream name]** — [Description]. [Amount or percentage].
3. ...

### Unit Economics

| Metric | Value | Notes |
|--------|-------|-------|
| Average Revenue Per User (ARPU) | [Amount / period] | [Basis] |
| Customer Acquisition Cost (CAC) | [Amount] | [Channel] |
| Lifetime Value (LTV) | [Amount] | [Retention assumption] |
| LTV : CAC Ratio | [X : 1] | [Target: > 3:1] |
| Payback Period | [Months] | |

### Cost Structure

| Category | % of Budget | Notes |
|----------|-------------|-------|
| [Category] | [%] | [Key line items] |
| [Category] | [%] | |
| ... | | |

---

## TRACTION

[Present whatever exists — be honest. Pre-launch is fine. Frame it as momentum.]

| Metric | Value | Date |
|--------|-------|------|
| [Metric: users, revenue, waitlist, pilots, LOIs, partnerships] | [Number] | [When] |
| ... | | |

[1-2 sentences of narrative context. "We launched a 2-week pilot in [city] and saw..." or "We're pre-launch but have secured..."]

---

## THE COMPETITION

### Landscape

[Position your product against alternatives. Use a 2×2 matrix description or comparison table. Keep it benefit-focused, not feature-focused.]

| | [Competitor / Status Quo A] | [Competitor B] | **[Your Product]** |
|--|---------------------------|----------------|-------------------|
| [Benefit dimension 1] | [Their reality] | [Their reality] | **[Your advantage]** |
| [Benefit dimension 2] | [Their reality] | [Their reality] | **[Your advantage]** |
| [Benefit dimension 3] | [Their reality] | [Their reality] | **[Your advantage]** |
| [Benefit dimension 4] | [Their reality] | [Their reality] | **[Your advantage]** |

### Our Moat

[2-3 bullet points. Why this is defensible. Use plain language — "network effects" is fine, "WebSocket-based real-time state sync" is not.]

- **[Moat type]:** [One sentence explanation]
- **[Moat type]:** [One sentence explanation]
- **[Moat type]:** [One sentence explanation]

---

## THE TEAM

[For each key team member:]

### [Name] — [Role]
[2-3 sentences. Background, relevant experience, personal connection to the problem. No technical skills — instead, credibility and track record.]

[Repeat for each team member]

### Key Hires Needed
[If applicable. 1-2 roles they'll hire with funding.]

---

## THE ASK

### Raising

| | |
|--|--|
| **Amount** | [Local currency (~$USD)] |
| **Instrument** | [SAFE / Equity / Convertible Note / Grant] |
| **Stage** | [Pre-seed / Seed / Series A] |
| **Use** | [One sentence: "To [achieve milestone] by [date]"] |

### Use of Funds

| Category | Allocation | What It Buys |
|----------|-----------|--------------|
| [Category] | [%] | [Specific outcome] |
| [Category] | [%] | [Specific outcome] |
| [Category] | [%] | [Specific outcome] |
| Buffer / Ops | [%] | Runway extension |

### 12-18 Month Milestones

_"This funding gets us to:"_

- [ ] [Milestone 1 — specific, measurable]
- [ ] [Milestone 2]
- [ ] [Milestone 3]
- [ ] [Milestone 4]

---

## RISKS & MITIGATION

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| [Biggest risk] | [High/Med/Low] | [What you're doing about it] |
| [Risk 2] | [H/M/L] | [Mitigation] |
| [Risk 3] | [H/M/L] | [Mitigation] |

---

## THE VISION

> [2-3 sentences. The 5-year picture. What does the world look like if you succeed? Make it aspirational but credible. End on an emotional note that echoes the problem story.]

---

## SUGGESTED PITCH DECK OUTLINE

_For converting this document into a 12-slide presentation:_

| Slide | Content | Source Section |
|-------|---------|---------------|
| 1 — Title | Company name, tagline, contact | Header |
| 2 — Problem | [Persona]'s story + problem at scale | The Problem |
| 3 — Solution | How it works (3-5 bullets) | The Solution |
| 4 — Demo / Product | Screenshots, mockups, or live demo | (Visual asset) |
| 5 — Market | TAM/SAM/SOM + Why Now | The Market |
| 6 — Business Model | Revenue streams + unit economics | The Business Model |
| 7 — Traction | Metrics table + narrative | Traction |
| 8 — Competition | Landscape table or 2×2 matrix | The Competition |
| 9 — Team | Bios + key hires | The Team |
| 10 — Financials | Revenue projection, burn rate | Business Model + Ask |
| 11 — The Ask | Amount, use of funds, milestones | The Ask |
| 12 — Vision | The 5-year picture | The Vision |

---

*[PROJECT NAME] — Investor Pitch Pack v1.0*
*Prepared [Date]*

<!-- ============================================================ -->
<!-- END OF FINAL DOCUMENT                                         -->
<!-- ============================================================ -->

---

# AGENT QUALITY CHECKLIST

Before delivering the final document, verify:

- [ ] Elevator pitch is 2-3 sentences and speakable out loud in 30 seconds
- [ ] Problem section tells a STORY about a named person, not a list of pain points
- [ ] Persona name is culturally appropriate for the founder's market
- [ ] Solution section has ZERO technical jargon — no mention of frameworks, databases, or protocols
- [ ] Market size has actual currency amounts (even rough estimates), not "it's a big market"
- [ ] TAM/SAM/SOM are calculated bottom-up (not pulled from a Gartner report)
- [ ] All currency is in the founder's local currency with USD equivalents for key figures
- [ ] Business model specifies exact percentages or price points, not "we'll charge a fee"
- [ ] Unit economics table is filled (even with estimates marked as such)
- [ ] Competition table compares on BENEFITS to users, not FEATURES of the product
- [ ] Competitors referenced are real players in the founder's actual market
- [ ] Moat section names a specific defensibility type, not "we're better"
- [ ] Team section highlights credibility and domain expertise, not technical skills
- [ ] The Ask has a specific amount (local currency + USD), instrument, and use-of-funds breakdown
- [ ] Milestones are specific and measurable ("1,000 DAU" not "grow user base")
- [ ] Risks are honest — at least one should make the founder uncomfortable
- [ ] Vision echoes the problem story — the person from Slide 2 lives in this world
- [ ] The entire document is understandable by someone who has never written code
- [ ] No placeholder text remains
- [ ] Suggested deck outline maps cleanly to the content sections
