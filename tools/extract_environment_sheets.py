from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image

from extract_sprite_sheets import _extract_foreground


ROOT = Path(r"C:\Proyectos de flutter\game_final")
SOURCE_ROOT = Path(r"C:\Users\JBH_2\OneDrive\Desktop\Juego de sistema caido")
OUTPUT_ROOT = ROOT / "assets" / "environment"
SOURCE_ASSET_ROOT = ROOT / "assets" / "source_sheets"


SOURCES = {
    "platforms": "Plataformas.png",
    "interactive": "Elementos interactivos.png",
    "infrastructure": "Decoracion de fondos - infraestructura.png",
    "electricity": "Decoracion de fondos - electricidad.png",
    "wear": "Decoracion de fondos - desgaste.png",
    "signage": "Decoracion de fondos - señalización.png",
}


# name: (source key, left, top, right, bottom, mode, output size)
ASSETS = {
    # Modular platforms and surface variants.
    "tile_normal": ("platforms", 1007, 79, 1088, 168, "opaque", (32, 32)),
    "tile_worn": ("platforms", 1105, 79, 1195, 168, "opaque", (32, 32)),
    "tile_cables": ("platforms", 1207, 79, 1296, 168, "opaque", (32, 32)),
    "tile_light": ("platforms", 1312, 79, 1400, 168, "opaque", (32, 32)),
    "tile_wet": ("platforms", 1415, 79, 1504, 168, "opaque", (32, 32)),
    "platform_full": ("platforms", 39, 318, 284, 374, "transparent", (160, 40)),
    "platform_start": ("platforms", 334, 318, 437, 376, "transparent", (64, 40)),
    "platform_center": ("platforms", 485, 318, 604, 376, "transparent", (80, 40)),
    "platform_end": ("platforms", 683, 318, 798, 376, "transparent", (72, 40)),
    "platform_small": ("platforms", 459, 583, 558, 641, "transparent", (64, 40)),
    "platform_medium": ("platforms", 624, 583, 824, 641, "transparent", (128, 40)),
    "platform_grate": ("platforms", 883, 297, 1056, 389, "transparent", (128, 64)),
    "platform_glow": ("platforms", 1103, 297, 1285, 396, "transparent", (128, 64)),
    "platform_suspended": ("platforms", 1325, 291, 1501, 398, "transparent", (128, 72)),
    "platform_support": ("platforms", 887, 466, 1050, 641, "transparent", (112, 120)),
    "platform_pipes": ("platforms", 1098, 463, 1290, 641, "transparent", (128, 120)),
    "platform_broken": ("platforms", 1334, 463, 1502, 641, "transparent", (128, 120)),

    # Interactive gameplay objects.
    "door_closed": ("interactive", 29, 263, 139, 391, "transparent", (80, 112)),
    "door_opening": ("interactive", 153, 263, 273, 391, "transparent", (80, 112)),
    "door_open": ("interactive", 286, 263, 405, 391, "transparent", (80, 112)),
    "door_blocked": ("interactive", 427, 263, 535, 391, "transparent", (80, 112)),
    "door_unlocking": ("interactive", 548, 263, 659, 391, "transparent", (80, 112)),
    "switch_inactive": ("interactive", 804, 281, 900, 383, "transparent", (64, 64)),
    "switch_active": ("interactive", 907, 281, 1002, 383, "transparent", (64, 64)),
    "checkpoint_inactive": ("interactive", 43, 487, 150, 642, "transparent", (88, 128)),
    "checkpoint_activating": ("interactive", 164, 487, 278, 642, "transparent", (88, 128)),
    "checkpoint_active": ("interactive", 287, 487, 405, 642, "transparent", (88, 128)),
    "moving_platform_left": ("interactive", 437, 548, 559, 631, "transparent", (128, 64)),
    "moving_platform_center": ("interactive", 562, 548, 691, 631, "transparent", (128, 64)),
    "moving_platform_right": ("interactive", 694, 548, 816, 631, "transparent", (128, 64)),
    "spikes_inactive": ("interactive", 601, 752, 744, 825, "transparent", (128, 64)),
    "spikes_active": ("interactive", 741, 739, 882, 825, "transparent", (128, 64)),
    "laser_inactive": ("interactive", 890, 744, 1014, 825, "transparent", (128, 64)),
    "laser_active": ("interactive", 1019, 744, 1182, 825, "transparent", (160, 64)),
    "electric_floor_inactive": ("interactive", 601, 885, 752, 978, "transparent", (128, 64)),
    "electric_floor_active": ("interactive", 757, 874, 912, 978, "transparent", (128, 64)),
    "collectible_idle": ("interactive", 1210, 752, 1298, 866, "transparent", (64, 72)),
    "collectible_rotate": ("interactive", 1295, 752, 1377, 866, "transparent", (64, 72)),
    "collectible_collected": ("interactive", 1373, 752, 1450, 866, "transparent", (64, 72)),
    "module_idle": ("interactive", 1209, 890, 1292, 978, "transparent", (64, 64)),
    "module_rotate": ("interactive", 1297, 890, 1378, 978, "transparent", (64, 64)),
    "module_collected": ("interactive", 1380, 890, 1462, 978, "transparent", (64, 64)),

    # Infrastructure props and background layers.
    "infra_pillar": ("infrastructure", 36, 267, 140, 508, "transparent", (96, 224)),
    "infra_beam": ("infrastructure", 166, 285, 367, 372, "transparent", (192, 80)),
    "infra_support": ("infrastructure", 386, 286, 518, 508, "transparent", (112, 208)),
    "infra_bridge": ("infrastructure", 174, 414, 449, 496, "transparent", (256, 72)),
    "pipe_straight": ("infrastructure", 547, 285, 703, 351, "transparent", (144, 56)),
    "pipe_curve": ("infrastructure", 716, 265, 819, 374, "transparent", (96, 96)),
    "pipe_tee": ("infrastructure", 851, 265, 989, 377, "transparent", (128, 96)),
    "cables_hanging": ("infrastructure", 1017, 264, 1170, 507, "transparent", (144, 224)),
    "cable_conduit": ("infrastructure", 1179, 301, 1356, 440, "transparent", (160, 128)),
    "junction_box": ("infrastructure", 1369, 270, 1512, 507, "transparent", (128, 208)),
    "generator_secondary": ("infrastructure", 31, 579, 184, 774, "transparent", (144, 184)),
    "control_unit": ("infrastructure", 201, 584, 345, 774, "transparent", (128, 176)),
    "energy_tank": ("infrastructure", 357, 574, 504, 774, "transparent", (144, 184)),
    "maintenance_panel": ("infrastructure", 535, 577, 665, 674, "transparent", (112, 80)),
    "electrical_box": ("infrastructure", 691, 568, 793, 681, "transparent", (88, 96)),
    "ventilation_fan": ("infrastructure", 811, 568, 924, 680, "transparent", (96, 96)),
    "wall_grille": ("infrastructure", 948, 599, 1081, 672, "transparent", (112, 56)),
    "energy_direction_sign": ("infrastructure", 535, 696, 671, 775, "transparent", (128, 64)),
    "industrial_lamp": ("infrastructure", 684, 690, 793, 778, "transparent", (96, 72)),
    "light_post": ("infrastructure", 823, 686, 905, 779, "transparent", (64, 80)),
    "safety_barrier": ("infrastructure", 941, 688, 1091, 779, "transparent", (144, 72)),
    "background_far": ("infrastructure", 28, 850, 510, 1003, "opaque", (640, 256)),
    "background_mid": ("infrastructure", 520, 850, 1015, 1003, "opaque", (640, 256)),
    "background_near": ("infrastructure", 1027, 850, 1518, 1003, "opaque", (640, 256)),

    # Electrical props and effects.
    "generator_main": ("electricity", 26, 302, 158, 555, "transparent", (128, 240)),
    "generator_small": ("electricity", 168, 354, 315, 555, "transparent", (128, 184)),
    "energy_core": ("electricity", 311, 303, 456, 555, "transparent", (144, 240)),
    "energy_container": ("electricity", 461, 292, 579, 555, "transparent", (112, 240)),
    "electric_panel": ("electricity", 620, 278, 716, 397, "transparent", (88, 104)),
    "electric_panel_sparks": ("electricity", 750, 277, 866, 397, "transparent", (104, 104)),
    "control_console": ("electricity", 904, 279, 1053, 404, "transparent", (136, 112)),
    "active_cables": ("electricity", 1103, 277, 1307, 412, "transparent", (192, 120)),
    "damaged_cables": ("electricity", 1318, 276, 1513, 412, "transparent", (184, 120)),
    "spark_small": ("electricity", 29, 649, 127, 737, "transparent", (80, 72)),
    "spark_large": ("electricity", 139, 649, 241, 737, "transparent", (80, 72)),
    "arc_horizontal": ("electricity", 252, 649, 382, 737, "transparent", (112, 72)),
    "arc_vertical": ("electricity", 390, 649, 491, 737, "transparent", (80, 72)),
    "surface_discharge": ("electricity", 503, 649, 689, 737, "transparent", (160, 72)),
    "short_circuit": ("electricity", 696, 649, 796, 737, "transparent", (80, 72)),
    "energy_fluctuation": ("electricity", 804, 649, 978, 737, "transparent", (144, 72)),
    "tube_light": ("electricity", 991, 649, 1099, 737, "transparent", (96, 72)),
    "core_light": ("electricity", 1104, 649, 1222, 737, "transparent", (96, 72)),
    "spark_light": ("electricity", 1226, 649, 1345, 737, "transparent", (96, 72)),
    "ambient_light": ("electricity", 1350, 649, 1514, 737, "transparent", (144, 72)),

    # Wear overlays.
    "wear_scratches": ("wear", 28, 433, 124, 527, "transparent", (80, 80)),
    "wear_impacts": ("wear", 245, 433, 340, 527, "transparent", (80, 80)),
    "wear_rust": ("wear", 585, 433, 686, 527, "transparent", (80, 80)),
    "wear_crack": ("wear", 1057, 433, 1160, 527, "transparent", (80, 80)),
    "wear_oil": ("wear", 136, 614, 230, 706, "transparent", (80, 80)),
    "wear_smoke": ("wear", 238, 614, 333, 706, "transparent", (80, 80)),
    "wear_electric_leak": ("wear", 683, 613, 778, 707, "transparent", (80, 80)),
    "wear_sparks": ("wear", 789, 613, 852, 707, "transparent", (64, 80)),
    "wear_vapor": ("wear", 858, 613, 943, 707, "transparent", (72, 80)),
    "wear_exposed_cables": ("wear", 1286, 613, 1396, 707, "transparent", (96, 80)),

    # Signs and navigation props.
    "sign_energy": ("signage", 38, 272, 194, 374, "transparent", (144, 88)),
    "sign_sector": ("signage", 214, 266, 339, 377, "transparent", (112, 96)),
    "sign_direction": ("signage", 363, 277, 495, 369, "transparent", (120, 80)),
    "sign_warning": ("signage", 513, 272, 674, 374, "transparent", (144, 88)),
    "sign_maintenance": ("signage", 696, 272, 878, 374, "transparent", (160, 88)),
    "sign_exit": ("signage", 899, 272, 1066, 374, "transparent", (152, 88)),
    "arrow_right": ("signage", 37, 463, 116, 520, "transparent", (64, 48)),
    "arrow_left": ("signage", 133, 463, 213, 520, "transparent", (64, 48)),
    "arrow_double": ("signage", 234, 463, 316, 520, "transparent", (64, 48)),
    "arrow_up": ("signage", 333, 453, 406, 526, "transparent", (64, 64)),
    "floor_safe": ("signage", 697, 484, 801, 520, "transparent", (96, 32)),
    "floor_danger": ("signage", 815, 484, 929, 520, "transparent", (96, 32)),
    "symbol_electric": ("signage", 617, 610, 704, 704, "transparent", (72, 72)),
    "symbol_no_entry": ("signage", 718, 610, 808, 704, "transparent", (72, 72)),
    "symbol_authorized": ("signage", 820, 610, 912, 704, "transparent", (72, 72)),
}


def _save_transparent(source: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    foreground = _extract_foreground(source.crop(box))
    bbox = foreground.getbbox()
    if bbox is None:
        return Image.new("RGBA", size)
    content = foreground.crop(bbox)
    scale = min(size[0] / content.width, size[1] / content.height)
    resized = content.resize(
        (max(1, round(content.width * scale)), max(1, round(content.height * scale))),
        Image.Resampling.NEAREST,
    )
    output = Image.new("RGBA", size)
    output.alpha_composite(resized, ((size[0] - resized.width) // 2, size[1] - resized.height))
    return output


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    SOURCE_ASSET_ROOT.mkdir(parents=True, exist_ok=True)
    sources: dict[str, Image.Image] = {}
    for key, filename in SOURCES.items():
        source_path = SOURCE_ROOT / filename
        shutil.copy2(source_path, SOURCE_ASSET_ROOT / filename)
        sources[key] = Image.open(source_path).convert("RGB")

    manifest: dict[str, object] = {"version": 1, "assets": {}}
    for name, (source_key, left, top, right, bottom, mode, size) in ASSETS.items():
        source = sources[source_key]
        box = (left, top, right, bottom)
        if mode == "transparent":
            image = _save_transparent(source, box, size)
        else:
            image = source.crop(box).resize(size, Image.Resampling.NEAREST).convert("RGBA")
        output = OUTPUT_ROOT / f"{name}.png"
        image.save(output, optimize=True)
        manifest["assets"][name] = {
            "path": output.relative_to(ROOT).as_posix(),
            "size": list(size),
            "source": SOURCES[source_key],
            "crop": [left, top, right, bottom],
            "mode": mode,
        }

    (OUTPUT_ROOT / "environment_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Generated {len(ASSETS)} environment assets in {OUTPUT_ROOT}")


if __name__ == "__main__":
    main()
