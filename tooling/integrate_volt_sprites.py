from __future__ import annotations

from collections import deque
from pathlib import Path
import json
import shutil

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "assets" / "sprites" / "volt"
SOURCE_ARCHIVE = ROOT / "assets" / "source_sheets" / "volt"
DESKTOP = Path(r"C:\Users\JBH_2\OneDrive\Desktop\Juego de sistema caido")
REVIEW = ROOT / "review" / "volt_integrated"

SOURCES = {
    "walk": DESKTOP / "Imagen_de_Codex_24_sept_2026__20_06_06-removebg-preview.png",
    "core_charge": DESKTOP / "Imagen_de_Codex_24_sept_2026__20_06_59-removebg-preview.png",
    "ground_slam": DESKTOP / "Imagen_de_Codex_24_sept_2026__20_07_29-removebg-preview.png",
    "missiles": DESKTOP / "Imagen_de_Codex_24_sept_2026__20_07_57-removebg-preview.png",
    "vulnerable": DESKTOP / "Imagen_de_Codex_24_sept_2026__20_08_32-removebg-preview.png",
    "defeat": DESKTOP / "Imagen_de_Codex_24_sept_2026__20_09_04-removebg-preview.png",
}

LEGACY_REVIEW = ROOT / "review" / "volt_sprite_review_v1"

ANIMATIONS: dict[str, list[str]] = {
    "idle": [f"idle_breathe_{i:02d}" for i in range(1, 6)],
    "walk": [f"walk_step_{i:02d}" for i in range(1, 7)],
    "core_charge": [f"core_charge_{i:02d}" for i in range(1, 6)],
    "ground_slam": [
        "ground_slam_raise",
        "ground_slam_windup",
        "ground_slam_descend",
        "ground_slam_impact_01",
        "ground_slam_impact_02",
    ],
    "missile_launch": ["missile_launcher_ready", "missile_launcher_fire"],
    "missile_projectile": [
        "missile_projectile_flight_01",
        "missile_projectile_flight_02",
        "missile_projectile_flight_03",
    ],
    "missile_impact": [
        "missile_impact_01",
        "missile_impact_02",
        "missile_impact_03",
    ],
    "vulnerable": [
        "vulnerable_core_open_01",
        "vulnerable_core_open_02",
        "vulnerable_core_open_03",
    ],
    "hurt": [f"hurt_recoil_{i:02d}" for i in range(1, 4)],
    "defeat": [
        "defeat_stagger",
        "defeat_collapse_01",
        "defeat_collapse_02",
        "defeat_destroyed",
    ],
}


def _components(mask: np.ndarray) -> list[list[tuple[int, int]]]:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    result: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            queue = deque([(x, y)])
            seen[y, x] = True
            component: list[tuple[int, int]] = []
            while queue:
                px, py = queue.popleft()
                component.append((px, py))
                for ny in range(max(0, py - 1), min(height, py + 2)):
                    for nx in range(max(0, px - 1), min(width, px + 2)):
                        if mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            queue.append((nx, ny))
            result.append(component)
    return result


def clean_transparency(image: Image.Image) -> Image.Image:
    rgba = np.array(image.convert("RGBA"))
    alpha = rgba[..., 3]
    mask = alpha > 10
    components = _components(mask)
    if not components:
        return Image.fromarray(rgba, "RGBA")
    main = max(components, key=len)
    main_x = [point[0] for point in main]
    main_y = [point[1] for point in main]
    main_bounds = (
        min(main_x) - 12,
        min(main_y) - 12,
        max(main_x) + 12,
        max(main_y) + 12,
    )
    for component in components:
        if component is main:
            continue
        xs = np.array([point[0] for point in component])
        ys = np.array([point[1] for point in component])
        colors = rgba[ys, xs, :3].astype(np.int16)
        orange = np.any(
            (colors[:, 0] > 125)
            & (colors[:, 0] > colors[:, 1] + 20)
            & (colors[:, 1] > colors[:, 2] + 10)
        )
        near_subject = not (
            xs.max() < main_bounds[0]
            or xs.min() > main_bounds[2]
            or ys.max() < main_bounds[1]
            or ys.min() > main_bounds[3]
        )
        if not orange and not near_subject:
            alpha[ys, xs] = 0
    rgba[..., 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def trim(image: Image.Image, padding: int = 3) -> Image.Image:
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError("Empty Volt sprite frame")
    left, top, right, bottom = bounds
    return image.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(image.width, right + padding),
            min(image.height, bottom + padding),
        )
    )


def crop_clean(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    return trim(clean_transparency(image.crop(box)))


def split_by_gaps(image: Image.Image, count: int) -> list[Image.Image]:
    cleaned = clean_transparency(image)
    alpha = np.array(cleaned.getchannel("A"))
    activity = np.sum(alpha > 16, axis=0)
    gaps: list[tuple[int, int]] = []
    start: int | None = None
    for x, empty in enumerate(activity <= 1):
        if empty and start is None:
            start = x
        if start is not None and (not empty or x == image.width - 1):
            end = x if not empty else x + 1
            if end - start >= 3:
                gaps.append((start, end))
            start = None
    boundaries = [0]
    search_radius = image.width / count * 0.48
    for index in range(1, count):
        expected = image.width * index / count
        candidates = [
            gap
            for gap in gaps
            if abs(((gap[0] + gap[1]) / 2) - expected) <= search_radius
            and gap[0] > boundaries[-1]
        ]
        if not candidates:
            boundaries.append(round(expected))
            continue
        best = max(
            candidates,
            key=lambda gap: ((gap[1] - gap[0]) * 3) - abs(((gap[0] + gap[1]) / 2) - expected),
        )
        boundaries.append((best[0] + best[1]) // 2)
    boundaries.append(image.width)
    return [
        trim(cleaned.crop((boundaries[i], 0, boundaries[i + 1], image.height)))
        for i in range(count)
    ]


def normalize(
    image: Image.Image,
    canvas_size: tuple[int, int],
    content_size: tuple[int, int],
    *,
    anchor: str = "bottom_center",
) -> Image.Image:
    scale = min(content_size[0] / image.width, content_size[1] / image.height)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    resized = image.resize(size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    if anchor == "bottom_left":
        x = 4
    else:
        x = (canvas_size[0] - resized.width) // 2
    y = canvas_size[1] - resized.height - 4
    canvas.alpha_composite(resized, (x, y))
    return canvas


def normalize_group(
    frames: list[Image.Image],
    canvas_size: tuple[int, int],
    content_size: tuple[int, int],
    *,
    anchor: str = "bottom_center",
) -> list[Image.Image]:
    def subject_bounds(frame: Image.Image) -> tuple[int, int, int, int]:
        alpha = np.array(frame.getchannel("A")) > 16
        components = _components(alpha)
        subject = max(components, key=len)
        xs = [point[0] for point in subject]
        ys = [point[1] for point in subject]
        return min(xs), min(ys), max(xs) + 1, max(ys) + 1

    bounds = [subject_bounds(frame) for frame in frames]
    scale = min(
        content_size[0] / max(right - left for left, _, right, _ in bounds),
        content_size[1] / max(bottom - top for _, top, _, bottom in bounds),
    )
    result: list[Image.Image] = []
    for frame, (left, top, right, bottom) in zip(frames, bounds, strict=True):
        size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
        resized = frame.resize(size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        scaled_left = round(left * scale)
        scaled_right = round(right * scale)
        scaled_bottom = round(bottom * scale)
        x = (
            4 - scaled_left
            if anchor == "bottom_left"
            else round((canvas_size[0] - (scaled_left + scaled_right)) / 2)
        )
        y = canvas_size[1] - scaled_bottom - 4
        canvas.alpha_composite(resized, (x, y))
        result.append(canvas)
    return result


def mechanical_body_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    rgba = np.array(image.convert("RGBA"))
    alpha = rgba[..., 3] > 96
    red = rgba[..., 0].astype(np.int16)
    green = rgba[..., 1].astype(np.int16)
    blue = rgba[..., 2].astype(np.int16)
    orange = alpha & (red > 150) & (red > green + 35) & (green > blue + 15)
    neutral = alpha & ~orange
    components = [component for component in _components(neutral) if len(component) > 20]
    if not components:
        bounds = image.getbbox()
        if bounds is None:
            raise ValueError("Cannot normalize an empty Volt frame")
        return bounds
    subject = max(components, key=len)
    xs = [point[0] for point in subject]
    ys = [point[1] for point in subject]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def standardize_volt_body(
    image: Image.Image,
    *,
    canvas_size: tuple[int, int],
    body_width: int = 160,
    body_center_x: int = 96,
    ground_y: int = 252,
) -> Image.Image:
    left, top, right, bottom = mechanical_body_bounds(image)
    scale = body_width / (right - left)
    resized = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.NEAREST,
    )
    scaled_center = ((left + right) / 2) * scale
    scaled_bottom = bottom * scale
    x = round(body_center_x - scaled_center)
    y = round(ground_y - scaled_bottom)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    canvas.alpha_composite(resized, (x, y))
    return canvas


def boss_frames(frames: list[Image.Image]) -> list[Image.Image]:
    normalized = normalize_group(frames, (192, 256), (184, 232))
    return [
        standardize_volt_body(frame, canvas_size=(192, 256))
        for frame in normalized
    ]


def missile_frames(image: Image.Image) -> tuple[list[Image.Image], list[Image.Image], list[Image.Image]]:
    # The sheet contains two launch poses, several trajectory examples and three impacts.
    launch = boss_frames(split_by_gaps(image.crop((0, 0, 250, 225)), 2))
    projectile = normalize_group(
        [
            crop_clean(image, (258, 75, 336, 118)),
            crop_clean(image, (320, 92, 376, 138)),
            crop_clean(image, (374, 112, 438, 155)),
        ],
        (96, 64),
        (88, 52),
        anchor="bottom_left",
    )
    impacts = [
        normalize(crop_clean(image, (494, 92, 620, 225)), (160, 128), (150, 116)),
        normalize(crop_clean(image, (610, 80, 746, 225)), (160, 128), (150, 116)),
        normalize(crop_clean(image, (728, 62, 864, 225)), (160, 128), (150, 116)),
    ]
    return launch, projectile, impacts


def save_animation(name: str, frames: list[Image.Image]) -> None:
    expected_names = ANIMATIONS[name]
    if len(frames) != len(expected_names):
        raise ValueError(f"{name}: expected {len(expected_names)} frames, got {len(frames)}")
    directory = ASSET_ROOT / name
    directory.mkdir(parents=True, exist_ok=True)
    for filename, frame in zip(expected_names, frames, strict=True):
        frame.save(directory / f"{filename}.png", optimize=True)


def archive_sources() -> None:
    SOURCE_ARCHIVE.mkdir(parents=True, exist_ok=True)
    for semantic_name, source in SOURCES.items():
        shutil.copy2(source, SOURCE_ARCHIVE / f"volt_{semantic_name}_source.png")


def build_review() -> None:
    REVIEW.mkdir(parents=True, exist_ok=True)
    for animation, filenames in ANIMATIONS.items():
        frames = [Image.open(ASSET_ROOT / animation / f"{name}.png") for name in filenames]
        columns = min(4, len(frames))
        rows = (len(frames) + columns - 1) // columns
        cell_width = max(frame.width for frame in frames) + 16
        cell_height = max(frame.height for frame in frames) + 16
        canvas = Image.new("RGBA", (columns * cell_width, rows * cell_height), (24, 36, 46, 255))
        for index, frame in enumerate(frames):
            x = (index % columns) * cell_width + (cell_width - frame.width) // 2
            y = (index // columns) * cell_height + cell_height - frame.height - 8
            canvas.alpha_composite(frame, (x, y))
        canvas.convert("RGB").save(REVIEW / f"{animation}.png")


def validate_body_scale() -> None:
    body_animations = {
        "idle",
        "walk",
        "core_charge",
        "ground_slam",
        "missile_launch",
        "vulnerable",
        "hurt",
        "defeat",
    }
    report: dict[str, dict[str, int]] = {}
    for animation in sorted(body_animations):
        report[animation] = {}
        for filename in ANIMATIONS[animation]:
            image = Image.open(ASSET_ROOT / animation / f"{filename}.png")
            left, _, right, _ = mechanical_body_bounds(image)
            width = right - left
            report[animation][filename] = width
            if not 152 <= width <= 168:
                raise ValueError(
                    f"{animation}/{filename}: mechanical body width {width}px "
                    "is outside the normalized 160px target"
                )
    (REVIEW / "body_scale_report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def main() -> None:
    missing = [str(path) for path in SOURCES.values() if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing Volt sources: " + ", ".join(missing))
    expected_root = (ROOT / "assets" / "sprites" / "volt").resolve()
    if ASSET_ROOT.resolve() != expected_root:
        raise RuntimeError("Refusing to replace an unexpected asset directory")
    if ASSET_ROOT.exists():
        shutil.rmtree(ASSET_ROOT)
    ASSET_ROOT.mkdir(parents=True)

    walk = boss_frames(split_by_gaps(Image.open(SOURCES["walk"]), 6))
    charge = boss_frames(split_by_gaps(Image.open(SOURCES["core_charge"]), 5))
    slam = boss_frames(split_by_gaps(Image.open(SOURCES["ground_slam"]), 5))
    vulnerable = boss_frames(split_by_gaps(Image.open(SOURCES["vulnerable"]), 3))
    defeat = boss_frames(split_by_gaps(Image.open(SOURCES["defeat"]), 4))
    missile_launch, missile_projectile, missile_impact = missile_frames(
        Image.open(SOURCES["missiles"])
    )
    idle = boss_frames(
        [Image.open(LEGACY_REVIEW / "idle" / f"frame_{i:02d}.png") for i in range(5)]
    )
    hurt = boss_frames(
        [Image.open(LEGACY_REVIEW / "hurt" / f"frame_{i:02d}.png") for i in range(3)]
    )

    save_animation("idle", idle)
    save_animation("walk", walk)
    save_animation("core_charge", charge)
    save_animation("ground_slam", slam)
    save_animation("missile_launch", missile_launch)
    save_animation("missile_projectile", missile_projectile)
    save_animation("missile_impact", missile_impact)
    save_animation("vulnerable", vulnerable)
    save_animation("hurt", hurt)
    save_animation("defeat", defeat)
    archive_sources()
    build_review()
    validate_body_scale()
    (ASSET_ROOT / "volt_sprite_manifest.json").write_text(
        json.dumps(ANIMATIONS, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"Integrated {sum(map(len, ANIMATIONS.values()))} named Volt sprites")


if __name__ == "__main__":
    main()
