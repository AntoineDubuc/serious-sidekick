---
name: serious-bananas
description: "Generate images (especially diagrams) using Google's Gemini native image generation API (Nano Banana 2). Use when the user says 'serious bananas', 'nano banana', 'generate image', 'generate diagram', 'create a diagram', or wants to create images via the Gemini API."
user-invocable: true
---

# Nano Banana 2 — Image Generation Skill

Generate images (optimized for diagrams) using Google's Gemini native image generation API. Powered by Nano Banana 2 with 4K resolution, precision text rendering, subject consistency, and iterative editing.

<!-- BEGIN CANONICAL VOICE BLOCK — do not edit; lint compares byte-for-byte across 24 surfaces -->
## Voice (MANDATORY — applies to all chat replies)

Talk to the user like a busy PM, not an engineer. Every chat reply uses this structure:

1. **What this does** — one sentence. Plain English. What the user experiences.
2. **What I need from you** — one ask, sometimes a short numbered list.
3. **What you need to set up first** — only if there's prep on the user's side.
4. **Question** — one line. Just the question, no preamble.

Style:
- ~10 lines max.
- No internal task labels ("Task 5", "Phase 2", "Plan 7B", "1v", "T0").
- No bare ordinal options ("Option 1", "Option 2"). Label alternatives by what they are.
- No file paths, library names, or framework names in chat.

Canonical card: `.claude/skills/_shared/voice-card.md`.
<!-- END CANONICAL VOICE BLOCK -->

## Prerequisites

- Python 3 with `google-genai` and `pillow` installed (`pip install google-genai pillow python-dotenv`)
- `GEMINI_API_KEY` set in the project `.env` file

## Models

<!-- voice-retrofit: deferred — reason: phase-4-polish; thread-1 line: 18 -->
<!-- WHY: this table is the skill's internal reference of which image-generation model to dispatch
     to. The user never sees the model IDs — they see the nickname ("Nano Banana 2") and the
     trade-off in plain English during the Interview Protocol. Phase 4 polish: hide the API model
     IDs entirely from any chat output (already partially handled by the Interview's "Recommended"
     framing). -->

| Model ID | Nickname | Use case | Pricing |
|----------|----------|----------|---------|
| `gemini-3.1-flash-image-preview` | Nano Banana 2 | Best balance — Pro quality at Flash speed. 4K, text rendering, subject consistency | ~$0.045/1K, ~$0.067/2K, ~$0.151/4K |
| `gemini-3-pro-image-preview` | Nano Banana Pro | Advanced reasoning for complex compositions | ~$0.134/image |
| `gemini-2.5-flash-image` | Nano Banana (v1) | Budget — high-volume, low-latency | ~$0.039/image |

Default to `gemini-3.1-flash-image-preview` (Nano Banana 2). Use Pro only if the user needs advanced reasoning for highly complex compositions. Use v1 only if the user explicitly wants the cheapest option.

## Interview Protocol

<!-- voice-retrofit: rewritten; thread-1 line: 27 -->

**Voice rule for this protocol:** the questions below have built-in option menus to inform the AGENT what's available — they are NOT what the user sees verbatim. For each question, ask the user in PM voice: state the recommended choice in plain English, then ONE question. Only present alternatives if the user asks. Example:

> What this does: a flowchart usually fits this best — clean lines, easy to read.
>
> Question: go with that, or want to see other styles?

When the user invokes `/serious-bananas`, ask these questions **one at a time**. Wait for each answer before asking the next.

### Question 1: What do you need?

Ask the user to describe what they want in plain language.

- Header: "Description"
- Free-text input (use a single option "Describe your image" with description "Tell me what you want to see — a diagram, illustration, icon, etc." plus let them use Other for free text)
- This is the core prompt — get enough detail to craft a good generation prompt

### Question 2: What type?

- Header: "Type"
- Options:
  - **Flowchart** — Process flows, decision trees, step-by-step
  - **Architecture diagram** — System components, services, connections
  - **Sequence diagram** — Interactions between actors over time
  - **ER diagram** — Entities, relationships, database schema
  - **Infographic** — Data visualization, stats, comparisons
  - **Concept map** — Ideas and their relationships
  - **Freeform / other** — No specific diagram type
- Other: allowed (user types custom type)

### Question 3: Style?

- Header: "Style"
- Options:
  - **Clean / minimal** — Simple lines, solid colors, lots of whitespace (Recommended)
  - **Dark mode** — Dark background, glowing/luminous borders, light text
  - **Technical / blueprint** — Grid background, precise lines, engineering feel
  - **Whiteboard sketch** — Hand-drawn look, casual, brainstorm feel
  - **Polished / presentation-ready** — Gradients, shadows, slide-deck quality

### Question 4: Resolution?

<!-- voice-retrofit: rewritten; thread-1 line: 64 -->
- Header: "Resolution"
- In chat: recommend 2K (standard) — good quality, fast, cheap. Mention "higher resolution costs more" without pasting the exact prices unless the user asks.
- Internal options (for agent dispatch):
  - **2K (standard)** — Good quality, fast, affordable (Recommended)
  - **4K (highest)** — Maximum detail, best for print or large displays (~$0.15/image)
  - **1K (fast)** — Quick previews, thumbnails (~$0.045/image)
  - **512 (thumbnail)** — Ultra-fast, ultra-cheap, tiny previews

### Question 5: Aspect ratio?

- Header: "Ratio"
- Options:
  - **16:9 (wide)** — Slides, presentations, widescreen (Recommended)
  - **1:1 (square)** — Social media, icons, balanced layouts
  - **3:2 (standard)** — Documents, general purpose
  - **4:3 (classic)** — Traditional presentations
  - **9:16 (tall)** — Mobile, vertical infographics
  - **21:9 (ultrawide)** — Banners, cinema, panoramic
  - **4:5 (portrait)** — Instagram portrait, posters
<!-- voice-retrofit: deferred — reason: not-user-facing; thread-1 line: 81 -->
<!-- WHY: this "Other: allowed" bullet is an agent-side reference list of the API-supported
     aspect ratios for the "Other" free-text path. The user types a ratio; the agent validates
     against this list. The list is never displayed verbatim to the user. -->
- Other: allowed (user types custom ratio — API supports: `1:1`, `1:4`, `1:8`, `2:3`, `3:2`, `3:4`, `4:1`, `4:3`, `4:5`, `5:4`, `8:1`, `9:16`, `16:9`, `21:9`)

### Question 6: How many variations?

- Header: "Variations"
- Options:
  - **1** — Single image (Recommended)
  - **2** — Two variations to compare
  - **3** — Three variations
  - **4** — Four variations (max)

### Question 7: Reference images?

- Header: "Reference images"
- Options:
  - **None** — Generate from description only (Recommended)
  - **Yes** — I have reference images for consistency
- If yes: ask for file paths (up to 14 images). These are base64-encoded and passed to the model for subject/style consistency.

### Question 8: Search grounding?

- Header: "Search grounding"
- Options:
  - **No** — Generate from description and training data only (Recommended)
  - **Web search** — Model searches Google for factual accuracy (useful for real-world subjects)
  - **Web + Image search** — Model searches Google web and images for visual references (best for recreating real things)

### Question 9: Where to save?

- Header: "Save path"
- Options:
  - **Current directory** — Save in the current working directory (Recommended)
  - **./images/** — Save in an images subfolder (created if needed)
  - **Desktop** — Save to ~/Desktop
- Other: allowed (user types custom path)

## Prompt Engineering

After collecting answers, craft an optimized prompt. For diagrams, always append these instructions to the user's description:

```
Diagram-specific suffixes (add to prompt based on type):
- Flowchart: "Clear labeled boxes connected by directional arrows. High contrast. Professional diagram style. No ambiguous connections. Legible text labels on all elements."
- Architecture: "Clearly labeled components with connection lines showing data flow direction. Professional technical diagram. Legend if needed. Legible text on all components."
- Sequence: "Vertical lifelines with horizontal arrows showing message flow. Clear labels on every arrow. Time flows top to bottom. Professional UML style."
- ER diagram: "Entities as labeled rectangles, relationships as labeled lines with cardinality notation. Clean database schema style. Legible field names."
- Infographic: "Clear data hierarchy, readable labels, consistent color palette, professional layout."
- Concept map: "Nodes as rounded rectangles, labeled connecting lines, clear hierarchy, balanced layout."
- Freeform: (no suffix — use user description as-is)
```

Style suffixes:
- Clean/minimal: "Minimalist design, solid colors, ample whitespace, thin lines."
- Dark mode: "Dark background (#1a1a2e or similar dark navy/charcoal). Light text on all nodes. Glowing or luminous node borders. Modern tech aesthetic."
- Technical/blueprint: "Blueprint grid background, precise technical lines, monospace labels, engineering aesthetic."
- Whiteboard sketch: "Hand-drawn sketch style, slightly imperfect lines, casual marker-on-whiteboard feel."
- Polished/presentation: "Professional presentation quality, subtle gradients, soft shadows, modern corporate style."

Always append: "No watermarks. No extra text outside labels. Legible, precise text rendering on all labels and annotations."

## Execution

After crafting the prompt, generate the image(s) by running a Python script via Bash.

### Script Template

```python
import os, sys, base64
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

from google import genai
from google.genai import types

api_key = os.environ.get("GEMINI_API_KEY")
if not api_key:
    print("ERROR: GEMINI_API_KEY not found in .env or environment", file=sys.stderr)
    sys.exit(1)

client = genai.Client(api_key=api_key)

PROMPT = """{{PROMPT}}"""
MODEL = "{{MODEL}}"
ASPECT = "{{ASPECT_RATIO}}"
IMAGE_SIZE = "{{IMAGE_SIZE}}"
SAVE_DIR = Path("{{SAVE_DIR}}")
VARIATIONS = {{VARIATIONS}}
BASE_NAME = "{{BASE_NAME}}"
REFERENCE_IMAGES = {{REFERENCE_IMAGES}}  # List of file paths, or empty list
SEARCH_GROUNDING = "{{SEARCH_GROUNDING}}"  # "none", "web", or "web_image"

SAVE_DIR.mkdir(parents=True, exist_ok=True)

# Build contents with reference images if provided
contents = []
if REFERENCE_IMAGES:
    for img_path in REFERENCE_IMAGES:
        with open(img_path, "rb") as f:
            img_data = base64.b64encode(f.read()).decode()
        contents.append(types.Part.from_bytes(
            data=base64.b64decode(img_data),
            mime_type="image/png"
        ))
    contents.append(PROMPT + "\nMaintain visual consistency with the reference images provided.")
else:
    contents.append(PROMPT)

# Build config
config_kwargs = {
    "image_config": types.ImageConfig(
        aspect_ratio=ASPECT,
        image_size=IMAGE_SIZE,
    ),
    "thinking_config": types.ThinkingConfig(
        thinking_level="High"
    ),
}

config = types.GenerateContentConfig(**config_kwargs)

for i in range(VARIATIONS):
    suffix = f"_v{i+1}" if VARIATIONS > 1 else ""
    filename = f"{BASE_NAME}{suffix}.png"
    filepath = SAVE_DIR / filename

    print(f"Generating {filename} ({IMAGE_SIZE}, {ASPECT})...")
    resp = client.models.generate_content(
        model=MODEL,
        contents=contents,
        config=config,
    )

    saved = False
    for part in resp.candidates[0].content.parts:
        if getattr(part, "inline_data", None) is not None:
            img = part.as_image()
            img.save(str(filepath))
            print(f"Saved {filepath}")
            saved = True
            break

    if not saved:
        for part in resp.candidates[0].content.parts:
            if hasattr(part, "text") and part.text:
                print(f"Model returned text instead of image: {part.text[:200]}")
                break
        else:
            print(f"WARNING: No image data in response for variation {i+1}")

print("Done.")
```

### Template Variables

Replace these placeholders before execution:
- `{{PROMPT}}` — The crafted prompt (user description + type suffix + style suffix + "No watermarks. No extra text outside labels. Legible, precise text rendering.")
- `{{MODEL}}` — The selected model ID (default: `gemini-3.1-flash-image-preview`)
- `{{ASPECT_RATIO}}` — The chosen aspect ratio (e.g., `16:9`)
- `{{IMAGE_SIZE}}` — The chosen resolution (e.g., `2K`, `4K`)
- `{{SAVE_DIR}}` — Resolved absolute path to save directory
- `{{VARIATIONS}}` — Number of variations (1-4)
- `{{BASE_NAME}}` — Slugified version of the user's description (e.g., `auth_flow_diagram`)
- `{{REFERENCE_IMAGES}}` — Python list of file paths, or `[]` if none
- `{{SEARCH_GROUNDING}}` — `"none"`, `"web"`, or `"web_image"`

### Execution Steps

1. Generate a short slug from the user's description for the filename (e.g., "authentication flow" → "auth_flow")
2. Fill in the template variables
3. Write the script to a temp file (e.g., `/tmp/nano_banana_gen.py`)
4. Run it via Bash: `python3 /tmp/nano_banana_gen.py`
5. If successful, use Read to display the generated image(s) to the user
6. **QA the generated image** — actually look at it and verify it matches the user's description. Check: are labels legible? Is the layout correct? Does the content match what was asked for? If not, report issues and offer to regenerate or iterate.
7. Clean up the temp script

### Iterative Editing

After generating, offer: **"Want to refine this? I can adjust specific elements."**

If yes, use the chat API for multi-turn editing:

```python
chat = client.chats.create(
    model="gemini-3.1-flash-image-preview",
    config=types.GenerateContentConfig(
        response_modalities=['TEXT', 'IMAGE']
    )
)

# First generation (or pass the existing image)
response = chat.send_message(PROMPT)

# Iterative edits
response = chat.send_message("Make the boxes blue instead of green")
response = chat.send_message("Add a legend in the top-right corner")
```

Each edit builds on the previous image — no need to regenerate from scratch.

### Error Handling

<!-- voice-retrofit: rewritten; thread-1 line: 284 -->

Translate error states to PM voice. Do NOT dump library names or env-variable names verbatim. Examples:

- **Missing image generator on this machine:** "The image-generation tool isn't installed yet. Want me to install it for you (one command), or you can paste this into your terminal: `pip install google-genai pillow python-dotenv`."
- **Missing API key:** "The image-generation service needs a key. I'll put it in your local secret file (`.env`). Want me to walk you through getting one (~2 min)?"
- **Model returned text instead of image:** "The model wrote back a description instead of drawing. Likely my prompt was ambiguous. Want to rephrase together?"
- **Generation failed:** "The model couldn't generate this one. Probably worth trying a different model — recommend Nano Banana Pro for complex compositions, or the cheap one for a quick retry."
- **Content blocked:** "The model refused this prompt (usually famous figures or sensitive content). Want to simplify the description?"

## Example Invocation

User: `/serious-bananas`

1. "What do you need?" → "Authentication flow for our OAuth2 implementation"
2. "What type?" → Flowchart
3. "Style?" → Dark mode
4. "Resolution?" → 2K
5. "Aspect ratio?" → 16:9
6. "How many variations?" → 2
7. "Reference images?" → None
8. "Search grounding?" → No
9. "Where to save?" → ./images/

<!-- voice-retrofit: deferred — reason: not-user-facing; thread-1 line: 304 -->
<!-- WHY: this is an Example Invocation showing how the agent SHOULD assemble the
     generation prompt internally. It's reference documentation for the agent, not
     a chat message to the user. The user sees the resulting image, not this prompt. -->
Crafted prompt: "Authentication flow for OAuth2 implementation. Show the complete flow from user login request through token exchange to authenticated session. Clear labeled boxes connected by directional arrows. High contrast. Professional diagram style. No ambiguous connections. Legible text labels on all elements. Dark background (#1a1a2e or similar dark navy/charcoal). Light text on all nodes. Glowing or luminous node borders. Modern tech aesthetic. No watermarks. No extra text outside labels. Legible, precise text rendering on all labels and annotations."

Generates: `./images/oauth2_auth_flow_v1.png` and `./images/oauth2_auth_flow_v2.png`

