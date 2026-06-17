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

HERE="$(cd "$(dirname "$0")" && pwd)"
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

# ── 0. Fix API key: write directly (SecretRef fails with gateway snapshot) ──
if [[ -n "${LLM_API_KEY:-}" ]]; then
  log "patching LLM_API_KEY directly into openclaw.json"
  bench_container_cli exec "${BENCH_CONTAINER}" python3 -c "
import json, os
p = '/home/node/.openclaw/openclaw.json'
d = json.load(open(p))
prov = d.setdefault('models',{}).setdefault('providers',{}).setdefault('deepseek',{})
prov['apiKey'] = os.environ.get('LLM_API_KEY','')
json.dump(d, open(p,'w'), indent=2)
print('patched apiKey directly')
"
fi

# ── 1. Stage wiki fixtures into the wiki vault ─────────────────────
# openclaw.json configures memory-wiki vault at ~/.openclaw/wiki/main.
# QA prompts reference wiki files via this vault path.
WIKI_VAULT="${BENCH_MOUNT}/wiki/main"
WIKI_SRC="${HERE}/wiki"

if [[ -d "${WIKI_SRC}" ]]; then
  log "staging wiki knowledge base -> ${WIKI_VAULT}"
  bench_container_cli exec "${BENCH_CONTAINER}" mkdir -p "${WIKI_VAULT}"

  # Copy the entire wiki tree into the vault
  tar -C "${WIKI_SRC}" -cf - . | \
    bench_container_cli exec -i "${BENCH_CONTAINER}" tar -xf - -C "${WIKI_VAULT}"

  local wiki_count
  wiki_count="$(find "${WIKI_SRC}" -name '*.md' | wc -l)"
  log "staged ${wiki_count} wiki pages into vault"
fi

# ── 2. Link benchmarks/ into workspace for agent path resolution ───
# QA prompts reference benchmarks/autoresearch/wiki/* paths.
# OpenClaw tools resolve relative paths from the workspace root.
log "linking repo benchmarks into workspace"
bench_container_cli exec "${BENCH_CONTAINER}" bash -lc \
  "for ws in workspace workspace/curate workspace/judge; do
     mkdir -p '${BENCH_MOUNT}/\${ws}'
     rm -f '${BENCH_MOUNT}/\${ws}/benchmarks'
     ln -s '${BENCH_MOUNT}/benchmarks' '${BENCH_MOUNT}/\${ws}/benchmarks'
   done"

log "env ready"
