"""
Build usda_nutrition.db from USDA FoodData Central SR Legacy data.

Usage:
    pip install requests
    python scripts/build_usda_db.py

Downloads the SR Legacy JSON (~45 MB), extracts food name + energy (kcal/100g),
and writes assets/db/usda_nutrition.db ready to bundle with the Flutter app.
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
            id              INTEGER PRIMARY KEY,
            description     TEXT NOT NULL,
            kcal_per_100g   REAL NOT NULL
        )
    """)
    c.execute("CREATE INDEX idx_desc ON foods(LOWER(description))")

    inserted = 0
    for food in foods:
        desc = food.get("description", "").strip()
        if not desc:
            continue
        kcal = None
        for nutrient in food.get("foodNutrients", []):
            # nutrient number 208 = Energy (kcal)
            n = nutrient.get("nutrient", {})
            if n.get("number") == "208" or n.get("id") == 1008:
                kcal = nutrient.get("amount")
                break
        if kcal is None:
            continue
        c.execute(
            "INSERT INTO foods(id, description, kcal_per_100g) VALUES (?, ?, ?)",
            (food.get("fdcId"), desc, float(kcal)),
        )
        inserted += 1

    conn.commit()
    conn.close()
    print(f"Inserted {inserted} foods → {db_path}")

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
