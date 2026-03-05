# Forge

Turn a product idea into documents that AI agents can build from.

You have an idea. You talk to an AI. It asks you smart questions. At the end, you get a document so detailed that another AI can read it and start building your product — or pitch it to investors.

That's Forge.

---

## What's Inside

### 1. Product Blueprint (`product-blueprint.md`)

**What it does:** Turns your idea into a full technical spec — the kind of document you'd hand to a developer and say "build this."

**Who it's for:** You and your AI coding agent.

**What comes out:** A 22-section document covering everything from "what does this product do" to "what's the database schema" to "how do we deploy it."

### 2. PitchForge (`pitch-forge.md`)

**What it does:** Turns your idea into an investor pitch pack — the kind of document you'd use to raise money or explain your startup to your mom.

**Who it's for:** Investors, advisors, partners, accelerator applications, your co-founder who keeps asking "but what do we actually do?"

**What comes out:** A narrative-driven pitch pack with elevator pitch, market sizing, business model, team bios, and a 12-slide deck outline. Zero technical jargon.

---

## How to Use (Step by Step)

### Step 1: Pick Your Document

| I want to... | Use this |
|---|---|
| Build the product (or have AI build it) | **Product Blueprint** |
| Pitch to investors or explain my startup | **PitchForge** |
| Both | Start with **Product Blueprint**, then run **PitchForge** (it reuses your answers) |

### Step 2: Start a Chat with an AI Agent

Open a conversation with any AI assistant (Claude, ChatGPT, etc.) and paste the contents of the framework file into the chat. Then say:

> **For Product Blueprint:**
> "Use this framework to interview me about my product idea and generate a Product Blueprint."

> **For PitchForge:**
> "Use this framework to interview me about my startup and generate an investor pitch pack."

That's it. The AI reads the framework, becomes your interviewer, and walks you through the process.

### Step 3: Answer the Questions

The AI will ask you questions in rounds — like a conversation, not a form.

**Product Blueprint** has 7 rounds (~60 minutes total):
1. The Idea — "What are you building?"
2. The Users — "Who uses it?"
3. The Core Flow — "What's the main thing it does?"
4. Money & Trust — "How does money work? What could go wrong?"
5. Everything Else — "Notifications? Admin panel? Social features?"
6. Technical Decisions — "What tech stack? How do users log in?"
7. Launch & Future — "What's MVP? What's the roadmap?"

**PitchForge** has 5 rounds (~25 minutes total):
1. The Story — "Elevator pitch. Go."
2. The Market — "How big is this?"
3. The Business — "How do you make money?"
4. The Moat — "Why won't someone copy you?"
5. The Ask — "How much are you raising?"

You don't need to prepare. Just answer honestly. The AI will push back if your answers are vague ("What do you mean by 'users can pay'? Pay with what?").

### Step 4: Get Your Document

When the interview is done, the AI generates the final document:

- **Product Blueprint** → `YourProject_ProductBlueprint_V1.0.md`
- **PitchForge** → `YourProject_PitchForge_V1.0.md`

Review it. Ask the AI to fix anything that's wrong. When you're happy, you're done.

### Step 5: Use It

**Product Blueprint** — Give it to your AI coding agent:
> "Here's my Product Blueprint. Plan the architecture and start building Phase 1 (MVP)."

**PitchForge** — Use it to:
- Build a slide deck (the document includes a 12-slide outline)
- Prepare for investor meetings
- Write accelerator applications
- Explain your startup to anyone

---

## Samples

The `samples/` folder has real outputs generated for the Jeepi project (a cashless jeepney fare platform for the Philippines):

- `samples/JEEPI_ProductBlueprint_V1.0.md` — Full Product Blueprint (22 sections, ~800 lines)
- `samples/JEEPI_PitchForge_V1.0.md` — Full investor pitch pack

Read these to see what the output looks like before you start.

---

## FAQ

**Do I need to be technical?**
No. The Product Blueprint asks technical questions, but the AI will suggest answers and explain trade-offs. You just need to know what you want your product to DO.

**Can I use this for an existing product?**
Yes, but these frameworks are designed for ideation — turning an idea into a spec. If you already have code, the AI can also scan your codebase to fill in technical sections automatically.

**What if I don't know the answer to a question?**
Say "I don't know" or "I haven't thought about that." The AI will either suggest an answer based on your product type, or flag it as something to decide later.

**Can I skip sections?**
Yes. If your product doesn't handle payments, the AI will mark that section "Not applicable" and move on.

**What AI should I use?**
Any capable AI assistant works. Claude and ChatGPT both handle these frameworks well. The framework is the prompt — the AI is the engine.

**How do I generate a PDF?**
If you have Node.js installed:
```bash
npx md-to-pdf YourProject_ProductBlueprint_V1.0.md
```
