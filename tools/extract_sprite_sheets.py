from __future__ import annotations

import json
import shutil
from collections import deque
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(r"C:\Proyectos de flutter\game_final")
SOURCE_ROOT = Path(r"C:\Users\JBH_2\OneDrive\Desktop\Juego de sistema caido")
ASSET_ROOT = ROOT / "assets" / "sprites"
SOURCE_ASSET_ROOT = ROOT / "assets" / "source_sheets"


@dataclass(frozen=True)
class Strip:
    centers: tuple[tuple[int, int], ...]
    crop: tuple[int, int]


@dataclass(frozen=True)
class CharacterSheet:
    source: str
    canvas: tuple[int, int]
    scale: float
    strips: dict[str, Strip]


SHEETS: dict[str, CharacterSheet] = {
    "m0": CharacterSheet(
        source="M-0.png",
        canvas=(144, 88),
        scale=0.72,
        strips={
            "idle": Strip(((80, 373), (166, 373), (254, 373), (343, 373), (431, 373)), (78, 98)),
            "run": Strip(((561, 374), (655, 374), (749, 374), (843, 374), (939, 374), (1032, 374)), (88, 100)),
            "rise": Strip(((1217, 373), (1325, 373), (1428, 373)), (92, 104)),
            "fall": Strip(((96, 553), (192, 553), (293, 553), (394, 553)), (88, 98)),
            "land": Strip(((563, 554), (665, 554), (785, 554)), (104, 92)),
            "attack": Strip(((963, 554), (1090, 554), (1260, 554), (1410, 554)), (158, 100)),
            "dash": Strip(((104, 748), (279, 748), (445, 748)), (166, 94)),
            "wall_slide": Strip(((581, 739), (683, 739)), (92, 126)),
            "wall_jump": Strip(((825, 742), (929, 742), (1022, 742)), (104, 120)),
            "double_jump": Strip(((1153, 744), (1249, 744), (1352, 744), (1454, 744)), (98, 114)),
            "down_strike": Strip(((78, 925), (191, 925), (306, 925)), (112, 128)),
            "hurt": Strip(((460, 925), (558, 925), (658, 925)), (92, 120)),
            "death": Strip(((776, 931), (868, 931), (967, 931), (1064, 931)), (100, 112)),
            "respawn": Strip(((1162, 930), (1270, 930), (1370, 930), (1464, 930)), (102, 120)),
        },
    ),
    "patrol": CharacterSheet(
        source="Patrol Unit.png",
        canvas=(128, 76),
        scale=0.62,
        strips={
            "idle": Strip(((97, 441), (248, 441), (393, 441), (548, 441)), (132, 116)),
            "walk": Strip(((744, 441), (893, 441), (1040, 441), (1187, 441), (1332, 441), (1450, 441)), (132, 116)),
            "turn": Strip(((98, 691), (244, 691), (397, 691), (550, 691)), (132, 120)),
            "attack": Strip(((742, 691), (916, 691), (1084, 691), (1264, 691), (1430, 691)), (156, 120)),
            "hurt": Strip(((103, 934), (264, 934), (417, 934), (584, 934)), (144, 116)),
            "death": Strip(((786, 923), (959, 923), (1134, 923), (1305, 923), (1465, 923)), (160, 142)),
        },
    ),
    "watcher": CharacterSheet(
        source="Watcher.png",
        canvas=(96, 104),
        scale=0.68,
        strips={
            "idle": Strip(((89, 433), (226, 433), (354, 433), (460, 433)), (112, 136)),
            "detect": Strip(((600, 433), (725, 433), (845, 433), (950, 433)), (112, 136)),
            "aim": Strip(((1067, 433), (1210, 433), (1340, 433), (1452, 433)), (118, 136)),
            "shoot": Strip(((100, 667), (236, 667), (381, 667), (532, 667)), (122, 130)),
            "cooldown": Strip(((925, 667), (1044, 667), (1171, 667), (1303, 667), (1440, 667)), (112, 130)),
        },
    ),
    "watcher_projectile": CharacterSheet(
        source="Watcher.png",
        canvas=(40, 32),
        scale=0.72,
        strips={
            "fly": Strip(((248, 884), (380, 884), (500, 884), (620, 884), (730, 884)), (100, 54)),
            "impact": Strip(((872, 895), (994, 895), (1148, 895), (1327, 895), (1474, 895)), (112, 112)),
        },
    ),
    "drone": CharacterSheet(
        source="Drone.png",
        canvas=(112, 76),
        scale=0.68,
        strips={
            "idle": Strip(((88, 365), (213, 365), (348, 365), (474, 365), (594, 365), (714, 365)), (112, 104)),
            "patrol": Strip(((874, 365), (1033, 365), (1182, 365), (1323, 365), (1448, 365)), (130, 104)),
            "turn": Strip(((95, 557), (261, 557), (408, 557), (534, 557), (693, 557)), (126, 112)),
            "shoot": Strip(((832, 557), (963, 557), (1095, 557)), (124, 112)),
            "charge": Strip(((100, 744), (262, 744), (421, 744), (576, 744), (725, 744)), (150, 106)),
            "hurt": Strip(((880, 744), (1037, 744), (1182, 744), (1320, 744), (1467, 744)), (126, 116)),
            "death": Strip(((96, 932), (227, 932), (363, 932), (506, 932), (633, 932), (752, 932)), (124, 126)),
        },
    ),
    "drone_projectile": CharacterSheet(
        source="Drone.png",
        canvas=(36, 28),
        scale=0.72,
        strips={
            "fly": Strip(((1025, 925), (1122, 925), (1212, 925), (1325, 925), (1420, 925), (1490, 925)), (88, 54)),
        },
    ),
    "volt": CharacterSheet(
        source="Volt.png",
        canvas=(224, 192),
        scale=0.92,
        strips={
            "idle": Strip(((90, 365), (228, 365), (365, 365), (501, 365), (637, 365)), (138, 124)),
            "walk": Strip(((829, 365), (955, 365), (1084, 365), (1212, 365), (1340, 365), (1469, 365)), (132, 124)),
            "telegraph": Strip(((95, 548), (245, 548), (394, 548), (546, 548), (687, 548)), (142, 132)),
            "slam": Strip(((840, 548), (975, 548), (1134, 548), (1283, 548), (1432, 548)), (146, 132)),
            "beam": Strip(((91, 730), (216, 730), (348, 730), (487, 730)), (134, 132)),
            "missiles": Strip(((835, 730), (961, 730)), (134, 132)),
            "vulnerable": Strip(((96, 924), (235, 924), (393, 924)), (142, 142)),
            "hurt": Strip(((574, 924), (704, 924), (840, 924), (936, 924)), (132, 142)),
            "defeat": Strip(((1046, 924), (1188, 924), (1341, 924), (1476, 924)), (132, 142)),
        },
    ),
}


def _connected_components(mask: np.ndarray) -> list[list[tuple[int, int]]]:
    height, width = mask.shape
    visited = np.zeros_like(mask, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or visited[y, x]:
                continue
            queue = deque([(x, y)])
            visited[y, x] = True
            component: list[tuple[int, int]] = []
            while queue:
                cx, cy = queue.popleft()
                component.append((cx, cy))
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not visited[ny, nx]:
                        visited[ny, nx] = True
                        queue.append((nx, ny))
            components.append(component)
    return components


def _extract_foreground(crop: Image.Image) -> Image.Image:
    rgb = np.asarray(crop.convert("RGB"), dtype=np.int16)
    border = np.concatenate((rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3), rgb[:, :4].reshape(-1, 3), rgb[:, -4:].reshape(-1, 3)))
    background = np.median(border, axis=0)
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    chroma = maximum - minimum
    distance = np.sqrt(((rgb - background) ** 2).sum(axis=2))
    seed = (maximum >= 72) | (chroma >= 30) | (distance >= 42)

    kept = np.zeros_like(seed)
    center_x = crop.width / 2
    center_y = crop.height * 0.58
    for component in _connected_components(seed):
        if len(component) < 5:
            continue
        xs = np.fromiter((point[0] for point in component), dtype=np.int16)
        ys = np.fromiter((point[1] for point in component), dtype=np.int16)
        component_center_x = float(xs.mean())
        component_center_y = float(ys.mean())
        near_subject = abs(component_center_x - center_x) < crop.width * 0.48 and abs(component_center_y - center_y) < crop.height * 0.60
        if near_subject or len(component) >= 20:
            kept[ys, xs] = True

    alpha = Image.fromarray((kept.astype(np.uint8) * 255), mode="L")
    alpha = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MaxFilter(3))
    alpha_array = np.asarray(alpha).copy()
    opaque = alpha_array > 0
    row_coverage = opaque.mean(axis=1)
    column_coverage = opaque.mean(axis=0)
    for row in np.where(row_coverage > 0.88)[0]:
        if row >= crop.height * 0.62:
            alpha_array[max(0, row - 1) :, :] = 0
            break
    edge_limit = max(3, round(crop.width * 0.15))
    for column in np.where(column_coverage > 0.72)[0]:
        if column < edge_limit or column >= crop.width - edge_limit:
            alpha_array[:, max(0, column - 1) : min(crop.width, column + 2)] = 0
    alpha = Image.fromarray(alpha_array, mode="L")
    rgba = crop.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


def _normalise(frame: Image.Image, canvas_size: tuple[int, int], scale: float) -> Image.Image:
    alpha = np.asarray(frame.getchannel("A"))
    points = np.argwhere(alpha > 0)
    if points.size == 0:
        return Image.new("RGBA", canvas_size)
    top, left = points.min(axis=0)
    bottom, right = points.max(axis=0) + 1
    content = frame.crop((int(left), int(top), int(right), int(bottom)))
    resized = content.resize(
        (max(1, round(content.width * scale)), max(1, round(content.height * scale))),
        Image.Resampling.NEAREST,
    )
    max_width, max_height = canvas_size
    if resized.width > max_width or resized.height > max_height:
        fit = min(max_width / resized.width, max_height / resized.height)
        resized = resized.resize((max(1, round(resized.width * fit)), max(1, round(resized.height * fit))), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", canvas_size)
    x = (max_width - resized.width) // 2
    y = max_height - resized.height
    canvas.alpha_composite(resized, (x, y))
    return canvas


def _contact_sheet(frames: list[Image.Image]) -> Image.Image:
    if not frames:
        return Image.new("RGBA", (1, 1))
    width, height = frames[0].size
    sheet = Image.new("RGBA", (width * len(frames), height))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * width, 0))
    return sheet


def main() -> None:
    ASSET_ROOT.mkdir(parents=True, exist_ok=True)
    SOURCE_ASSET_ROOT.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {"version": 1, "characters": {}}

    copied_sources: set[str] = set()
    for character, sheet in SHEETS.items():
        source_path = SOURCE_ROOT / sheet.source
        if sheet.source not in copied_sources:
            shutil.copy2(source_path, SOURCE_ASSET_ROOT / sheet.source)
            copied_sources.add(sheet.source)
        source = Image.open(source_path).convert("RGB")
        character_manifest: dict[str, object] = {
            "canvas": list(sheet.canvas),
            "source": f"assets/source_sheets/{sheet.source}",
            "animations": {},
        }
        for animation, strip in sheet.strips.items():
            animation_dir = ASSET_ROOT / character / animation
            animation_dir.mkdir(parents=True, exist_ok=True)
            for old_file in animation_dir.glob("*.png"):
                old_file.unlink()
            frames: list[Image.Image] = []
            paths: list[str] = []
            crop_width, crop_height = strip.crop
            for index, (center_x, center_y) in enumerate(strip.centers):
                left = center_x - crop_width // 2
                top = center_y - crop_height // 2
                crop = source.crop((left, top, left + crop_width, top + crop_height))
                frame = _normalise(_extract_foreground(crop), sheet.canvas, sheet.scale)
                output = animation_dir / f"frame_{index:02d}.png"
                frame.save(output, optimize=True)
                frames.append(frame)
                paths.append(output.relative_to(ROOT).as_posix())
            _contact_sheet(frames).save(ASSET_ROOT / character / f"{animation}.png", optimize=True)
            character_manifest["animations"][animation] = {
                "frames": paths,
                "frame_time": 0.10 if animation not in {"idle", "walk", "patrol"} else 0.14,
            }
        manifest["characters"][character] = character_manifest

    (ASSET_ROOT / "sprite_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Generated sprite assets in {ASSET_ROOT}")


if __name__ == "__main__":
    main()
