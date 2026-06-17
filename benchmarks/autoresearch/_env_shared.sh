#!/usr/bin/env bash
# benchmarks/autoresearch/_env_shared.sh
# Shared env logic for autoresearch shards.
# Called from each shard's env.sh.
#
# Responsibility: prepare container filesystem only.
# - Stage wiki fixtures into the wiki vault (~/.openclaw/wiki/main/)
# - Link benchmarks/ into workspace for path resolution
# qa.jsonl is read by run_bench.py on the host — no need to stage it.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log() { printf '\n[autoresearch.env] %s\n' "$*"; }

# Bring up a fresh container for this shard.
if [[ -n "${BENCH_ENV_FILE:-}" && -f "${BENCH_ENV_FILE}" ]]; then
  . "${BENCH_ENV_FILE}"
  bench_force_recreate
fi
# ── 0. Fix API key ──
if [[ -n "${LLM_API_KEY:-}" ]]; then
  log "patching LLM_API_KEY directly into openclaw.json"
  docker exec "${BENCH_CONTAINER}" python3 -c "
import json, os
p = '/home/node/.openclaw/openclaw.json'
d = json.load(open(p))
prov = d.setdefault('models',{}).setdefault('providers',{}).setdefault('deepseek',{})
prov['apiKey'] = os.environ.get('LLM_API_KEY','')
json.dump(d, open(p,'w'), indent=2)
print('patched apiKey directly')
" 2>/dev/null
fi

# ── 1. Stage wiki fixtures into the wiki vault ─────────────────────
WIKI_VAULT="${BENCH_MOUNT}/wiki/main"
WIKI_SRC="${HERE}/wiki"

if [[ -d "${WIKI_SRC}" ]]; then
  log "staging wiki knowledge base (${WIKI_SRC}) -> ${WIKI_VAULT}"
  docker exec "${BENCH_CONTAINER}" mkdir -p "${WIKI_VAULT}"

  # Copy: tar from host into container. Use docker directly (not bench_container_cli)
  # because bash functions can fail inside pipes with set -euo pipefail.
  tar -C "${WIKI_SRC}" -cf - . 2>/dev/null | \
    docker exec -i "${BENCH_CONTAINER}" tar -xf - -C "${WIKI_VAULT}" 2>/dev/null || {
    log "WARNING: wiki staging via tar pipe failed, trying docker cp fallback"
    docker cp "${WIKI_SRC}/." "${BENCH_CONTAINER}:${WIKI_VAULT}/"
  }

  local wiki_count
  wiki_count="$(docker exec "${BENCH_CONTAINER}" find "${WIKI_VAULT}" -name '*.md' 2>/dev/null | wc -l)"
  log "staged ${wiki_count} wiki pages into vault"
else
  log "WARNING: wiki source not found at ${WIKI_SRC}"
fi

# ── 2. Link benchmarks/ into workspace ───
log "linking repo benchmarks into workspace"
docker exec "${BENCH_CONTAINER}" bash -lc \
  "for ws in workspace workspace/curate workspace/judge; do
     mkdir -p '${BENCH_MOUNT}/\${ws}'
     rm -f '${BENCH_MOUNT}/\${ws}/benchmarks'
     ln -s '${BENCH_MOUNT}/benchmarks' '${BENCH_MOUNT}/\${ws}/benchmarks'
   done" 2>/dev/null

log "env ready"
