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

## How to Use

### Using Claude Code Skills (Recommended)

If you have Forge skills installed (`~/.claude/skills/`):

```
/bluep MyProject     — Start a Product Blueprint interview
/pitch MyProject     — Start a PitchForge interview
/arch                — Polish blueprint architecture (after /bluep)
```

The skills handle everything — framework loading, interview flow, document generation.

### Manual Usage (Any AI)

Open a conversation with any AI assistant and paste the contents of the framework file:

> **For Product Blueprint:**
> "Use this framework to interview me about my product idea and generate a Product Blueprint."

> **For PitchForge:**
> "Use this framework to interview me about my startup and generate an investor pitch pack."

### The Interview

The AI asks questions in rounds — like a conversation, not a form.

**Product Blueprint** has 7 rounds (~60 minutes total):
1. The Idea — "What are you building?"
2. The Users — "Who uses it?"
3. The Core Flow — "What's the main thing it does?"
4. Money & Trust — "How does money work? What could go wrong?"
5. Everything Else — "Notifications? Admin panel? Social features?"
6. Technical Decisions — "What tech stack? How do users log in?"
7. Launch & Future — "What's MVP? What's the roadmap?"

**PitchForge** has 6 rounds (~27 minutes total):
0. The Context — "Where are you building this?" (sets currency, competitors, regulations)
1. The Story — "Elevator pitch. Go."
2. The Market — "How big is this?"
3. The Business — "How do you make money?"
4. The Moat — "Why won't someone copy you?"
5. The Ask — "How much are you raising?"

You don't need to prepare. Just answer honestly. The AI will push back if your answers are vague.

### Output

- **Product Blueprint** → `YourProject_ProductBlueprint_V1.0.md`
- **PitchForge** → `YourProject_PitchForge_V1.0.md`

Review it. Ask the AI to fix anything that's wrong. When you're happy, you're done.

### What to Do Next

**Product Blueprint** — Give it to your AI coding agent:
> "Here's my Product Blueprint. Plan the architecture and start building Phase 1 (MVP)."

Or run `/arch` to polish the architecture before building.

**PitchForge** — Use it to:
- Build a slide deck (the document includes a 12-slide outline)
- Prepare for investor meetings
- Write accelerator applications
- Explain your startup to anyone

---

## Samples

The project subdirectories have real outputs:

- `jeepi/` — Jeepi project (product blueprint + pitch pack)
- `kain/` — Kain project (product blueprint + pitch pack)
- `sookie/` — Sookie project (pitch pack)

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
Any capable AI assistant works. Claude Code with Forge skills is the ideal setup. The framework is the prompt — the AI is the engine.

**How do I generate a PDF?**
```bash
npx md-to-pdf YourProject_ProductBlueprint_V1.0.md
```
