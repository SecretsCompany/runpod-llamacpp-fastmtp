"""RunPod LB health endpoint: 204 while llama-server loads, 200 when ready, 503 if it died."""
import http.server, os, urllib.request
UP = f"http://127.0.0.1:{os.environ.get('PORT', '8080')}/health"
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            code = urllib.request.urlopen(UP, timeout=2).status
            code = 200 if code == 200 else 204
        except urllib.error.HTTPError as e:
            code = 204 if e.code == 503 else 500
        except Exception:
            code = 204 if os.path.exists("/tmp/llama.starting") else 503
        self.send_response(code); self.end_headers()
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT_HEALTH", "8081"))), H).serve_forever()
