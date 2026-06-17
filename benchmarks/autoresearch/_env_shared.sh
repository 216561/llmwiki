#!/usr/bin/env bash
# benchmarks/autoresearch/_env_shared.sh
# Shared env logic for autoresearch shards.
# Called from each shard's env.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log() { printf '\n[autoresearch.env] %s\n' "$*"; }

# Use the container from env_setup directly — no force_recreate.
# This avoids container-name/env-var issues after recreation.
CTR="${BENCH_CONTAINER:-openclaw-bench}"

# ── 0. Verify container is running ──
if ! docker ps --format '{{.Names}}' | grep -q "^${CTR}$"; then
  log "ERROR: container ${CTR} not running"
  exit 1
fi

# ── 1. Fix API key ──
log "patching LLM_API_KEY"
docker exec "${CTR}" python3 -c "
import json, os
p='/home/node/.openclaw/openclaw.json'
d=json.load(open(p))
prov=d.setdefault('models',{}).setdefault('providers',{}).setdefault('deepseek',{})
prov['apiKey']=os.environ.get('LLM_API_KEY','')
json.dump(d,open(p,'w'),indent=2)
" 2>/dev/null

# ── 2. Stage wiki into vault ──
WIKI_SRC="${HERE}/wiki"
WIKI_VAULT="/home/node/.openclaw/wiki/main"

if [[ -d "${WIKI_SRC}" ]]; then
  log "staging wiki: ${WIKI_SRC} -> ${WIKI_VAULT}"
  docker exec "${CTR}" mkdir -p "${WIKI_VAULT}"
  docker cp "${WIKI_SRC}/." "${CTR}:${WIKI_VAULT}/" 2>/dev/null
  n=$(docker exec "${CTR}" find "${WIKI_VAULT}" -name '*.md' 2>/dev/null | wc -l)
  log "staged ${n} wiki pages into vault"
else
  log "WARNING: wiki dir not found: ${WIKI_SRC}"
fi

# ── 3. Symlink benchmarks into workspace ──
log "linking benchmarks into workspace"
docker exec "${CTR}" bash -lc \
  "for ws in workspace workspace/curate workspace/judge; do
     mkdir -p \"/home/node/.openclaw/\${ws}\"
     rm -f \"/home/node/.openclaw/\${ws}/benchmarks\"
     ln -s /home/node/.openclaw/benchmarks \"/home/node/.openclaw/\${ws}/benchmarks\"
   done" 2>/dev/null

log "env ready"
