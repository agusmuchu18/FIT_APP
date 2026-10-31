"""Encode generated originals to local WebP; keep all originals untouched."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
manifest = root / 'docs/design/WORKOUT_ASSETS_2026_10_12.json'
data = json.loads(manifest.read_text(encoding='utf-8'))
sheet = Image.new('RGB', (1500, 700), '#17212d')
draw = ImageDraw.Draw(sheet)
for index, asset in enumerate(data['assets']):
    with Image.open(asset['source']) as image:
        image = image.convert('RGB')
        image.thumbnail((asset['maxWidth'], asset['maxWidth']))
        target = root / asset['file']
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            raise FileExistsError(target)
        image.save(target, 'WEBP', quality=82, method=6)
        asset['bytes'] = target.stat().st_size
        asset['width'], asset['height'] = image.size
        preview = image.copy()
        preview.thumbnail((284, 300))
        x, y = (index % 5) * 300, (index // 5) * 350
        sheet.paste(preview, (x, y + 26))
        draw.text((x + 8, y + 4), asset['name'], fill='#ffffff')
manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
preview_path = root / 'build/workout_art_contact_sheet.jpg'
sheet.save(preview_path, quality=90)
print(f"{len(data['assets'])} assets, {sum(a['bytes'] for a in data['assets'])} bytes. Preview: {preview_path}")
