---
name: serious-bananas
description: "Generate images (especially diagrams) using Google's Gemini native image generation API (Nano Banana). Use when the user says 'serious bananas', 'nano banana', 'generate image', 'generate diagram', 'create a diagram', or wants to create images via the Gemini API."
user-invocable: true
---

# Nano Banana — Image Generation Skill

Generate images (optimized for diagrams) using Google's Gemini native image generation API.

## Prerequisites

- Python 3 with `google-genai` and `pillow` installed (`pip install google-genai pillow`)
- `GEMINI_API_KEY` set in the project `.env` file

## Models

| Model ID | Nickname | Use case |
|----------|----------|----------|
| `gemini-3-pro-image-preview` | Nano Banana Pro | Highest quality |
| `gemini-3.1-flash-image-preview` | Nano Banana 2 | Faster / cheaper |

Default to `gemini-3-pro-image-preview` unless the user requests the faster model.

## Interview Protocol

When the user invokes `/nano-banana`, ask these 6 questions **one at a time** using the AskUserQuestion tool. Wait for each answer before asking the next.

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
  - **Technical / blueprint** — Grid background, precise lines, engineering feel
  - **Whiteboard sketch** — Hand-drawn look, casual, brainstorm feel
  - **Polished / presentation-ready** — Gradients, shadows, slide-deck quality

### Question 4: Aspect ratio?

- Header: "Ratio"
- Options:
  - **16:9 (wide)** — Slides, presentations, widescreen (Recommended)
  - **1:1 (square)** — Social media, icons, balanced layouts
  - **3:2 (standard)** — Documents, general purpose
  - **9:16 (tall)** — Mobile, vertical infographics

### Question 5: How many variations?

- Header: "Variations"
- Options:
  - **1** — Single image (Recommended)
  - **2** — Two variations to compare
  - **3** — Three variations
  - **4** — Four variations (max)

### Question 6: Where to save?

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
- Flowchart: "Clear labeled boxes connected by directional arrows. High contrast. Professional diagram style. No ambiguous connections. White or light background."
- Architecture: "Clearly labeled components with connection lines showing data flow direction. Professional technical diagram. Legend if needed. Clean background."
- Sequence: "Vertical lifelines with horizontal arrows showing message flow. Clear labels on every arrow. Time flows top to bottom. Professional UML style."
- ER diagram: "Entities as labeled rectangles, relationships as labeled lines with cardinality notation. Clean database schema style."
- Infographic: "Clear data hierarchy, readable labels, consistent color palette, professional layout."
- Concept map: "Nodes as rounded rectangles, labeled connecting lines, clear hierarchy, balanced layout."
- Freeform: (no suffix — use user description as-is)
```

Style suffixes:
- Clean/minimal: "Minimalist design, solid colors, ample whitespace, thin lines."
- Technical/blueprint: "Blueprint grid background, precise technical lines, monospace labels, engineering aesthetic."
- Whiteboard sketch: "Hand-drawn sketch style, slightly imperfect lines, casual marker-on-whiteboard feel."
- Polished/presentation: "Professional presentation quality, subtle gradients, soft shadows, modern corporate style."

Always append: "No watermarks. No extra text outside labels."

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
MODEL = "gemini-3-pro-image-preview"
ASPECT = "{{ASPECT_RATIO}}"
SAVE_DIR = Path("{{SAVE_DIR}}")
VARIATIONS = {{VARIATIONS}}
BASE_NAME = "{{BASE_NAME}}"

SAVE_DIR.mkdir(parents=True, exist_ok=True)

for i in range(VARIATIONS):
    suffix = f"_v{i+1}" if VARIATIONS > 1 else ""
    filename = f"{BASE_NAME}{suffix}.png"
    filepath = SAVE_DIR / filename

    print(f"Generating {filename}...")
    resp = client.models.generate_content(
        model=MODEL,
        contents=[PROMPT],
        config=types.GenerateContentConfig(
            image_config=types.ImageConfig(
                aspect_ratio=ASPECT,
                image_size="2K",
            )
        ),
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
        # Try text response (model may return text instead of image)
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
- `{{PROMPT}}` — The crafted prompt (user description + type suffix + style suffix + "No watermarks. No extra text outside labels.")
- `{{ASPECT_RATIO}}` — The chosen aspect ratio (e.g., "16:9")
- `{{SAVE_DIR}}` — Resolved absolute path to save directory
- `{{VARIATIONS}}` — Number of variations (1-4)
- `{{BASE_NAME}}` — Slugified version of the user's description (e.g., "auth_flow_diagram")

### Execution Steps

1. Generate a short slug from the user's description for the filename (e.g., "authentication flow" → "auth_flow")
2. Fill in the template variables
3. Write the script to a temp file (e.g., `/tmp/nano_banana_gen.py`)
4. Run it via Bash: `python3 /tmp/nano_banana_gen.py`
5. If successful, use Read to display the generated image(s) to the user
6. Clean up the temp script

### Error Handling

- If `google-genai` is not installed: tell the user to run `pip install google-genai pillow`
- If `GEMINI_API_KEY` is missing from `.env`: tell the user to add it
- If the model returns text instead of an image: show the text response and suggest rephrasing
- If generation fails: show the error and suggest trying the flash model (`gemini-3.1-flash-image-preview`)

## Example Invocation

User: `/nano-banana`

1. "What do you need?" → "Authentication flow for our OAuth2 implementation"
2. "What type?" → Flowchart
3. "Style?" → Clean / minimal
4. "Aspect ratio?" → 16:9
5. "How many variations?" → 2
6. "Where to save?" → ./images/

Crafted prompt: "Authentication flow for OAuth2 implementation. Show the complete flow from user login request through token exchange to authenticated session. Clear labeled boxes connected by directional arrows. High contrast. Professional diagram style. No ambiguous connections. White or light background. Minimalist design, solid colors, ample whitespace, thin lines. No watermarks. No extra text outside labels."

Generates: `./images/oauth2_auth_flow_v1.png` and `./images/oauth2_auth_flow_v2.png`
