"""Check deployed files, links, offline cache and APK without browser automation."""
from pathlib import Path
from urllib.request import urlopen
from html.parser import HTMLParser
import hashlib
import json
import re
import zipfile

root = Path(__file__).resolve().parent.parent
site = root / 'build' / 'web'

class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []

    def handle_starttag(self, tag, attrs):
        self.urls.extend(value for key, value in attrs if key in ('href', 'src') and value and not value.startswith(('#', 'https:', 'http:')))

checked = 0
for page in ('index.html', 'game.html'):
    html = (site / page).read_text(encoding='utf-8')
    assert '$GODOT_' not in html, 'Unexpanded engine template'
    parser = Links()
    parser.feed(html)
    for url in parser.urls:
        assert (site / url).exists(), f'Broken local link: {url}'
        checked += 1
manifest = json.loads((site / 'manifest.webmanifest').read_text(encoding='utf-8'))
assert (site / manifest['start_url']).is_file()
assert manifest['orientation'] == 'landscape'
worker = (site / 'sw.js').read_text(encoding='utf-8')
assert '__BUILD_HASH__' not in worker
for path in re.findall(r"'\./[^']*'", worker):
    url = path.strip("'")
    with urlopen('http://127.0.0.1:8080/' + url.removeprefix('./')) as response:
        assert response.status == 200, url
        if url.endswith('.wasm'):
            assert response.headers.get_content_type() == 'application/wasm'
        response.read()
    checked += 1
assert hashlib.sha256((site / 'downloads/RELIC.apk').read_bytes()).digest() == hashlib.sha256((root / 'build/android/RELIC.apk').read_bytes()).digest()
with zipfile.ZipFile(root / 'build/RELIC-website.zip') as archive:
    assert archive.testzip() is None
    assert 'index.html' in archive.namelist() and 'downloads/RELIC.apk' in archive.namelist()
    assert not any('keystore' in name or name.endswith(('.gd', '.ps1', '.log', '.dpapi')) for name in archive.namelist())
print(f'PASS: {checked} links/cache assets, WASM MIME type, matching Android download, ZIP integrity')
