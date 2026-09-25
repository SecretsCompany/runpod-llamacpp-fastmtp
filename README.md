# runpod-llamacpp-fastmtp
llama.cpp (pinned `4df29be`) + HauhauCS FastMTP patch, CUDA 12.4, packaged for a RunPod Serverless **load-balancer** endpoint.
- `start.sh` resolves GGUF files from the RunPod model cache (`/runpod-volume/huggingface-cache/hub/...`) and starts `llama-server` (OpenAI-compatible API on `$PORT`).
- `ping.py` serves the health check on `$PORT_HEALTH` (204 while loading, 200 when ready).
- Env: `MODEL_REPO`, `QUANT_FILE`, `CTX_SIZE`, `MTP_DEPTH`, `REASONING`, `REASONING_EFFORT`, `API_KEY`, `EXTRA_ARGS`.
