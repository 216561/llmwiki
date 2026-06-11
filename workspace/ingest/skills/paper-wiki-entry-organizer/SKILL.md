---
name: paper-wiki-entry-organizer
description: Paper PDF ingestion workflow for the Ingest agent. Convert a PDF into a structured wiki paper page following the 11-section template with full evidence traceability.
---

# Paper Wiki Entry Organizer

## Purpose

Use this skill to ingest a research paper PDF and create a structured wiki paper page. The Ingest agent invokes this skill as its single core capability: Paper PDF ingestion → wiki page creation.

## When To Use

Use this skill when:
- A new paper PDF needs to be added to the wiki
- A user (main agent 颖姗 or end user) requests "ingest this paper" or "add this paper to the wiki"
- raw/inbox/ contains a paper that needs to be processed

Do not use this skill for:
- Literature queries (those are handled by the curate agent)
- Cross-paper comparisons (those are handled by the curate agent)
- Wiki quality audits (those are handled by the curate agent)

## Inputs

Collect or infer these fields before ingestion:
- `pdf_path`: path to the source PDF (raw/inbox/ or raw/sources/)
- `target_domain`: which domain subtree the paper belongs to
- `evidence_level`: based on PDF access (default: full-paper if full text extracted)

## Output Contract

After successful ingestion, the following should exist:

```text
raw/sources/YYYY-MM-DD-short-title.pdf
raw/sources/YYYY-MM-DD-short-title.txt   # extracted full text
```

Wiki side effects (via `wiki_apply` / `wiki_get` tools, not filesystem writes):
- A structured paper page created under the target domain (slug: `<slug>`)
- wiki index updated (add paper entry under domain)
- wiki log appended (format: `## [YYYY-MM-DD] ingest | Paper Title`)

The paper page must include:
- All frontmatter fields (title, type, domain, status, created, updated, tags, source_pages, raw_sources, related_pages)
- Paper-specific frontmatter (paper.title, paper.authors, paper.year, paper.venue, paper.arxiv, paper.doi, paper.code, classification.*, evidence_level)
- All 11 sections (Citation, One-Sentence Contribution, Problem Setting, Method, Experiments, Results, Limitations, Reusable Claims, Connections, Open Questions, Provenance)

## Ingestion Workflow (Execute-Verify-Report)

### Step 1: Capture
1. Move the PDF to raw/sources/ with canonical naming `YYYY-MM-DD-short-title.pdf`
2. **Verify**: file exists, is readable, size > 0
3. On failure: retry once (check path/permissions), then report and stop

### Step 2: Extract
1. Extract full text to raw/sources/`YYYY-MM-DD-short-title.txt`
2. **Verify**: text has sufficient length, contains paper structure (sections, references)
3. On failure: try alternative extraction once, then report and stop

### Step 3: Create Paper Page
1. Use `wiki_apply` to create the paper page under the target domain with the 11-section template (see references/page-templates.md)
2. Fill all frontmatter fields; set `evidence_level` based on coverage
3. **Verify**: page >=100 lines, has evidence_level, Results has concrete numbers (use `wiki_get` to re-read)
4. On failure: re-read source and fill missing parts, max 1 retry

### Step 4: Update Index
1. Use `wiki_apply` to update the wiki index (add paper page entry under domain)
2. Use `wiki_apply` to append a log entry with format `## [YYYY-MM-DD] ingest | Paper Title`
3. **Verify**: use `wiki_get` to confirm index links correct, log is append-only
4. On failure: stop and report

## Minimum Acceptable Output

- One raw source captured
- One full-text extraction completed
- One paper page created via wiki tools (>=100 lines, has evidence_level, Results has concrete numbers)
- Wiki index and log updated via wiki tools

## Quality Rules

- No fabricated claims — every claim traces to a paper page section
- Experiments must include dataset sizes, baseline names, training hyperparameters
- Results must include concrete numbers for every main claim (no "significantly outperforms SOTA")
- Pages in Chinese; preserve original paper title, authors, DOI, arXiv, code links
- Mark missing information as "not reported in the source"
- Update existing pages rather than creating duplicates

## Safety Rules

- Never modify raw/ files
- Mark uncertain content as "待验证"
- Confirm before destructive operations (delete, rename, mass refactor)
- Do not leak paper PDF content externally
