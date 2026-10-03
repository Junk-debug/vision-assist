import sys
from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 1024
SUPERSAMPLE = 4
BLUE = (10, 89, 247, 255)
OUTER = (94, 148, 255, 255)
INNER = (156, 192, 255, 255)
WHITE = (255, 255, 255, 255)


def ring(draw, center, radius, width, color):
    draw.ellipse([center - radius, center - radius, center + radius, center + radius], outline=color, width=width)


def foreground(scale):
    size = SIZE * scale
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    c = size // 2
    ring(draw, c, int(0.300 * size), int(0.038 * size), OUTER)
    ring(draw, c, int(0.197 * size), int(0.038 * size), INNER)
    r = int(0.092 * size)
    draw.ellipse([c - r, c - r, c + r, c + r], fill=WHITE)
    return image.resize((SIZE, SIZE), Image.LANCZOS)


def background():
    return Image.new("RGBA", (SIZE, SIZE), BLUE)


def preview(fg, bg, side):
    canvas = Image.alpha_composite(bg, fg)
    mask = Image.new("L", (SIZE * SUPERSAMPLE, SIZE * SUPERSAMPLE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE * SUPERSAMPLE - 1, SIZE * SUPERSAMPLE - 1], radius=int(0.25 * SIZE * SUPERSAMPLE), fill=255)
    mask = mask.resize((SIZE, SIZE), Image.LANCZOS)
    rounded = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rounded.paste(canvas, (0, 0), mask)
    return rounded.resize((side, side), Image.LANCZOS)


def main(root):
    root = Path(root)
    fg = foreground(SUPERSAMPLE)
    bg = background()
    for media in [root / "AppScope/resources/base/media", root / "entry/src/main/resources/base/media"]:
        fg.save(media / "foreground.png")
        bg.save(media / "background.png")
    preview(fg, bg, 144).save(root / "entry/src/main/resources/base/media/startIcon.png")
    preview(fg, bg, 512).save(root / "tools/icon/preview.png")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
