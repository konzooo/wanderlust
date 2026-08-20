#!/usr/bin/env python3
"""Build and verify a four-panel Wanderlust App Store screenshot set."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SCREENSHOTS = ROOT / "screenshots"
TARGET_WIDTH = 1284
TARGET_HEIGHT = 2778

PROFILES = {
    "group-v1": {
        "panels": (
            ("01-get-inspired.png", SCREENSHOTS / "01-get-inspired" / "imagegen-edit-a.png"),
            ("02-based-on-personality.png", SCREENSHOTS / "02-based-on-personality" / "imagegen-clean.png"),
            ("03-unique-path.png", SCREENSHOTS / "03-unique-path" / "imagegen-edit-b.png"),
            ("04-group-trips.png", SCREENSHOTS / "04-group-trips" / "imagegen-concept.png"),
        ),
        "output_dir": SCREENSHOTS / "final-appstore-1284x2778-group-v1",
        "master_path": SCREENSHOTS / "panorama" / "four-panel-2026-08-20-master.png",
        "showcase_path": SCREENSHOTS / "showcase-four-panel-1284x2778.png",
    },
    "theme-v2": {
        "panels": (
            ("01-get-inspired.png", SCREENSHOTS / "theme-v2" / "01-get-inspired" / "selected.png"),
            ("02-based-on-personality.png", SCREENSHOTS / "theme-v2" / "02-based-on-personality" / "selected.png"),
            ("03-unique-path.png", SCREENSHOTS / "theme-v2" / "03-unique-path" / "selected.png"),
            ("04-group-trips.png", SCREENSHOTS / "theme-v2" / "04-group-trips" / "selected.png"),
        ),
        "output_dir": SCREENSHOTS / "final-appstore-1284x2778-theme-v2",
        "master_path": SCREENSHOTS / "panorama" / "four-panel-theme-v2-master.png",
        "showcase_path": SCREENSHOTS / "showcase-four-panel-theme-v2.png",
    },
    "continuous-v3": {
        "master_source": (
            SCREENSHOTS / "continuous-v3" / "master-variants" / "v1.png"
        ),
        "filenames": (
            "01-get-inspired.png",
            "02-based-on-personality.png",
            "03-unique-path.png",
            "04-group-trips.png",
        ),
        "output_dir": (
            SCREENSHOTS / "final-appstore-1284x2778-continuous-v3"
        ),
        "master_path": (
            SCREENSHOTS / "panorama" / "four-panel-continuous-v3-master.png"
        ),
        "showcase_path": SCREENSHOTS / "showcase-four-panel-continuous-v3.png",
    },
    "continuous-v4-five-panel": {
        "master_source": (
            SCREENSHOTS
            / "continuous-v4-five-panel"
            / "master-variants"
            / "v3.png"
        ),
        "filenames": (
            "01-get-inspired.png",
            "02-based-on-personality.png",
            "03-unique-path.png",
            "04-group-trips.png",
            "05-traveler-dna-profiles.png",
        ),
        "output_dir": (
            SCREENSHOTS / "final-appstore-1284x2778-continuous-v4-five-panel"
        ),
        "master_path": (
            SCREENSHOTS
            / "panorama"
            / "five-panel-continuous-v4-master.png"
        ),
        "showcase_path": (
            SCREENSHOTS / "showcase-five-panel-continuous-v4.png"
        ),
    },
}


def cover_resize(
    image: Image.Image,
    target_width: int = TARGET_WIDTH,
    target_height: int = TARGET_HEIGHT,
) -> Image.Image:
    """Resize without distortion, then crop the tiny aspect-ratio excess."""
    scale = max(target_width / image.width, target_height / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - target_width) // 2
    top = (resized.height - target_height) // 2
    return resized.crop(
        (left, top, left + target_width, top + target_height)
    ).convert("RGB")


def build(profile_name: str) -> None:
    profile = PROFILES[profile_name]
    output_dir = profile["output_dir"]
    master_path = profile["master_path"]
    showcase_path = profile["showcase_path"]
    output_dir.mkdir(parents=True, exist_ok=True)
    master_path.parent.mkdir(parents=True, exist_ok=True)

    rendered: list[tuple[str, Image.Image]] = []
    if "master_source" in profile:
        filenames = profile["filenames"]
        master = cover_resize(
            Image.open(profile["master_source"]).convert("RGB"),
            TARGET_WIDTH * len(filenames),
            TARGET_HEIGHT,
        )
        for index, filename in enumerate(filenames):
            left = index * TARGET_WIDTH
            panel = master.crop(
                (left, 0, left + TARGET_WIDTH, TARGET_HEIGHT)
            ).convert("RGB")
            panel.save(output_dir / filename, "PNG", optimize=True)
            rendered.append((filename, panel))
    else:
        for filename, source_path in profile["panels"]:
            panel = cover_resize(Image.open(source_path).convert("RGB"))
            output_path = output_dir / filename
            panel.save(output_path, "PNG", optimize=True)
            rendered.append((filename, panel))

        master = Image.new(
            "RGB",
            (TARGET_WIDTH * len(rendered), TARGET_HEIGHT),
            (88, 111, 242),
        )
        for index, (_, panel) in enumerate(rendered):
            master.paste(panel, (index * TARGET_WIDTH, 0))
    master.save(master_path, "PNG", optimize=True)

    if "master_source" in profile:
        showcase_width = 1800
        showcase_height = round(showcase_width * master.height / master.width)
        showcase = master.resize(
            (showcase_width, showcase_height), Image.Resampling.LANCZOS
        )
    else:
        preview_height = 900
        preview_width = round(TARGET_WIDTH * preview_height / TARGET_HEIGHT)
        gap = 24
        margin = 36
        showcase = Image.new(
            "RGB",
            (
                margin * 2
                + preview_width * len(rendered)
                + gap * (len(rendered) - 1),
                margin * 2 + preview_height,
            ),
            "white",
        )
        for index, (_, panel) in enumerate(rendered):
            preview = panel.resize(
                (preview_width, preview_height), Image.Resampling.LANCZOS
            )
            x = margin + index * (preview_width + gap)
            showcase.paste(preview, (x, margin))
    showcase.save(showcase_path, "PNG", optimize=True)

    for filename, panel in rendered:
        assert panel.size == (TARGET_WIDTH, TARGET_HEIGHT), filename
        assert panel.mode == "RGB", filename
        print(f"verified {filename}: {panel.width}x{panel.height}, {panel.mode}")
    print(f"profile: {profile_name}")
    print(f"master: {master_path} ({master.width}x{master.height}, {master.mode})")
    print(f"showcase: {showcase_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=sorted(PROFILES), default="group-v1")
    args = parser.parse_args()
    build(args.profile)
