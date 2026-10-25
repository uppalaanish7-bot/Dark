"""Encode the actual Godot preview frames with a stable shared GIF palette."""
from pathlib import Path
import sys
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/asset_review/motion_previews'
OUT.mkdir(exist_ok=True)
for identity in sys.argv[1:] or ['female','omega','subboss_7','grand_boss','main_boss']:
    files=sorted((ROOT/'art/asset_review/motion_frames'/identity).glob('*.png'))
    if not files: continue
    sample=Image.new('RGB',(720,480*12))
    for n in range(12):
        im=Image.open(files[min(n*len(files)//12,len(files)-1)]).convert('RGB').resize((720,480),Image.Resampling.LANCZOS)
        sample.paste(im,(0,n*480))
    palette=sample.quantize(colors=192,method=Image.Quantize.MEDIANCUT)
    frames=[]
    for path in files:
        im=Image.open(path).convert('RGB').resize((720,480),Image.Resampling.LANCZOS)
        frames.append(im.quantize(palette=palette,dither=Image.Dither.NONE))
    durations=[40 if n%6 else 50 for n in range(len(frames))]
    target=OUT/(identity+'_motion.gif')
    frames[0].save(target,save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=True,disposal=2)
    print('GIF_READY',target,len(frames),target.stat().st_size,flush=True)
