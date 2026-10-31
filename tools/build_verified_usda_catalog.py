"""Build a compact, source-preserving USDA Foundation catalog (no inference).

Download the pinned public ZIP from docs/nutrition/FOOD_DATA_SOURCES.md, then:
  python tools/build_verified_usda_catalog.py --input PATH_TO_ZIP
Only reproducible public catalog data is written; user data is never opened.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import zipfile

URL = 'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-10-29.zip'
SHA256 = 'dd414cc9f1a132626bad354ef6655972c78b44aff14f16114dc899708663c579'
RELEASE = '2026-10-29'
MICROS = {'fiber_g': ('291','g'), 'sugar_g': ('269','g'),
          'saturatedFat_g': ('606','g'), 'sodium_mg': ('307','mg'),
          'potassium_mg': ('306','mg'), 'calcium_mg': ('301','mg'),
          'iron_mg': ('303','mg'), 'magnesium_mg': ('304','mg'),
          'vitaminC_mg': ('401','mg'), 'vitaminD_ug': ('328','ug')}

def number(value):
    if isinstance(value, bool) or not isinstance(value, (float,int)):
        return None
    return value if math.isfinite(value) and value >= 0 else None

def unit(value):
    return str(value).lower().replace('µ','u').replace('μ','u')

def build_food(food):
    nutrients = food.get('foodNutrients', [])
    notes = []
    def nutrient(nid, expected):
        for row in nutrients:
            definition = row.get('nutrient', {})
            if str(definition.get('number')) != nid:
                continue
            amount = number(row.get('amount'))
            if unit(definition.get('unitName')) != expected:
                notes.append(f'Nutriente {nid}: unidad de origen incompatible; se conserva como no disponible.')
                return None
            if amount is None and row.get('amount') is not None:
                notes.append(f'Nutriente {nid}: valor de origen no utilizable; no se considera cero.')
            return amount
        return None
    energy = None
    energy_method = None
    for nid, label in [('958','USDA · Atwater específico'),
                       ('957','USDA · Atwater general'),
                       ('208','USDA · energía reportada')]:
        amount = nutrient(nid,'kcal')
        if amount is not None:
            energy, energy_method = amount, label
            break
    # Each chosen weight is a supplied foodPortion weight, without rounding,
    # clamping, inferred density or an invented default serving.
    portions = [p for p in food.get('foodPortions', [])
                if number(p.get('gramWeight')) is not None
                and p['gramWeight'] > 0]
    portions.sort(key=lambda p:p.get('sequenceNumber', 0))
    portion = portions[0] if portions else None
    serving = None if portion is None else portion['gramWeight']
    label = None
    if portion:
        amount = number(portion.get('amount', portion.get('value')))
        raw_unit = portion.get('measureUnit', {}).get('name', '')
        translated = {'tablespoon':'cucharadas','teaspoon':'cucharaditas',
                      'cup':'tazas','ounce':'onzas','slice':'rebanadas',
                      'piece':'piezas','serving':'porciones'}.get(raw_unit,raw_unit)
        modifier = portion.get('modifier','')
        if translated == 'undetermined':
            translated = modifier or 'porción del catálogo'
        label = f'{amount:g} {translated}' if amount is not None else translated
        if modifier and modifier not in label:
            label += f' · {modifier}'
    category = food.get('foodCategory', {}).get('description','USDA Foundation')
    return {'id':food['fdcId'],'n':food['description'],'c':category,
            'k':energy,'p':nutrient('203','g'),'h':nutrient('205','g'),
            'f':nutrient('204','g'),'s':serving,'servingLabel':label,
            'energyMethod':energy_method,'sourceDate':food.get('publicationDate'),
            'micros':{key:nutrient(nid,expected) for key,(nid,expected) in MICROS.items()},
            'dataNotes':notes}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input',type=Path,required=True)
    args=parser.parse_args()
    raw=args.input.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=SHA256:
        raise ValueError('The ZIP does not match the pinned official release.')
    with zipfile.ZipFile(args.input) as archive:
        names=[n for n in archive.namelist() if n.endswith('.json')]
        if len(names)!=1 or archive.getinfo(names[0]).file_size>20000000:
            raise ValueError('Unexpected archive structure or size.')
        dataset=json.loads(archive.read(names[0]))
    foods=dataset['FoundationFoods']
    ids=[f['fdcId'] for f in foods]
    if len(ids)!=len(set(ids)):
        raise ValueError('Repeated USDA identifiers.')
    items=[build_food(f) for f in foods]
    root=Path(__file__).resolve().parents[1]
    destination=root/'assets/data/usda_foundation_2026_10.json'
    packet={'source':'USDA FoodData Central Foundation Foods','release':RELEASE,
            'license':'CC0-1.0','sourceUrl':URL,'sourceSha256':SHA256,
            'energy':'Reported USDA values only: 2048/958, then 2047/957, then 1008/208. No app-derived 4/4/9.',
            'items':items}
    destination.write_text(json.dumps(packet,ensure_ascii=False,separators=(',',':'),allow_nan=False),encoding='utf-8')
    print(f'{len(items)} foods; {sum(i["k"] is None for i in items)} energy values unavailable; {destination.stat().st_size} bytes')

if __name__=='__main__':
    main()
