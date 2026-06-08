# Benchmark: Paper Review

**Agent:** main  
**Judge:** reviewer agent (`judge: "agent"`)  
**Seeds:** 24 independent QA items

## Purpose

Evaluate the `paper-review` sub-agent's stage skills through the standard main
entrypoint. Each QA is sent to main, which produces the final answer directly;
the benchmark scores the Markdown answer body. This benchmark answers: can the
paper-review stage skills produce stage-specific, downstream-consumable Markdown
answers when given controlled inputs?

Full manager orchestration, cross-stage runtime chaining, wiki-read integration,
and artifact persistence are evaluated separately in `benchmarks/paper-review-pipeline/`.

## Wiki / S1 Boundary

- **S1 wiki entry generation** is the responsibility of the `autoresearch`
  sub-agent, tested by `benchmarks/paper-ingest/` and `benchmarks/autoresearch/`.
- **This benchmark does NOT test wiki read.** QA inputs are staged fixture
  materials (paper full text) and inline upstream summaries ("上游 Wiki 摘要",
  "上游实验提取摘要", etc.). No QA references `wiki/` file paths.
- The wiki system uses isolated mode (per-agent wikis are independent). A
  true wiki→S2 read integration test requires explicit fixture sharing and
  belongs in `benchmarks/paper-review-pipeline/` or a dedicated integration
  benchmark.

## Skills Under Test

| Skill | QA IDs | What It Tests |
| --- | --- | --- |
| `paper-experiment-deep-extractor` | `s2-*` | Structured experiment extraction, incomplete evidence discipline, cross-paper comparison, nonstandard paper layout |
| `paper-review-style-problem-analyzer` | `s3-*` | Review-style problem analysis, cherry-picking, baseline fairness, competing hypotheses, scope boundaries, dependency audit, negative results, contradictory inputs |
| `paper-validation-experiment-designer` | `s4-*` | Validation design, budget tradeoffs, minimal experiments, contradiction adjudication |
| `claude-code-validation-task-prompt-generator` | `s5-*` | Prompt generation, missing repo handling, precise repo path targeting, experiment prioritization |
| `paper-pipeline-quality-auditor` | `s6-*` | Single-stage audit, cross-stage consistency, boundary violations, full pipeline audit |

## Procedure

1. `env.sh` stages `qa.jsonl` and paper materials into the benchmark container.
2. `metrics.py` calls `run_bench.py` with `agent_id="main"`.
3. `run_bench.py` wraps each QA prompt with a `[BENCHMARK DIRECTIVE]`
   instructing main to produce the complete final output directly.
4. `judge_with_agent` invokes the dedicated `reviewer` agent to score against
   `gold_answer`, `rubric`, and `rubric_dimensions`.

## Input Sources

QA inputs use two mechanisms (see `qa.jsonl` `input_material` field):

1. **Staged fixture materials** — paper full text copied into the container
   by `env.sh` from `benchmarks/paper-review/materials/`. Referenced by
   relative path (e.g. `benchmarks/paper-review/materials/react_full.md`).
2. **Inline upstream summaries** — hand-written summaries embedded directly
   in the QA JSON, labelled "上游 Wiki 摘要", "上游实验提取摘要",
   "上游问题分析摘要", or "上游验证设计摘要". These simulate the output
   of prior pipeline stages without requiring actual wiki reads.

No QA reads from the `wiki/` filesystem. Wiki ingest (S1) is tested by
`benchmarks/paper-ingest/`; wiki→S2 integration belongs in
`benchmarks/paper-review-pipeline/`.

## Evaluation Notes

- Every QA is independent; no QA consumes a prior QA's actual output.
- This benchmark scores the final Markdown answer body. It does not require
  per-QA files to be written; artifact checks belong to pipeline benchmarks.
- S6 cases in this benchmark use controlled, hand-written upstream artifacts.
  Real end-to-end S6 audits belong in `paper-review-pipeline`.
- Normal cases intentionally enforce exact Markdown section contracts. A deep
  prose answer that cannot be consumed by the next stage should fail.
- Missing or contradictory information must be explicitly marked instead of
  repaired by speculation.
- **Wiki import failure does NOT short-circuit this benchmark.** The wiki
  import block in `env.sh` is disabled; `metrics.py` does not check for
  `.wiki-import-failed`.

## Current Matrix

| Stage | Count | IDs |
| --- | ---: | --- |
| S2 | 5 | `s2-incomplete`, `s2-nonstandard`, `s2-toolformer`, `s2-vpt`, `s2-negative-missing-paper` |
| S3 | 12 | `s3-cherrypick`, `s3-baseline`, `s3-competing`, `s3-scope`, `s3-dependency`, `s3-negative`, `s3-tot-competing`, `s3-tot-scope`, `s3-sr-dependency`, `s3-sr-negative`, `s3-ta-competing`, `s3-ta-scope` |
| S4 | 2 | `s4-budget`, `s4-minimal` |
| S5 | 2 | `s5-norepo`, `s5-largerepo` |
| S6 | 2 | `s6-boundary-new`, `s6-cross-new` |

## Seed Reference

### S2 — Experiment Extraction

| ID | Paper | Focus |
| --- | --- | --- |
| `s2-incomplete` | FedAux | Incomplete ablation reporting; agent must surface what is missing without fabrication |
| `s2-nonstandard` | ReAct | Nonstandard paper layout (multi-benchmark); agent must extract across 4 heterogeneous task domains |
| `s2-toolformer` | Toolformer | Self-supervised API learning experiments; decoding strategy and data quality ablations |
| `s2-vpt` | VPT | Visual prompt tuning across FGVC + VTAB-1k; prompt design ablations across backbones |
| `s2-negative-missing-paper` | (negative control) | Input references a non-existent paper; agent must refuse gracefully rather than hallucinate |

### S3 — Problem Analysis

| ID | Paper | Dimension | Focus |
| --- | --- | --- | --- |
| `s3-cherrypick` | FedAux | cherry_picking | Best-case vs average performance selective reporting |
| `s3-baseline` | FedAux | baseline_fairness | Baseline tuning budget asymmetry; comparison fairness |
| `s3-competing` | FedAux | competing_hypotheses | Alternative explanations for claimed improvements |
| `s3-scope` | FedAux | scope_boundary | Single-benchmark claim generalization |
| `s3-dependency` | ReAct | dependency_audit | Wikipedia API / environment interface external dependencies |
| `s3-negative` | ReAct | negative_balance | HotpotQA loss to CoT (27.4 vs 29.4); fair negative result treatment |
| `s3-tot-competing` | ToT | competing_hypotheses | Tree search vs. larger token budget alternative explanations |
| `s3-tot-scope` | ToT | scope_boundary | 3-task scope vs. general problem-solving claim |
| `s3-sr-dependency` | Self-Refine | dependency_audit | Self-feedback quality dependence on model capability |
| `s3-sr-negative` | Self-Refine | negative_balance | Acronym generation +0.2%; near-zero improvement cases |
| `s3-ta-competing` | Tip-Adapter | competing_hypotheses | Cache model vs. fine-tuning alternative explanations |
| `s3-ta-scope` | Tip-Adapter | scope_boundary | Training-free claim boundaries across shot counts |

### S4 — Validation Design

| ID | Paper | Focus |
| --- | --- | --- |
| `s4-budget` | FedAux | Design validation experiments under constrained compute budget; must prioritize and justify |
| `s4-minimal` | ReAct | Design minimal single-variable experiments; contaminate with irrelevant upstream context that must be ignored |

### S5 — Claude Code Prompt Generation

| ID | Paper | Focus |
| --- | --- | --- |
| `s5-norepo` | FedAux | Missing code repository; must use placeholder `此处应填写代码仓库路径` without fabrication |
| `s5-largerepo` | ReAct | Real large codebase (`react-lm.github.io`); must target specific files, not vague directories |

### S6 — Pipeline Quality Audit

| ID | Focus |
| --- | --- |
| `s6-boundary-new` | Stage boundary violations; audit an S3 output that illegally performs S4 validation design |
| `s6-cross-new` | Cross-stage consistency; audit S2→S3→S4 chain for orphaned claims and evidence drift |
