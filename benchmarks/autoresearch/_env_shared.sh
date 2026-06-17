#!/usr/bin/env bash
# benchmarks/autoresearch/_env_shared.sh
# Shared env logic for autoresearch shards.
# Called from each shard's env.sh.
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
import json, os
p='/home/node/.openclaw/openclaw.json'
d=json.load(open(p))
prov=d.setdefault('models',{}).setdefault('providers',{}).setdefault('deepseek',{})
prov['apiKey']=os.environ.get('LLM_API_KEY','')
json.dump(d,open(p,'w'),indent=2)
" 2>/dev/null
fi

# ── 1. Stage wiki into vault ──
WIKI_SRC="${HERE}/wiki"
WIKI_VAULT="/home/node/.openclaw/wiki/main"

if [[ -d "${WIKI_SRC}" ]]; then
  log "staging wiki: ${WIKI_SRC} -> ${WIKI_VAULT}"
  bench_container_cli exec "${BENCH_CONTAINER}" mkdir -p "${WIKI_VAULT}"
  tar -C "${WIKI_SRC}" -cf - . 2>/dev/null | \
    bench_container_cli exec -i "${BENCH_CONTAINER}" tar -xf - -C "${WIKI_VAULT}" 2>/dev/null || true
  n=$(bench_container_cli exec "${BENCH_CONTAINER}" find "${WIKI_VAULT}" -name '*.md' 2>/dev/null | wc -l)
  log "staged ${n} wiki pages into vault"
else
  log "WARNING: wiki dir not found: ${WIKI_SRC}"
fi

# ── 2. Link benchmarks/ into workspace ──
log "linking benchmarks into workspace"
bench_container_cli exec "${BENCH_CONTAINER}" bash -lc \
  "for ws in workspace workspace/curate workspace/judge; do
     mkdir -p '/home/node/.openclaw/\${ws}'
     rm -f '/home/node/.openclaw/\${ws}/benchmarks'
     ln -s /home/node/.openclaw/benchmarks '/home/node/.openclaw/\${ws}/benchmarks'
   done" 2>/dev/null || true

log "env ready"
