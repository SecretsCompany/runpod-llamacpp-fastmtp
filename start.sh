#!/bin/bash
# Resolves GGUF files from RunPod model cache (or network volume) and starts llama-server.
set -u
REPO="${MODEL_REPO:-secretscompany/Qwen3.8-27B-Aggressive-MTP-Q4_K_P}"
QUANT_FILE="${QUANT_FILE:-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf}"
DRAFT_FILE="${DRAFT_FILE:-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf}"
MMPROJ_FILE="${MMPROJ_FILE:-mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf}"
touch /tmp/llama.starting
python3 /app/ping.py &
find_file() {  # $1 = filename; searches HF cache snapshot of $REPO, then /runpod-volume
  local base="/runpod-volume/huggingface-cache/hub/models--${REPO//\//--}"
  local ref; ref=$(cat "$base/refs/main" 2>/dev/null)
  for c in "$base/snapshots/$ref/$1" $(ls -d "$base"/snapshots/*/"$1" 2>/dev/null) "/runpod-volume/models/$1"; do
    [ -f "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}
MODEL=$(find_file "$QUANT_FILE") || { echo "FATAL: $QUANT_FILE not found"; ls -R /runpod-volume 2>/dev/null | head -50; rm -f /tmp/llama.starting; sleep 600; exit 1; }
ARGS=(--model "$MODEL" --host 0.0.0.0 --port "$PORT"
  --ctx-size "${CTX_SIZE:-131072}" --parallel "${PARALLEL:-1}"
  --n-gpu-layers all --split-mode none --flash-attn on --no-mmap
  --batch-size 2048 --ubatch-size 512 --jinja
  --temp 1.0 --top-k 20 --top-p 0.95 --min-p 0 --presence-penalty 0 --repeat-penalty 1.0
  --reasoning "${REASONING:-on}" --reasoning-effort "${REASONING_EFFORT:-medium}" --reasoning-preserve --reasoning-format deepseek
  --metrics)
if DRAFT=$(find_file "$DRAFT_FILE"); then
  ARGS+=(--spec-draft-model "$DRAFT" --spec-draft-ngl all --spec-type draft-mtp --spec-draft-n-max "${MTP_DEPTH:-3}" --spec-draft-p-min 0)
else
  ARGS+=(--spec-type draft-mtp --spec-draft-n-max 2)   # embedded MTP fallback
fi
MMP=$(find_file "$MMPROJ_FILE") && ARGS+=(--mmproj "$MMP")
# KV-cache precision: q8_0 halves KV memory (near-lossless) -> ~2x longer context on 24 GB cards
[ -n "${KV_TYPE:-}" ] && ARGS+=(--cache-type-k "$KV_TYPE" --cache-type-v "$KV_TYPE")
# agent loops resend a growing prompt: reuse the already-computed prefix instead of recomputing it
ARGS+=(--cache-reuse "${CACHE_REUSE:-256}")
[ -n "${API_KEY:-}" ] && ARGS+=(--api-key "$API_KEY")
[ -n "${EXTRA_ARGS:-}" ] && ARGS+=($EXTRA_ARGS)
echo "llama-server ${ARGS[*]}"
exec /app/llama-server "${ARGS[@]}"
