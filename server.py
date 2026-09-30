# server.py - serve o projeto e recebe as gravacoes do host em ./gravacoes
#
# Uso: py server.py [PORTA]   (padrao 8765, so em 127.0.0.1)
# O host (index.html aberto via localhost) faz PUT /rec/<arquivo>.webm com cada parte.

import http.server
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "gravacoes")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
NAME = re.compile(r"/rec/([\w-]+(?:\.[\w-]+)*\.webm)")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_PUT(self):
        m = NAME.fullmatch(self.path)
        if not m:
            self.send_error(404)
            return
        size = int(self.headers.get("Content-Length") or 0)
        os.makedirs(OUT, exist_ok=True)
        dest = os.path.join(OUT, m.group(1))
        tmp = dest + ".part"
        with open(tmp, "wb") as f:
            left = size
            while left > 0:
                buf = self.rfile.read(min(left, 1 << 20))
                if not buf:
                    break
                f.write(buf)
                left -= len(buf)
        if left:
            os.remove(tmp)
            self.send_error(400, "upload incompleto")
            return
        os.replace(tmp, dest)
        print(f"gravacao salva: {dest} ({size / 1048576:.1f} MB)", flush=True)
        self.send_response(201)
        self.send_header("Content-Length", "0")
        self.end_headers()


if __name__ == "__main__":
    print(f"cam: http://127.0.0.1:{PORT}/  gravacoes em {OUT}", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
