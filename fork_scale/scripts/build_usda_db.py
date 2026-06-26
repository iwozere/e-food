"""
Build usda_nutrition.db from USDA FoodData Central SR Legacy data.

Usage:
    pip install requests
    python scripts/build_usda_db.py

Downloads the SR Legacy JSON (~45 MB), extracts food name, energy (kcal/100g)
and macronutrients (protein/carbs/fat per 100 g), and writes
assets/db/usda_nutrition.db ready to bundle with the Flutter app.
"""

import json
import os
import sqlite3
import urllib.request
import zipfile
import tempfile

URL = "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_json_2021-10-28.zip"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "db", "usda_nutrition.db")

def download(url: str, dest: str):
    print(f"Downloading {url} …")
    urllib.request.urlretrieve(url, dest)
    print("Done.")

def build(json_path: str, db_path: str):
    print("Parsing JSON …")
    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)

    foods = data.get("SRLegacyFoods") or data.get("FoundationFoods") or []
    print(f"Found {len(foods)} foods")

    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute("DROP TABLE IF EXISTS foods")
    c.execute("""
        CREATE TABLE foods (
            id                INTEGER PRIMARY KEY,
            description       TEXT NOT NULL,
            kcal_per_100g     REAL NOT NULL,
            protein_per_100g  REAL,
            carbs_per_100g    REAL,
            fat_per_100g      REAL
        )
    """)
    c.execute("CREATE INDEX idx_desc ON foods(LOWER(description))")

    # USDA FoodData Central nutrient numbers (amounts are per 100 g for SR Legacy).
    ENERGY_KCAL = ("208", 1008)
    PROTEIN = ("203", 1003)
    FAT = ("204", 1004)
    CARBS = ("205", 1005)

    def amount_for(nutrients, number_id):
        number, nid = number_id
        for nutrient in nutrients:
            n = nutrient.get("nutrient", {})
            if n.get("number") == number or n.get("id") == nid:
                return nutrient.get("amount")
        return None

    inserted = 0
    for food in foods:
        desc = food.get("description", "").strip()
        if not desc:
            continue
        nutrients = food.get("foodNutrients", [])
        kcal = amount_for(nutrients, ENERGY_KCAL)
        if kcal is None:
            continue
        protein = amount_for(nutrients, PROTEIN)
        carbs = amount_for(nutrients, CARBS)
        fat = amount_for(nutrients, FAT)
        c.execute(
            "INSERT INTO foods(id, description, kcal_per_100g, "
            "protein_per_100g, carbs_per_100g, fat_per_100g) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (
                food.get("fdcId"),
                desc,
                float(kcal),
                float(protein) if protein is not None else None,
                float(carbs) if carbs is not None else None,
                float(fat) if fat is not None else None,
            ),
        )
        inserted += 1

    conn.commit()
    conn.close()
    print(f"Inserted {inserted} foods -> {db_path}")

def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        zip_path = os.path.join(tmp, "usda.zip")
        download(URL, zip_path)
        print("Extracting …")
        with zipfile.ZipFile(zip_path) as z:
            names = z.namelist()
            json_name = next(n for n in names if n.endswith(".json"))
            z.extract(json_name, tmp)
        build(os.path.join(tmp, json_name), OUT)
    print("usda_nutrition.db ready.")

if __name__ == "__main__":
    main()
