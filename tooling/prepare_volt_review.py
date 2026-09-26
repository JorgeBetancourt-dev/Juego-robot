from __future__ import annotations

from collections import deque
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "review" / "volt_sprite_review_v1"
MAIN = Path(r"C:\Users\JBH_2\OneDrive\Desktop\Juego de sistema caido\Volt.png")


MAIN_ROWS = {
    "idle": ((20, 300, 745, 419), 5),
    "walk": ((775, 300, 1518, 419), 6),
    "telegraph": ((20, 485, 745, 608), 4),
    "slam": ((775, 480, 1518, 610), 5),
    "vulnerable": ((20, 852, 490, 976), 3),
    "hurt": ((500, 852, 970, 976), 3),
    "defeat": ((980, 845, 1518, 976), 4),
}


MISSILE_ROWS = {
    "missile_launch": ((790, 680, 1040, 790), 2),
    "missile_impact": ((1250, 655, 1518, 790), 3),
}


MAIN_FRAMES = {
    "missile_projectile": [
        (1160, 660, 1235, 715),
    ],
}


DISPLAY_NAMES = {
    "idle": "IDLE / RESPIRACIÓN",
    "walk": "CAMINATA LENTA",
    "telegraph": "PREPARACIÓN DE ATAQUE",
    "slam": "ATAQUE 1 / GOLPE TERRESTRE",
    "missile_launch": "ATAQUE 3A / LANZAMIENTO",
    "missile_projectile": "ATAQUE 3B / PROYECTILES",
    "missile_impact": "ATAQUE 3C / IMPACTOS",
    "vulnerable": "FASE VULNERABLE",
    "hurt": "DAÑO",
    "defeat": "DERROTA",
}


def _connected_components(mask: np.ndarray) -> list[list[tuple[int, int]]]:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    groups: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            queue = deque([(x, y)])
            seen[y, x] = True
            group: list[tuple[int, int]] = []
            while queue:
                px, py = queue.popleft()
                group.append((px, py))
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if (
                        0 <= nx < width
                        and 0 <= ny < height
                        and mask[ny, nx]
                        and not seen[ny, nx]
                    ):
                        seen[ny, nx] = True
                        queue.append((nx, ny))
            groups.append(group)
    return groups


def trim_transparent(result: Image.Image, pad: int = 6) -> Image.Image:
    bounds = result.getbbox()
    if bounds is None:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    left, top, right, bottom = bounds
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(result.width, right + pad)
    bottom = min(result.height, bottom + pad)
    return result.crop((left, top, right, bottom))


def extract(
    source: Image.Image,
    box: tuple[int, int, int, int],
    *,
    trim: bool = True,
) -> Image.Image:
    crop = source.crop(box).convert("RGB")
    rgb = np.asarray(crop).astype(np.float32)
    height, width = rgb.shape[:2]

    edge = max(2, min(8, width // 10))
    row_samples = np.concatenate((rgb[:, :edge], rgb[:, -edge:]), axis=1)
    row_bg = np.median(row_samples, axis=1)[:, None, :]
    top_bg = np.median(rgb[: min(8, height)], axis=(0, 1))[None, None, :]
    background = row_bg * 0.72 + top_bg * 0.28

    distance = np.sqrt(np.sum((rgb - background) ** 2, axis=2))
    alpha = np.clip((distance - 8.0) * (255.0 / 22.0), 0, 255).astype(np.uint8)

    # Remove low-contrast isolated texture while retaining tiny orange sparks.
    rough = alpha > 24
    for group in _connected_components(rough):
        ys = np.array([point[1] for point in group])
        xs = np.array([point[0] for point in group])
        colors = rgb[ys, xs]
        bright_orange = np.any(
            (colors[:, 0] > 120)
            & (colors[:, 0] > colors[:, 2] + 40)
        )
        visible_detail = np.any(np.max(colors, axis=1) > 88)
        if len(group) < 6 and not bright_orange:
            alpha[ys, xs] = 0
        elif not visible_detail and not bright_orange:
            alpha[ys, xs] = 0

    rgba = np.dstack((rgb.astype(np.uint8), alpha))
    result = Image.fromarray(rgba, "RGBA")
    return trim_transparent(result) if trim else result


def split_row(
    source: Image.Image,
    box: tuple[int, int, int, int],
    count: int,
) -> list[Image.Image]:
    strip = extract(source, box, trim=False)
    alpha = np.asarray(strip)[..., 3]
    activity = np.sum(alpha > 36, axis=0)
    low = activity <= 2
    gaps: list[tuple[int, int]] = []
    start: int | None = None
    for x, is_low in enumerate(low):
        if is_low and start is None:
            start = x
        if start is not None and (not is_low or x == strip.width - 1):
            end = x if not is_low else x + 1
            if end - start >= 3 and start > 5 and end < strip.width - 5:
                gaps.append((start, end))
            start = None
    boundaries = [0, *[(start + end) // 2 for start, end in gaps[: count - 1]]]
    if len(boundaries) != count:
        boundaries = [int(round(index * strip.width / count)) for index in range(count)]
    boundaries.append(strip.width)
    return [
        trim_transparent(strip.crop((boundaries[i], 0, boundaries[i + 1], strip.height)))
        for i in range(count)
    ]


def checkerboard(size: tuple[int, int], cell: int = 12) -> Image.Image:
    image = Image.new("RGB", size, (40, 52, 62))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            color = (58, 73, 85) if (x // cell + y // cell) % 2 else (39, 51, 60)
            draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=color)
    return image


def make_preview(name: str, frames: list[Image.Image]) -> None:
    font = ImageFont.truetype(r"C:\Windows\Fonts\arial.ttf", 20)
    label_font = ImageFont.truetype(r"C:\Windows\Fonts\arial.ttf", 15)
    max_frame_width = max(frame.width for frame in frames)
    max_frame_height = max(frame.height for frame in frames)
    columns = 4 if max_frame_width < 360 else 2
    cell_width = max(220, max_frame_width + 36)
    cell_height = max(200, max_frame_height + 64)
    rows = (len(frames) + columns - 1) // columns
    canvas = checkerboard((columns * cell_width, 54 + rows * cell_height))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, canvas.width, 54), fill=(7, 22, 32))
    draw.text((18, 16), DISPLAY_NAMES[name], fill=(214, 239, 255), font=font)

    for index, frame in enumerate(frames):
        column = index % columns
        row = index // columns
        x0 = column * cell_width
        y0 = 54 + row * cell_height
        x = x0 + (cell_width - frame.width) // 2
        y = y0 + cell_height - frame.height - 30
        canvas.paste(frame, (x, y), frame)
        draw.text((x0 + 10, y0 + 8), f"F{index + 1:02d}", fill=(255, 184, 74), font=label_font)
        draw.rectangle(
            (x0, y0, x0 + cell_width - 1, y0 + cell_height - 1),
            outline=(74, 112, 132),
            width=1,
        )
    canvas.save(OUT / f"preview_{name}.png")


def make_overview(filename: str, names: list[str]) -> None:
    previews = [Image.open(OUT / f"preview_{name}.png").convert("RGB") for name in names]
    target_width = 1200
    resized: list[Image.Image] = []
    for preview in previews:
        if preview.width > target_width:
            height = round(preview.height * target_width / preview.width)
            preview = preview.resize((target_width, height), Image.Resampling.NEAREST)
        resized.append(preview)
    gap = 18
    canvas = Image.new(
        "RGB",
        (target_width, sum(image.height for image in resized) + gap * (len(resized) - 1)),
        (4, 14, 22),
    )
    y = 0
    for preview in resized:
        canvas.paste(preview, (0, y))
        y += preview.height + gap
    canvas.save(OUT / filename)


def process(source_path: Path, definitions: dict[str, list[tuple[int, int, int, int]]]) -> None:
    source = Image.open(source_path).convert("RGB")
    for name, boxes in definitions.items():
        animation_dir = OUT / name
        animation_dir.mkdir(parents=True, exist_ok=True)
        frames: list[Image.Image] = []
        for index, box in enumerate(boxes):
            frame = extract(source, box)
            frame.save(animation_dir / f"frame_{index:02d}.png")
            frames.append(frame)
        make_preview(name, frames)


def process_rows(source_path: Path) -> None:
    source = Image.open(source_path).convert("RGB")
    for name, (box, count) in MAIN_ROWS.items():
        animation_dir = OUT / name
        animation_dir.mkdir(parents=True, exist_ok=True)
        frames = split_row(source, box, count)
        for index, frame in enumerate(frames):
            frame.save(animation_dir / f"frame_{index:02d}.png")
        make_preview(name, frames)


def process_missile_rows(source_path: Path) -> None:
    source = Image.open(source_path).convert("RGB")
    for name, (box, count) in MISSILE_ROWS.items():
        animation_dir = OUT / name
        animation_dir.mkdir(parents=True, exist_ok=True)
        frames = split_row(source, box, count)
        if name == "missile_launch":
            frames[1] = trim_transparent(
                frames[1].crop((20, 0, frames[1].width, frames[1].height))
            )
        if name == "missile_impact":
            frames[1] = trim_transparent(
                frames[1].crop((0, 0, frames[1].width - 20, frames[1].height))
            )
        for index, frame in enumerate(frames):
            frame.save(animation_dir / f"frame_{index:02d}.png")
        make_preview(name, frames)


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True, exist_ok=True)
    process_rows(MAIN)
    process_missile_rows(MAIN)
    process(MAIN, MAIN_FRAMES)
    make_overview("overview_movement.png", ["idle", "walk"])
    make_overview("overview_attacks.png", ["telegraph", "slam"])
    make_overview(
        "overview_missiles.png",
        ["missile_launch", "missile_projectile", "missile_impact"],
    )
    make_overview("overview_states.png", ["vulnerable", "hurt", "defeat"])
    print(f"Review sprites written to {OUT}")


if __name__ == "__main__":
    main()
