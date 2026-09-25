# llama.cpp (pinned) + HauhauCS FastMTP patch, CUDA, for RunPod Serverless Load-Balancer endpoint
ARG CUDA_VERSION=12.4.1
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04 AS build
ARG LLAMA_COMMIT=4df29be4f4c3673f428170fda944a5b19f743bb8
ARG PATCH_URL=https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch
# 8.0 A100, 8.6 A6000/3090/A40, 8.9 L40S/6000 Ada/4090, 9.0 H100
ARG CUDA_ARCHS="80;86;89;90"
RUN apt-get update && apt-get install -y --no-install-recommends git cmake build-essential curl ca-certificates libcurl4-openssl-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp && git checkout ${LLAMA_COMMIT} \
 && curl -fL -o fastmtp.patch "${PATCH_URL}" && git apply --check fastmtp.patch && git apply fastmtp.patch
RUN cd llama.cpp && cmake -S . -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHS}" \
      -DLLAMA_CURL=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
 && cmake --build build --config Release -j"$(nproc)" --target llama-server \
 && mkdir -p /out && cp build/bin/llama-server /out/ && find build -name "*.so*" -exec cp -P {} /out/ \;

FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu22.04
RUN apt-get update && apt-get install -y --no-install-recommends libcurl4 libgomp1 python3 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /out/ /app/
COPY start.sh ping.py /app/
ENV LD_LIBRARY_PATH=/app PORT=8080 PORT_HEALTH=8081
EXPOSE 8080 8081
ENTRYPOINT ["/bin/bash","/app/start.sh"]
