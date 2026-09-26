from pathlib import Path

import numpy as np
from PIL import Image

from integrate_volt_sprites import _components


ROOT = Path(__file__).resolve().parents[1]


def bbox(component: list[tuple[int, int]]) -> tuple[int, int, int, int]:
    xs = [point[0] for point in component]
    ys = [point[1] for point in component]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


for path in sorted((ROOT / "assets" / "sprites" / "volt").glob("*/*.png")):
    image = Image.open(path).convert("RGBA")
    rgba = np.array(image)
    alpha = rgba[..., 3] > 96
    red = rgba[..., 0].astype(np.int16)
    green = rgba[..., 1].astype(np.int16)
    blue = rgba[..., 2].astype(np.int16)
    orange = alpha & (red > 150) & (red > green + 35) & (green > blue + 15)
    neutral = alpha & ~orange
    neutral_components = [c for c in _components(neutral) if len(c) > 20]
    if not neutral_components:
        continue
    subject = max(neutral_components, key=len)
    left, top, right, bottom = bbox(subject)
    orange_local = orange.copy()
    orange_local[:, : max(0, left - 8)] = False
    orange_local[:, min(image.width, right + 8) :] = False
    orange_local[: max(0, top - 8), :] = False
    orange_local[min(image.height, bottom + 8) :, :] = False
    orange_components = [c for c in _components(orange_local) if len(c) > 5]
    core = max(orange_components, key=len) if orange_components else []
    core_box = bbox(core) if core else None
    print(
        path.parent.name,
        path.stem,
        "body=",
        (left, top, right, bottom),
        "core=",
        core_box,
    )
