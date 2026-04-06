from pathlib import Path
from PIL import Image

INPUT_DIR = Path("assets/markers_raw")      # ham ikonlar burada
OUTPUT_DIR = Path("assets/markers")         # düzenlenmiş ikonlar burada
CANVAS_SIZE = (48, 48)                      # final boyut
ICON_MAX_SIZE = (34, 34)                    # ikonun canvas içindeki max alanı

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def normalize_icon(input_path: Path, output_path: Path):
    img = Image.open(input_path).convert("RGBA")

    # Oranı bozmadan küçült
    img.thumbnail(ICON_MAX_SIZE, Image.LANCZOS)

    # Şeffaf canvas
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))

    # Ortala
    x = (CANVAS_SIZE[0] - img.width) // 2
    y = (CANVAS_SIZE[1] - img.height) // 2

    canvas.paste(img, (x, y), img)
    canvas.save(output_path)

valid_exts = {".png", ".jpg", ".jpeg", ".webp"}

for file_path in INPUT_DIR.iterdir():
    if file_path.suffix.lower() in valid_exts:
        out_name = file_path.stem + ".png"
        output_path = OUTPUT_DIR / out_name
        normalize_icon(file_path, output_path)
        print(f"OK: {file_path.name} -> {output_path.name}")

print("Bitti.")