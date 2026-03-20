---
skill: serious-research
slug: nano-banana-2-update
status: done
parent:
created: 2026-03-20
classification: Feature
scope: Both
mode: Quick
---

# Nano Banana 2 Update

## Summary

Nano Banana 2 (`gemini-3.1-flash-image-preview`) launched February 26, 2026 as a major upgrade combining Pro-level quality with Flash-tier speed and pricing. Key new capabilities: 4K resolution output, subject consistency (up to 5 characters + 14 objects), Grounding with Google Image Search, precision text rendering, a new Interactions API (`client.interactions.create()`), thinking mode, expanded aspect ratios (14 options vs 4), and the `512` image size tier. The current serious-bananas SKILL.md has the model ID correct but is missing all the new capabilities and the Interactions API.

## Background

The serious-bananas skill currently supports two models: `gemini-3-pro-image-preview` (Nano Banana Pro, default) and `gemini-3.1-flash-image-preview` (Nano Banana 2, labeled as "faster/cheaper"). The skill uses the `generate_content` API with basic `image_config` parameters (aspect_ratio, image_size). Nano Banana 2 brings significant new capabilities that the skill doesn't expose.

## Findings

### Finding 1: Model Lineup Has Three Models Now

| Model ID | Name | Use Case | Pricing |
|---|---|---|---|
| `gemini-3.1-flash-image-preview` | Nano Banana 2 | Best balance of quality + speed. Pro-level 4K at Flash pricing | ~$0.045/1K, ~$0.067/std, ~$0.151/4K |
| `gemini-3-pro-image-preview` | Nano Banana Pro | Advanced reasoning, professional asset production | ~$0.134/image |
| `gemini-2.5-flash-image` | Nano Banana (v1) | High-volume, low-latency, budget | ~$0.039/image |

The current SKILL.md only lists Pro and Flash. The original `gemini-2.5-flash-image` (v1) still exists for budget use cases.

**Recommendation:** Default should change from Pro to Nano Banana 2. Pro is 2-3x more expensive with marginal quality improvement now that NB2 has 4K and subject consistency.

### Finding 2: New Image Sizes Including 4K

Old image_size values: `1K`, `2K`

New image_size values: `512` (0.5K, 3.1 Flash only), `1K`, `2K`, `4K`

4K is a headline feature of Nano Banana 2. The current skill hardcodes `image_size="2K"`. Should expose this as a user option.

### Finding 3: Massively Expanded Aspect Ratios

Old (in skill): `1:1`, `3:2`, `9:16`, `16:9` (4 options)

New (API supports): `1:1`, `1:4`, `1:8`, `2:3`, `3:2`, `3:4`, `4:1`, `4:3`, `4:5`, `5:4`, `8:1`, `9:16`, `16:9`, `21:9` (14 options)

Notable additions: `21:9` (ultrawide/cinema), `4:5` (Instagram portrait), `1:4`/`1:8`/`4:1`/`8:1` (extreme ratios for banners/strips).

### Finding 4: Reference Images for Subject Consistency

Nano Banana 2 can maintain character consistency across images using reference images:
- Up to 5 characters + 14 objects per workflow
- Images are base64-encoded and passed as input
- Best results with clear, well-lit headshots

This is huge for diagram series (consistent visual style across a set of related diagrams) and for any branded content.

### Finding 5: Grounding with Google Search (Web + Image)

New capability: the model can search Google (web and images) during generation for factual accuracy.

```python
tools=[{"type": "google_search", "search_types": ["web_search", "image_search"]}]
```

Use case: "Generate a diagram of the AWS us-east-1 region architecture" — the model can look up actual AWS service icons and region layouts.

### Finding 6: New Interactions API

A new API alongside `generate_content`:

```python
# Old API (still works)
resp = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=[prompt],
    config=types.GenerateContentConfig(
        image_config=types.ImageConfig(aspect_ratio="16:9", image_size="2K")
    ),
)

# New Interactions API
interaction = client.interactions.create(
    model="gemini-3.1-flash-image-preview",
    input="A cinematic travel poster for Kyoto...",
)
images = [output for output in interaction.outputs if output.type == "image"]
```

The Interactions API supports:
- Array-based multimodal input (text + images mixed)
- Built-in search tool integration
- Cleaner output filtering by type
- Reference image passing as array elements

### Finding 7: Thinking Mode

Nano Banana 2 has built-in thinking/reasoning before generating. It's on by default and cannot be disabled. You can control the level:

```python
thinking_config=types.ThinkingConfig(
    thinking_level="High",  # or "minimal"
    include_thoughts=True
)
```

This means the model reasons about the prompt before generating — useful for complex diagrams.

### Finding 8: Multi-Turn Chat-Based Image Editing

Supports conversational iteration through chat:

```python
chat = client.chats.create(
    model="gemini-3.1-flash-image-preview",
    config=types.GenerateContentConfig(
        response_modalities=['TEXT', 'IMAGE']
    )
)
response = chat.send_message("Generate a flowchart of our auth system")
# Then: "Make the boxes blue instead of green"
response = chat.send_message("Change the boxes to blue")
```

This is a game-changer for iterative diagram refinement — you don't re-generate from scratch, you have a conversation.

### Finding 9: Response Modalities

New config option to get both text and images:

```python
config=types.GenerateContentConfig(
    response_modalities=['TEXT', 'IMAGE']
)
```

Returns textual descriptions alongside the generated image. Useful for getting the model's interpretation of what it generated.

### Finding 10: Precision Text Rendering

"Capable of generating legible, stylized text" — this was a major weakness of v1 where text in diagrams was often garbled. Nano Banana 2 specifically targets readable text for infographics, marketing mockups, and diagrams with labels.

## Recommendations

1. **Change default model** from `gemini-3-pro-image-preview` to `gemini-3.1-flash-image-preview`. NB2 is cheaper, faster, and now matches Pro on quality with 4K support.

2. **Add 4K resolution option** to the interview (Question 4.5 or merge with Question 4). Options: 1K (fast/cheap), 2K (balanced, default), 4K (highest quality).

3. **Expand aspect ratio options** — add at minimum `21:9` (ultrawide), `4:5` (Instagram), `2:3`/`3:4` (portrait/landscape). Don't overwhelm with all 14 — keep the common ones.

4. **Add reference image support** — new interview question: "Do you have reference images for consistency?" Accept file paths, base64-encode them.

5. **Add search grounding option** — new interview question: "Should the model search Google for reference?" Useful for real-world subjects.

6. **Add iterative editing** — after generating, offer "Want to refine this? I can adjust specific elements." Uses the chat API for multi-turn editing.

7. **Keep the generate_content API** as the primary method (simpler, proven) but document the Interactions API as an alternative for advanced use cases.

8. **Add thinking level control** — default to "High" for diagrams (better reasoning about layouts).

9. **Update prompt suffixes** — remove "White or light background" from flowchart suffix (user may want dark mode). Make background a parameter.

10. **Add 3 models** to the model table instead of 2.

## References
- [Nano Banana Image Generation - Google AI Docs](https://ai.google.dev/gemini-api/docs/image-generation)
- [Nano Banana 2 Blog Post](https://blog.google/innovation-and-ai/technology/ai/nano-banana-2/)
- [Build with Nano Banana 2 - Developer Blog](https://blog.google/innovation-and-ai/technology/developers-tools/build-with-nano-banana-2/)
- [Nano Banana 2 Interactions API Guide](https://www.philschmid.de/nano-banana-2-interactions-api)
- [Gemini 3.1 Flash Image Preview Model Docs](https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-image-preview)
- [Complete Gemini Image API Guide 2026](https://blog.laozhang.ai/en/posts/gemini-image-api-guide-2026)
- [Nano Banana 2 API Guide - Medium](https://medium.com/@GrsAi.com/nano-banana-2-api-guide-ultra-fast-4k-image-generation-with-gemini-3-1-flash-only-0-065-image-c1eff36ac404)
