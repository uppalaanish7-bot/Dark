"""Assemble the static website after Godot's Web export; Python 3 + Pillow."""
from pathlib import Path
from PIL import Image
import hashlib
import shutil
import zipfile

root = Path(__file__).resolve().parent.parent
dest = root / 'build' / 'web'
dest.mkdir(parents=True, exist_ok=True)
for name in ('index.html', 'style.css', 'site.js', 'manifest.webmanifest', '_headers'):
    shutil.copy2(root / 'web' / name, dest / name)
(dest / 'icons').mkdir(exist_ok=True)
for size in (180, 192, 512):
    shutil.copy2(root / 'assets' / f'relic_{size}.png', dest / 'icons')
shutil.copy2(root / 'assets' / 'Rajdhani-SemiBold.ttf', dest)
Image.open(root / 'tests' / 'gameplay.png').convert('RGB').save(dest / 'arena.webp', quality=88)
notices = ['CREDITS.md', 'License.txt', 'read me .txt', 'assets/OFL.txt', 'build/ENGINE-LICENSES.txt']
(dest / 'credits.txt').write_text('\n\n'.join((root / name).read_text(encoding='utf-8', errors='replace') for name in notices), encoding='utf-8')
apk = root / 'build' / 'android' / 'RELIC.apk'
if apk.exists():
    (dest / 'downloads').mkdir(exist_ok=True)
    shutil.copy2(apk, dest / 'downloads' / 'RELIC.apk')
digest = hashlib.sha256()
for file in sorted(dest.rglob('*')):
    if file.is_file() and file.name != 'sw.js' and 'downloads' not in file.parts:
        digest.update(file.relative_to(dest).as_posix().encode())
        digest.update(file.read_bytes())
(dest / 'sw.js').write_text((root / 'web' / 'sw.js').read_text(encoding='utf-8').replace('__BUILD_HASH__', digest.hexdigest()[:16]), encoding='utf-8')
with zipfile.ZipFile(root / 'build' / 'RELIC-website.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(dest.rglob('*')):
        if file.is_file():
            archive.write(file, file.relative_to(dest))
print('Website ready:', dest)
print('Upload the contents of RELIC-website.zip to an HTTPS static host.')
