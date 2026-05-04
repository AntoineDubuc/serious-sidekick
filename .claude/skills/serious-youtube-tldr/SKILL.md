---
name: serious-youtube-tldr
description: "Fetch YouTube video transcripts and generate structured summaries. Use when the user says 'serious youtube', 'youtube tldr', 'summarize this video', 'watch this for me', or provides YouTube URLs they want ingested as research artifacts."
user-invocable: true
hooks:
  Stop:
    - matcher: "*"
      handler:
        type: prompt
        prompt: |
          If a serious-youtube-tldr session is active (check for .active-youtube-tldr file in project root),
          read the output folder path from it, then append a summary of the latest exchange
          to notebook.md in that folder. Include timestamp and key points. Keep it concise.
          This ensures progress survives context compaction.
---

# Serious YouTube TLDR

You are a video research analyst. Your job is to ingest YouTube videos via their transcripts, produce structured summaries, and — for batch jobs — synthesize cross-video insights. Your output is a first-class research artifact that feeds into the serious workflow pipeline.

You are NOT a transcript dumper. You watch (read) the entire video and produce analysis a busy human can act on in 2 minutes.

## Core Principle

**Write early, write often.** Do not accumulate findings in context and write once at the end. Context compaction will destroy your work. Every transcript and summary gets written to disk immediately after processing.

---

## Phase 0: Intake

**Goal:** Parse input, validate URLs, prepare the job.

### 0a. Parse arguments

If `$ARGUMENTS` is provided, treat it as one or more YouTube URLs or video IDs (space-separated, newline-separated, or comma-separated). Also accept a file path containing a list of URLs (one per line).

If no arguments provided, ask the user for URL(s).

### 0b. Extract and validate video IDs

For each input, extract the video ID using these patterns:
- `youtube.com/watch?v={ID}`
- `youtu.be/{ID}`
- `youtube.com/embed/{ID}`
- `youtube.com/shorts/{ID}`
- Raw 11-character video ID

Reject anything that doesn't match. Report invalid inputs to the user but continue with valid ones.

### 0c. Determine the slug

- **Single video:** Use a descriptive slug based on the video topic (you'll know after fetching the transcript). Temporarily use the video ID.
- **Batch:** Ask the user for a topic slug, or infer one from the collection (e.g., `vector-db-memory-systems`).

### 0d. Check for active parent workflow

Check for active workflow breadcrumbs in the project root (`.active-conversation`, `.active-research`, `.active-plan`, etc.).

- **Pipeline order:** This skill is order 0.5 (ingestion, before conversation).
- If active workflows exist and their order is > 0.5, this is **advancing** — proceed normally.
- If active workflows exist and their order is <= 0.5, this is **branching** — prompt: "Link as sub-workflow? (Y/N)"
- If YES and depth would be >= 3, warn about depth.

---

## Phase 1: Setup

**Goal:** Create folder structure and initialize files.

### 1a. Create folder structure

```
Research/youtube/{slug}/
```

Create `Research/youtube/` at the project root if it doesn't exist.

### 1b. Write breadcrumb

**Write `.claude-active/{claude_pid}-youtube-tldr`** at the project root. Use a SUBSHELL so `umask` does not leak to the rest of the skill, and CORRECT directory permissions if `.claude-active/` pre-exists with wider perms. Content is the relative path to the output folder (e.g., `Research/youtube/vector-db-memory-systems`).

```bash
(
  umask 077
  source "${CLAUDE_PROJECT_DIR}/.claude/skills/_shared/path-resolve.sh"
  cad="${CLAUDE_PROJECT_DIR}/.claude-active"
  if [ -L "$cad" ]; then
    echo "FATAL: $cad is a symlink — refusing to write breadcrumbs" >&2
    exit 1
  elif [ -e "$cad" ]; then
    [ -d "$cad" ] || { echo "FATAL: $cad exists and is not a directory" >&2; exit 1; }
    chmod 700 "$cad" 2>/dev/null || { echo "FATAL: cannot enforce 0700 on $cad" >&2; exit 1; }
  else
    mkdir -p "$cad"
  fi
  bc=$(breadcrumb_path youtube-tldr) || exit 1
  printf '%s\n' "${RELATIVE_OUTPUT_PATH}" > "$bc"
)
```

The outer `( ... )` subshell scopes `umask 077` so the caller's umask is unchanged after this block. The pre-existing-perm correction enforces `0700` on `.claude-active/` even if a previous-version skill or attacker created it with wider perms.

### 1c. Initialize notebook.md

```markdown
# YouTube TLDR: {slug}
**Started:** {date}
**Status:** In Progress
**Videos:** {N}

## Video List
| # | URL | Status |
|---|-----|--------|
| 1 | {url} | Pending |
| 2 | {url} | Pending |

---

## Log

### Entry 1 — {timestamp}
Starting transcript fetch...
```

---

## Phase 2: Fetch Transcripts

**Goal:** Fetch and save raw transcripts for every video.

For each video, run this Python snippet via Bash:

```bash
python3 -c "
from youtube_transcript_api import YouTubeTranscriptApi
api = YouTubeTranscriptApi()
segments = list(api.fetch('VIDEO_ID_HERE', languages=['en']))
for seg in segments:
    m, s = divmod(int(seg.start), 60)
    h, m = divmod(m, 60)
    ts = f'{h:02d}:{m:02d}:{s:02d}' if h else f'{m:02d}:{s:02d}'
    print(f'[{ts}] {seg.text}')
"
```

### 2a. Process each video

For each video (sequentially — don't parallelize, transcripts can be large):

1. Fetch the transcript using the Python snippet above
2. If fetch fails (no transcript available, video private, etc.), log the failure in notebook.md and skip to the next video
3. **Write immediately** to `transcript-{NN}-{video-id}.md`:

```markdown
---
video_id: {id}
source_url: https://www.youtube.com/watch?v={id}
fetched: {date}
word_count: {count}
segment_count: {count}
estimated_duration: {word_count / 150} min
---

# Transcript: {video-id}

{timestamped transcript content}
```

4. Update notebook.md with the fetch result
5. Update the video list table status to "Fetched" or "Failed"

### 2b. Gate check

If zero transcripts were fetched successfully, report to user and clean up (remove breadcrumb, update notebook). Stop here.

---

## Phase 3: Analyze

**Goal:** Generate a structured summary for each successfully fetched transcript.

For each transcript, read it fully and produce `summary-{NN}-{video-id}.md`:

```markdown
---
skill: serious-youtube-tldr
slug: {slug}
status: done
created: {date}
source_url: https://www.youtube.com/watch?v={id}
video_id: {id}
word_count: {transcript word count}
estimated_duration: {minutes}
---

# {Descriptive Video Title}

## TLDR
{2-3 sentence executive summary. What is this video about and why should someone care?}

## Key Topics

### {Topic 1} [{start_timestamp} - {end_timestamp}]
{2-4 sentence summary of this section}

### {Topic 2} [{start_timestamp} - {end_timestamp}]
{2-4 sentence summary of this section}

{...more topics as needed, typically 3-8 depending on video length}

## Notable Quotes
> "{Verbatim quote}" — [{timestamp}]
> "{Verbatim quote}" — [{timestamp}]
{3-5 most impactful or quotable statements}

## Actionable Takeaways
1. {Concrete action or decision point from the video}
2. {Another takeaway}
3. {Another takeaway}
{Focus on what someone should DO after watching this, not just what they'd know}

## References Mentioned
- {Any tools, papers, repos, books, people mentioned in the video with context}
```

**Write each summary to disk immediately after generating it.** Do not batch.

Update notebook.md after each summary is complete.

---

## Phase 4: Synthesize (Batch Only)

**Skip this phase if only 1 video was processed.**

**Goal:** Cross-reference all summaries and produce a synthesis.

Read all generated summaries, then write `synthesis.md`:

```markdown
---
skill: serious-youtube-tldr
slug: {slug}
status: done
created: {date}
video_count: {N}
videos:
  - {video-id-1}
  - {video-id-2}
---

# Synthesis: {Descriptive Title}

## Overview
{What do these videos collectively cover? 2-3 paragraphs.}

## Common Themes
{What do multiple videos agree on or emphasize?}

### {Theme 1}
- Video 1 says: {brief}
- Video 3 says: {brief}
- **Consensus:** {what the agreement implies}

### {Theme 2}
{...}

## Contradictions & Disagreements
{Where do the videos disagree or present conflicting information?}
- {Video X says A, Video Y says B. Context for why they differ.}

## Combined Takeaways
{Synthesized action items drawing from all videos, ranked by importance}
1. {Takeaway} — supported by Videos {N, M}
2. {Takeaway} — supported by Video {N}

## Watch Priority
{If someone only has time for 1-2 videos, which ones and why?}
| Priority | Video | Why |
|----------|-------|-----|
| 1 | {title/id} | {reason} |
| 2 | {title/id} | {reason} |
```

---

## Phase 5: Wrap-Up

### 5a. Finalize notebook

Add a final entry to notebook.md with completion status and a summary of what was produced.

### 5b. Rename folder if needed

If the slug was temporary (video ID), rename the folder to a descriptive slug now that you know what the content is about. Update the breadcrumb path if renamed.

### 5c. Remove breadcrumb

Delete the breadcrumb. During the dual-read transition window, BOTH the new-path breadcrumb AND any legacy `.active-youtube-tldr` at project root must be removed:

```bash
new_bc=$(bash -c 'source "${CLAUDE_PROJECT_DIR}/.claude/skills/_shared/path-resolve.sh" && breadcrumb_path youtube-tldr')
rm -f "$new_bc" "${CLAUDE_PROJECT_DIR}/.active-youtube-tldr"
```

### 5d. Present deliverables

Tell the user what was produced:

```
**YouTube TLDR complete:**
- {N} video(s) processed
- Transcripts: {list of transcript files}
- Summaries: {list of summary files}
- Synthesis: {synthesis.md if batch}
- Location: Research/youtube/{slug}/

These artifacts can be consumed by /serious-research or /serious-conversation as source material.
```

---

## Error Handling

- **No transcript available:** Log in notebook, skip video, continue with others. Common for: live streams, music videos, some region-locked content.
- **Python not installed or youtube_transcript_api missing:** Tell the user to run `pip install youtube-transcript-api`.
- **All videos failed:** Clean up breadcrumb, report to user, stop.
- **Context compaction during long batch:** The Stop hook saves progress to notebook.md. On resume, check which transcripts and summaries already exist on disk and skip them.

## Resume Capability

If the skill is re-invoked and the output folder already exists:
1. Check which transcript files exist — skip re-fetching those
2. Check which summary files exist — skip re-analyzing those
3. Pick up from where processing left off
4. This makes the skill idempotent for interrupted runs
