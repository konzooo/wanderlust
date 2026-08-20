#!/usr/bin/env python3
"""Build and verify the selected five-panel App Store screenshot set."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SCREENSHOTS = ROOT / "screenshots"
MASTER_SOURCE = SCREENSHOTS / "continuous-v4-five-panel" / "master.png"
OUTPUT_DIR = (
    SCREENSHOTS / "final-appstore-1284x2778-continuous-v4-five-panel"
)
TARGET_WIDTH = 1284
TARGET_HEIGHT = 2778
FILENAMES = (
    "01-get-inspired.png",
    "02-based-on-personality.png",
    "03-unique-path.png",
    "04-group-trips.png",
    "05-traveler-dna-profiles.png",
)


def cover_resize(
    image: Image.Image,
    target_width: int,
    target_height: int,
) -> Image.Image:
    """Resize without distortion, then crop the aspect-ratio excess."""
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


def build() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    master = cover_resize(
        Image.open(MASTER_SOURCE).convert("RGB"),
        TARGET_WIDTH * len(FILENAMES),
        TARGET_HEIGHT,
    )

    for index, filename in enumerate(FILENAMES):
        left = index * TARGET_WIDTH
        panel = master.crop(
            (left, 0, left + TARGET_WIDTH, TARGET_HEIGHT)
        ).convert("RGB")
        panel.save(OUTPUT_DIR / filename, "PNG", optimize=True)
        assert panel.size == (TARGET_WIDTH, TARGET_HEIGHT), filename
        assert panel.mode == "RGB", filename
        print(f"verified {filename}: {panel.width}x{panel.height}, {panel.mode}")


if __name__ == "__main__":
    build()
