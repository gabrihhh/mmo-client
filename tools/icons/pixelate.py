"""Converte as imagens do Meshy em ícones pixel art 48x48 (habilidades: quadro cheio; itens: fundo transparente)."""
import sys, glob, os
import numpy as np
from PIL import Image

SIZE = 48
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out + "/abilities", exist_ok=True); os.makedirs(out + "/items", exist_ok=True)

def trim_border(im):
    """Corta molduras lisas (preta/branca) na borda das imagens de habilidade."""
    a = np.asarray(im.convert("RGB")).astype(int)
    h, w, _ = a.shape
    inner = a[int(h*.12):int(h*.2), int(w*.12):int(w*.88)].reshape(-1, 3)
    bg = np.median(inner, axis=0)
    def far(line): return (np.abs(line - bg).sum(axis=1) > 60).mean() > 0.6
    t, b, l, r = 0, h - 1, 0, w - 1
    while t < h // 4 and far(a[t]): t += 1
    while b > 3 * h // 4 and far(a[b]): b -= 1
    while l < w // 4 and far(a[:, l]): l += 1
    while r > 3 * w // 4 and far(a[:, r]): r -= 1
    m = 4 if (t or l) else 0
    return im.crop((l + m, t + m, r - m + 1, b - m + 1))

def quantize(im, colors):
    rgba = im.convert("RGBA")
    alpha = rgba.getchannel("A")
    q = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    q.putalpha(alpha)
    return q

for f in sorted(glob.glob(src + "/ability_*.png")):
    name = os.path.basename(f)[len("ability_"):]
    im = trim_border(Image.open(f))
    side = min(im.size); im = im.crop(((im.width - side)//2, (im.height - side)//2, (im.width + side)//2, (im.height + side)//2))
    px = quantize(im.resize((SIZE, SIZE), Image.Resampling.BOX), 28)
    px = px.convert("RGB")
    px.save(out + "/abilities/" + name)

def item_icon(im):
    im = im.convert("RGBA")
    a = np.asarray(im)
    mask = a[:, :, 3] > 40
    ys, xs = np.nonzero(mask)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = int(max(im.size) * 1.08)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0)); sq.alpha_composite(im, ((side - im.width)//2, (side - im.height)//2))
    inner = SIZE - 4
    small = sq.resize((inner, inner), Image.Resampling.BOX)
    arr = np.asarray(small).copy()
    arr[:, :, 3] = np.where(arr[:, :, 3] > 110, 255, 0)
    small = quantize(Image.fromarray(arr), 20)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)); canvas.alpha_composite(small, (2, 2))
    # contorno escuro de 1 px em volta do item (cara de pixel art)
    c = np.asarray(canvas).copy(); solid = c[:, :, 3] > 0
    grow = solid.copy()
    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
        grow |= np.roll(np.roll(solid, dy, 0), dx, 1)
    edge = grow & ~solid
    c[edge] = (24, 18, 30, 255)
    return Image.fromarray(c)

for f in sorted(glob.glob(src + "/item_*.png")):
    item_icon(Image.open(f)).save(out + "/items/" + os.path.basename(f)[len("item_"):])
DIAGONAL = ("arcane_staff", "knight_sword")  # armas em pé ficam finas: na diagonal ocupam o ícone
for f in sorted(glob.glob(src + "/concept_*.png")):
    im = Image.open(f).convert("RGBA")
    if any(n in f for n in DIAGONAL): im = im.rotate(-45, resample=Image.Resampling.BICUBIC, expand=True)
    item_icon(im).save(out + "/items/" + os.path.basename(f)[len("concept_"):])
print("ok")
