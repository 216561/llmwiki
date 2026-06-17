#!/usr/bin/env bash
# benchmarks/autoresearch/_env_shared.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log() { printf '\n[autoresearch.env] %s\n' "$*"; }

# Bring up a fresh container for this shard.
if [[ -n "${BENCH_ENV_FILE:-}" && -f "${BENCH_ENV_FILE}" ]]; then
  . "${BENCH_ENV_FILE}"
  bench_force_recreate
fi
if ! declare -F bench_container_cli >/dev/null; then
  bench_container_cli() {
    local cli="${BENCH_CONTAINER_CLI:-${BENCH_CONTAINER_RUNTIME:-docker}}"
    [[ "${cli}" == "auto" ]] && cli=docker
    "${cli}" "$@"
  }
fi

# ── 0. Fix API key ──
if [[ -n "${LLM_API_KEY:-}" ]]; then
  log "patching LLM_API_KEY"
  bench_container_cli exec "${BENCH_CONTAINER}" python3 -c "
import json,os
p='/home/node/.openclaw/openclaw.json'
d=json.load(open(p))
prov=d.setdefault('models',{}).setdefault('providers',{}).setdefault('deepseek',{})
prov['apiKey']=os.environ.get('LLM_API_KEY','')
json.dump(d,open(p,'w'),indent=2)
" 2>/dev/null || true
fi

# ── 1. Copy wiki directly to both locations the agent might look ──
WIKI_SRC="${HERE}/wiki"
if [[ -d "${WIKI_SRC}" ]]; then
  n=$(find "${WIKI_SRC}" -name '*.md' | wc -l)
  log "copying ${n} wiki pages into container..."

  # Path A: wiki vault
  bench_container_cli exec "${BENCH_CONTAINER}" mkdir -p /home/node/.openclaw/wiki/main
  bench_container_cli cp "${WIKI_SRC}/." "${BENCH_CONTAINER}:/home/node/.openclaw/wiki/main/" 2>/dev/null || true

  # Path B: benchmarks tree (where QA paths point)
  bench_container_cli exec "${BENCH_CONTAINER}" mkdir -p /home/node/.openclaw/benchmarks/autoresearch/wiki
  bench_container_cli cp "${WIKI_SRC}/." "${BENCH_CONTAINER}:/home/node/.openclaw/benchmarks/autoresearch/wiki/" 2>/dev/null || true

  log "wiki copied to container"
else
  log "WARNING: wiki dir not found: ${WIKI_SRC}"
fi

log "env ready"
