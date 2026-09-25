"""Create the RunPod Serverless LB endpoint for Qwen3.8-27B (needs balance >= $0.01).
Usage: python3 deploy_endpoint.py   (reads /home/claude/.runpod_api_key, /home/claude/.runpod_ids)"""
import json, requests
K = open("/home/claude/.runpod_api_key").read().strip()
ids = json.load(open("/home/claude/.runpod_ids"))
q = """mutation S($input: EndpointInput!){ saveEndpoint(input:$input){ id name gpuIds workersMin workersMax idleTimeout type modelReferences templateId } }"""
inp = {"name": "qwen38-27b-agent", "templateId": ids["template_id"],
       "gpuIds": "ADA_24,AMPERE_24,-NVIDIA L4", "gpuCount": 1,       # 4090, then 3090/A5000; L4 excluded (slow memory)
       "workersMin": 0, "workersMax": 1, "idleTimeout": 600,          # 1 warm worker keeps agent prefix cache; off after 10 min idle
       "flashBootType": "FLASHBOOT", "scalerType": "REQUEST_COUNT", "scalerValue": 1,
       "type": "LB", "minCudaVersion": "12.4",
       "modelReferences": ["https://huggingface.co/secretscompany/Qwen3.8-27B-Aggressive-MTP-Q4_K_P:main"]}
r = requests.post("https://api.runpod.io/graphql?api_key=" + K, json={"query": q, "variables": {"input": inp}}, timeout=60).json()
print(json.dumps(r, ensure_ascii=False, indent=1))
ep = (r.get("data") or {}).get("saveEndpoint")
if ep:
    ids["endpoint_id"] = ep["id"]; json.dump(ids, open("/home/claude/.runpod_ids", "w"))
    print(f"OpenAI base URL: https://{ep['id']}.api.runpod.ai/v1  (Authorization: Bearer <RUNPOD_API_KEY>)")
