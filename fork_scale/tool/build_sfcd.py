#!/usr/bin/env python3
"""
build_sfcd.py — Build the Swiss Food Composition Database (SFCD) asset
=====================================================================

Downloads the Swiss Federal Food Safety and Veterinary Office (BLV/OSAV)
generic food composition data and builds a SQLite asset used by ForkScale
for ingredient autocomplete in the Recipe Editor.

Source:  https://naehrwertdaten.ch/de/downloads/
Licence: CC BY 4.0  (attribution: Swiss Federal Food Safety and Veterinary Office)

USAGE
-----
  1. Install dependencies (one time):
       pip install openpyxl

  2. Run from the fork_scale directory:
       python tool/build_sfcd.py

  3. After the script finishes, add the asset to pubspec.yaml:
       flutter:
         assets:
           - assets/db/usda_nutrition.db
           - assets/db/sfcd.db        ← add this line

  4. Rebuild the app:
       flutter run

NOTES
-----
- The script downloads the latest XLSX export from naehrwertdaten.ch (~700 KB).
  If the URL returns 404 in a future release, check naehrwertdaten.ch/de/downloads/
  and update DOWNLOAD_URL below.
- The database contains German-language food names only.
- The resulting sfcd.db is ~300–500 KB and can be committed to git.
- Re-run the script when a new SFCD version is published (annual cadence).
"""

import io
import sqlite3
import sys
import urllib.request
from pathlib import Path

# ── Configuration ─────────────────────────────────────────────────────────────

DOWNLOAD_URL = (
    "https://webapp.prod.blv.foodcase-services.com/wp-content/uploads/2025/07/"
    "Schweizer_Nahrwertdatenbank.xlsx"
)

ASSET_DIR = Path(__file__).parent.parent / "assets" / "db"
OUTPUT_PATH = ASSET_DIR / "sfcd.db"

# ── Download ──────────────────────────────────────────────────────────────────

def download_xlsx(url: str) -> bytes:
    print(f"Downloading SFCD export from:\n  {url}")
    req = urllib.request.Request(
        url, headers={"User-Agent": "ForkScale/1.0 build_sfcd.py"}
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        total = int(resp.headers.get("Content-Length", 0))
        data = bytearray()
        chunk_size = 65536
        downloaded = 0
        while True:
            chunk = resp.read(chunk_size)
            if not chunk:
                break
            data.extend(chunk)
            downloaded += len(chunk)
            if total:
                pct = downloaded / total * 100
                print(f"\r  {downloaded // 1024} KB / {total // 1024} KB ({pct:.0f}%)",
                      end="", flush=True)
        print()
    print(f"  Downloaded {len(data) // 1024} KB.")
    return bytes(data)

# ── Parse ─────────────────────────────────────────────────────────────────────

def parse_xlsx(data: bytes) -> list[dict]:
    try:
        import openpyxl
    except ImportError:
        sys.exit("ERROR: openpyxl is required. Run: pip install openpyxl")

    wb = openpyxl.load_workbook(io.BytesIO(data), read_only=True, data_only=True)

    # Use the first sheet (generic foods), skip branded products sheet.
    ws = wb.worksheets[0]
    all_rows = list(ws.iter_rows(values_only=True))

    # Auto-detect header row: the first row where we find both a "Name" column
    # and an energy (kcal) column.
    header_idx = None
    col_name = None
    col_kcal = None
    col_fat = None
    col_carbs = None
    col_protein = None

    for i, row in enumerate(all_rows[:10]):
        cells = [str(c).strip() if c is not None else "" for c in row]
        # Look for Name column
        name_candidates = [j for j, c in enumerate(cells)
                           if c.lower() in ("name", "lebensmittel", "bezeichnung")]
        kcal_candidates = [j for j, c in enumerate(cells)
                           if "kcal" in c.lower() and "energie" in c.lower()]
        if not kcal_candidates:
            kcal_candidates = [j for j, c in enumerate(cells) if "kcal" in c.lower()]
        if name_candidates and kcal_candidates:
            header_idx = i
            col_name = name_candidates[0]
            col_kcal = kcal_candidates[0]
            # Try to find fat, carbs, protein columns
            for j, c in enumerate(cells):
                cl = c.lower()
                if "fett" in cl and "total" in cl and col_fat is None:
                    col_fat = j
                if ("kohlenhydrat" in cl or "carbohydrat" in cl) and col_carbs is None:
                    col_carbs = j
                if "protein" in cl and col_protein is None:
                    col_protein = j
            print(f"  Header row detected at index {i}.")
            print(f"  Name col [{col_name}], kcal col [{col_kcal}], "
                  f"fat [{col_fat}], carbs [{col_carbs}], protein [{col_protein}]")
            break

    if header_idx is None:
        sys.exit(
            "ERROR: Could not auto-detect header row.\n"
            "Check that the spreadsheet has 'Name' and 'kcal' columns.\n"
            f"First 5 rows: {[list(r[:6]) for r in all_rows[:5]]}"
        )

    data_rows = all_rows[header_idx + 1:]
    records = []
    for row in data_rows:
        def cell(idx):
            if idx is None or idx >= len(row):
                return None
            v = row[idx]
            return str(v).strip() if v is not None else None

        name = cell(col_name) or ""
        if not name:
            continue

        kcal_raw = cell(col_kcal)
        try:
            kcal = float(str(kcal_raw).replace(",", ".")) if kcal_raw else None
        except ValueError:
            kcal = None
        if kcal is None:
            continue

        fat_raw = cell(col_fat)
        carbs_raw = cell(col_carbs)
        protein_raw = cell(col_protein)

        def to_float(v):
            try:
                return float(str(v).replace(",", ".")) if v else None
            except ValueError:
                return None

        records.append({
            "name": name,
            "energy_kcal_100g": kcal,
            "fat_g": to_float(fat_raw),
            "carbs_g": to_float(carbs_raw),
            "protein_g": to_float(protein_raw),
        })

    return records

# ── Build SQLite ──────────────────────────────────────────────────────────────

def build_sqlite(records: list[dict], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    conn = sqlite3.connect(str(output))
    try:
        conn.execute("""
            CREATE TABLE swiss_fcd_items (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                name_de          TEXT NOT NULL,
                name_fr          TEXT,
                name_en          TEXT,
                energy_kcal_100g REAL NOT NULL,
                fat_g            REAL,
                carbs_g          REAL,
                protein_g        REAL
            )
        """)
        conn.execute(
            "CREATE INDEX idx_sfcd_name ON swiss_fcd_items(name_de COLLATE NOCASE)"
        )
        conn.executemany(
            """INSERT INTO swiss_fcd_items
               (name_de, name_fr, name_en, energy_kcal_100g, fat_g, carbs_g, protein_g)
               VALUES (?,?,?,?,?,?,?)""",
            [
                (
                    r["name"],
                    r["name"],   # no FR/EN in v7; duplicate DE so search works
                    r["name"],
                    r["energy_kcal_100g"],
                    r["fat_g"],
                    r["carbs_g"],
                    r["protein_g"],
                )
                for r in records
            ],
        )
        conn.commit()
    finally:
        conn.close()

    size_kb = output.stat().st_size // 1024
    print(f"  Wrote {len(records)} rows to {output}  ({size_kb} KB)")

# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print("=== ForkScale SFCD asset builder ===\n")
    raw = download_xlsx(DOWNLOAD_URL)
    print("\nParsing spreadsheet...")
    records = parse_xlsx(raw)
    print(f"  Parsed {len(records)} food items.\n")
    print("Building SQLite asset...")
    build_sqlite(records, OUTPUT_PATH)
    print("""
Done!

Next steps:
  1. Add the asset to fork_scale/pubspec.yaml under flutter > assets:
       - assets/db/sfcd.db

  2. Run: flutter pub get && flutter run
""")

if __name__ == "__main__":
    main()
