# Offline nutrition data

`usda_foundation_2026_04.json` is a compact projection of the official USDA
FoodData Central Foundation Foods JSON release dated 2026-04-30.

- Source: https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-04-30.zip
- License: United States public domain.
- Included: 363 valid foods (32 null placeholder rows excluded), FDC ID,
  description, category, serving grams and protein/carbohydrate/fat per 100 g.
- Energy: USDA nutrient 208 when supplied; otherwise a documented 4/4/9
  derivation from the included USDA macronutrients.
- Spanish aliases are maintained in `offline_food_catalog.dart`; original USDA
  descriptions remain unchanged to preserve traceability.

Do not hand-edit nutrient values. Regenerate from a dated official release and
update its tests, release metadata and this note together.
