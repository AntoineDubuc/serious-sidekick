# Nano Banana v1 vs v2 — What Changed

## At a Glance

| Feature | Nano Banana (v1) | Nano Banana 2 |
|---|---|---|
| **Model ID** | `gemini-2.5-flash-image` | `gemini-3.1-flash-image-preview` |
| **Max resolution** | 2K | **4K** |
| **Speed** | Fast | Fast (same Flash tier) |
| **Pricing** | ~$0.039/image | ~$0.045/1K, ~$0.151/4K |
| **Text rendering** | Often garbled | **Legible, stylized text** |
| **Subject consistency** | None | **Up to 5 characters + 14 objects** |
| **Reference images** | None | **Up to 14 images as input** |
| **Google Search grounding** | None | **Web + Image search during generation** |
| **Thinking/reasoning** | None | **Built-in, on by default** |
| **Multi-turn editing** | None | **Chat-based iterative refinement** |
| **Aspect ratios** | 4 options | **14 options** |
| **Image sizes** | 1K, 2K | **512, 1K, 2K, 4K** |
| **Interactions API** | None | **New unified API** |

---

## New Capabilities in Detail

### 1. 4K Resolution Output
Before: Maximum 2K resolution.
Now: 4K output available. Set `image_size="4K"` in ImageConfig. Costs ~$0.151 per 4K image vs ~$0.045 for 1K.

### 2. Precision Text Rendering
Before: Text in generated images was frequently garbled, misspelled, or unreadable — a major problem for diagrams with labels.
Now: "Capable of generating legible, stylized text" for infographics, marketing mockups, and labeled diagrams. This is the single biggest improvement for diagram use cases.

### 3. Subject Consistency via Reference Images
Before: Each generation was independent. No way to maintain visual consistency across images.
Now: Pass up to 14 reference images (base64-encoded). The model maintains:
- Character appearance for up to 5 characters
- Object fidelity for up to 14 objects
Use case: Generate a series of diagrams with consistent visual style, icons, or branded elements.

### 4. Grounding with Google Search
Before: Model generated from training data only.
Now: Model can search Google (web + images) during generation for factual accuracy.
```python
tools=[{"type": "google_search", "search_types": ["web_search", "image_search"]}]
```
Use case: "Generate an AWS architecture diagram" — model looks up actual AWS service icons.

### 5. Thinking Mode
Before: Direct generation from prompt.
Now: Built-in reasoning process. Model thinks through the prompt before generating. On by default, controllable:
```python
thinking_config=types.ThinkingConfig(thinking_level="High")
```
Use case: Complex diagrams with many interconnected components benefit from the model reasoning about layout first.

### 6. Multi-Turn Chat-Based Editing
Before: One-shot generation. Want changes? Re-generate from scratch.
Now: Conversational iteration via chat API:
```python
chat = client.chats.create(model="gemini-3.1-flash-image-preview", ...)
response = chat.send_message("Generate a flowchart of auth")
response = chat.send_message("Make the boxes blue")  # Edits the previous image
```
Use case: Iterative diagram refinement without starting over.

### 7. New Interactions API
Before: Only `client.models.generate_content()`.
Now: Also `client.interactions.create()` with:
- Array-based multimodal input (text + images mixed)
- Built-in search tool integration
- Cleaner output filtering (`interaction.outputs` filtered by type)
```python
interaction = client.interactions.create(
    model="gemini-3.1-flash-image-preview",
    input=[
        {"type": "text", "text": "Generate a diagram..."},
        {"type": "image", "data": reference_b64, "mime_type": "image/png"}
    ],
    tools=[{"type": "google_search", "search_types": ["web_search"]}]
)
```

### 8. Expanded Aspect Ratios
Before: `1:1`, `3:2`, `9:16`, `16:9` (4 options)
Now: `1:1`, `1:4`, `1:8`, `2:3`, `3:2`, `3:4`, `4:1`, `4:3`, `4:5`, `5:4`, `8:1`, `9:16`, `16:9`, `21:9` (14 options)

Notable additions:
- `21:9` — ultrawide/cinema (great for banner diagrams)
- `4:5` — Instagram portrait
- `1:4` / `4:1` — extreme vertical/horizontal strips

### 9. Response Modalities
Before: Image-only response.
Now: Can return both text and images:
```python
config=types.GenerateContentConfig(response_modalities=['TEXT', 'IMAGE'])
```
The model describes what it generated alongside the image.

### 10. New Image Size Tier
Before: `1K`, `2K`
Now: `512` (0.5K, Flash only), `1K`, `2K`, `4K`
The `512` tier is ultra-cheap for thumbnails and previews.

---

## What Stayed the Same

- `generate_content` API still works (not deprecated)
- `image_config=types.ImageConfig(...)` parameter structure unchanged
- Response parsing: `part.inline_data` → `part.as_image()` → `.save()` unchanged
- Python SDK: `google-genai` package, same import structure
- API key authentication: same `Client(api_key=...)` pattern

---

## Migration Path

**Minimum change:** Swap default model from `gemini-3-pro-image-preview` to `gemini-3.1-flash-image-preview`. Everything else keeps working.

**Full upgrade:** Add 4K support, reference images, search grounding, iterative editing, expanded ratios, and thinking config. Update the interview protocol with new questions.

---

## Pricing Comparison

| Model | 1K Image | 2K Image | 4K Image |
|---|---|---|---|
| Nano Banana (v1, `gemini-2.5-flash-image`) | ~$0.039 | — | — |
| Nano Banana 2 (`gemini-3.1-flash-image-preview`) | ~$0.045 | ~$0.067 | ~$0.151 |
| Nano Banana Pro (`gemini-3-pro-image-preview`) | ~$0.134 | ~$0.134 | — |

Nano Banana 2 at 2K is **half the price** of Pro with comparable quality.
