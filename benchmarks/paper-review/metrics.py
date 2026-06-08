#!/usr/bin/env python3
"""benchmarks/paper-review/metrics.py — invokes `main`; main must delegate to
`paper-review` per QA via target_agent. This benchmark scores the final
paper-review Markdown answer; wiki ingest/read is covered by integration
benchmarks, not this single-agent skill benchmark.
To regenerate qa.jsonl from the existing seed_qa.json:
  python3 benchmarks/paper-review/build_qa.py
"""
import sys
from pathlib import Path

BENCH_NAME = "paper-review"


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "_common"))
    from run_bench import main  # noqa: E402

    sys.exit(main(BENCH_NAME, agent_id="main"))
