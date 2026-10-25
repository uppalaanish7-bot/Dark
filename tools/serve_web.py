"""Serve only the exported public site, never the project or signing material."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8080)
parser.add_argument('--bind', default='127.0.0.1')
args = parser.parse_args()
site = Path(__file__).resolve().parent.parent / 'build' / 'web'
if not (site / 'game.html').is_file():
    raise SystemExit('Export and package the Web build first.')

class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.webmanifest': 'application/manifest+json', '.apk': 'application/vnd.android.package-archive', '.pck': 'application/octet-stream'}

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(site), **kw)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

    def list_directory(self, path):
        self.send_error(404)
        return None

print(f'RELIC: http://{args.bind}:{args.port}', flush=True)
ThreadingHTTPServer((args.bind, args.port), Handler).serve_forever()
