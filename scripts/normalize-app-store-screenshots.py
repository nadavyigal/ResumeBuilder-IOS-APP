#!/usr/bin/env python3

from pathlib import Path
import sys

from PIL import Image, ImageOps


TARGETS = {
    "iphone-6.5-1242x2688": (1242, 2688),
    "ipad-13": (2064, 2752),
}


def normalize(folder: Path, size: tuple[int, int]) -> None:
    files = sorted(folder.glob("*.png"))
    if len(files) != 10:
        raise RuntimeError(f"{folder}: expected 10 PNG files, found {len(files)}")

    for path in files:
        with Image.open(path) as source:
            normalized = ImageOps.fit(
                source.convert("RGB"),
                size,
                method=Image.Resampling.LANCZOS,
            )
            temporary = path.with_suffix(".normalized.png")
            normalized.save(temporary, format="PNG", optimize=True)
        temporary.replace(path)


def main() -> None:
    root = Path(
        sys.argv[1] if len(sys.argv) > 1 else "dist/app-store-screenshots/app-store-v1"
    )
    for folder_name, size in TARGETS.items():
        normalize(root / folder_name, size)


if __name__ == "__main__":
    main()
