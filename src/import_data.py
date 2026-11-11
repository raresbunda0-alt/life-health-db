"""
import_data.py
Loads the WHO and World Bank files from data/raw into the PostgreSQL database.
Run sql/01_schema.sql first. This script can be run again: it empties the
data tables (not the sex table) before loading.

Pipeline: source files -> validation -> cleaning -> transformation -> database
"""
import csv
import json
from datetime import date
from getpass import getpass
from pathlib import Path

import psycopg

RAW = Path("data/raw")
YEAR_FROM, YEAR_TO = 2000, 2022          # years that all 3 sources share
RETRIEVED_ON = date(2026, 11, 11)

WB_DATA = RAW / "API_SP.DYN.LE00.IN_DS2_en_csv_v2_260452.csv"
WB_META = RAW / "Metadata_Country_API_SP.DYN.LE00.IN_DS2_en_csv_v2_260452.csv"

# key, name, organization, url, license
SOURCES = [
    ("PAA", "WHO GHO: Insufficient physical activity, adults 18+, age-standardized",
     "World Health Organization (Global Health Observatory)",
     "https://ghoapi.azureedge.net/api/NCD_PAA",
     "CC BY-NC-SA 3.0 IGO"),
    ("OB", "WHO GHO: Obesity among adults, BMI >= 30, crude estimate",
     "World Health Organization (Global Health Observatory)",
     "https://ghoapi.azureedge.net/api/NCD_BMI_30C",
     "CC BY-NC-SA 3.0 IGO"),
    ("LE", "World Bank: Life expectancy at birth, total (years)",
     "World Bank (World Development Indicators)",
     "https://data.worldbank.org/indicator/SP.DYN.LE00.IN",
     "CC BY 4.0"),
]

# code, name, unit, source key
INDICATORS = [
    ("NCD_PAA", "Insufficient physical activity, adults 18+, age-standardized", "%", "PAA"),
    ("NCD_BMI_30C", "Obesity among adults, BMI >= 30, crude", "%", "OB"),
    ("SP.DYN.LE00.IN", "Life expectancy at birth, total", "years", "LE"),
]


# ---------- reading and cleaning ----------

def read_who(filename):
    """Read a WHO file. Keep only countries, age group 18+, chosen years, existing values."""
    with open(RAW / filename, encoding="utf-8") as f:
        rows = json.load(f)["value"]
    kept = []
    for r in rows:
        if r["SpatialDimType"] != "COUNTRY":
            continue
        if r["Dim2"] != "AGEGROUP_YEARS18-PLUS":
            continue
        if not (YEAR_FROM <= r["TimeDim"] <= YEAR_TO):
            continue
        if r["NumericValue"] is None:
            continue
        kept.append(r)
    return len(rows), kept


def read_world_bank_csv(path):
    """The World Bank CSV has a few non-data lines before the real header."""
    with open(path, encoding="utf-8-sig", newline="") as f:
        lines = f.read().splitlines()
    start = next(i for i, line in enumerate(lines)
                 if line.startswith('"Country Name"') or line.startswith('"Country Code"'))
    return list(csv.DictReader(lines[start:]))


def rnd(x):
    return None if x is None else round(x, 3)


def build_who_observations(rows, indicator_code, subset):
    out, seen = [], set()
    for r in rows:
        iso3 = r["SpatialDim"]
        if iso3 not in subset:
            continue
        value, low, high = rnd(r["NumericValue"]), rnd(r["Low"]), rnd(r["High"])
        key = (iso3, r["Dim1"], r["TimeDim"])
        if key in seen:                                   # duplicate
            continue
        if value < 0 or (low is not None and low < 0):    # invalid value
            continue
        if low is not None and high is not None and low > high:
            continue
        seen.add(key)
        out.append((iso3, indicator_code, r["Dim1"], r["TimeDim"], value, low, high))
    return out


def build_world_bank_observations(wb_by_code, subset):
    """Turn the wide table (one column per year) into one row per country and year."""
    out = []
    for iso3 in sorted(subset):
        row = wb_by_code[iso3]
        for year in range(YEAR_FROM, YEAR_TO + 1):
            text = (row.get(str(year)) or "").strip()
            if text:                                       # skip empty cells
                out.append((iso3, "SP.DYN.LE00.IN", "SEX_BTSX", year,
                            rnd(float(text)), None, None))
    return out


# ---------- main ----------

def main():
    password = getpass("PostgreSQL password for user postgres (typing is hidden): ")

    print("Reading source files...")
    pa_total, pa_rows = read_who("who_NCD_PAA.json")
    ob_total, ob_rows = read_who("who_obesity_crude.json")
    wb_data = read_world_bank_csv(WB_DATA)
    wb_meta = read_world_bank_csv(WB_META)

    # Real countries have a Region in the metadata; aggregates (World, ...) do not
    meta = {m["Country Code"]: m for m in wb_meta if m["Region"].strip()}
    wb_by_code = {r["Country Code"]: r for r in wb_data if r["Country Code"] in meta}
    year_cols = [k for k in wb_data[0].keys() if k and k.isdigit()]
    wb_total = len(wb_by_code) * len(year_cols)

    # Subset: countries present in all three sources
    subset = ({r["SpatialDim"] for r in pa_rows}
              & {r["SpatialDim"] for r in ob_rows}
              & set(wb_by_code))
    print("Countries in subset:", len(subset))

    # WHO region of every country (from the WHO files)
    who_regions, country_who = {}, {}
    for r in pa_rows + ob_rows:
        if r["SpatialDim"] in subset and r["ParentLocationCode"]:
            who_regions.setdefault(r["ParentLocationCode"], r["ParentLocation"])
            country_who.setdefault(r["SpatialDim"], r["ParentLocationCode"])

    observations = {
        "PAA": build_who_observations(pa_rows, "NCD_PAA", subset),
        "OB": build_who_observations(ob_rows, "NCD_BMI_30C", subset),
        "LE": build_world_bank_observations(wb_by_code, subset),
    }
    rows_read = {"PAA": pa_total, "OB": ob_total, "LE": wb_total}

    print("Loading into the database...")
    with psycopg.connect(host="localhost", port=5432, dbname="life_health_db",
                         user="postgres", password=password) as conn:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE observation, country, indicator, import_batch, "
                        "data_source, income_group, wb_region, who_region "
                        "RESTART IDENTITY CASCADE")

            source_id = {}
            for key, name, org, url, lic in SOURCES:
                cur.execute("INSERT INTO data_source (name, organization, url, license, retrieved_on) "
                            "VALUES (%s, %s, %s, %s, %s) RETURNING source_id",
                            (name, org, url, lic, RETRIEVED_ON))
                source_id[key] = cur.fetchone()[0]

            for code, name, unit, key in INDICATORS:
                cur.execute("INSERT INTO indicator (code, name, unit, source_id) "
                            "VALUES (%s, %s, %s, %s)", (code, name, unit, source_id[key]))

            for code, name in sorted(who_regions.items()):
                cur.execute("INSERT INTO who_region (code, name) VALUES (%s, %s)", (code, name))
            for name in sorted({meta[c]["Region"] for c in subset}):
                cur.execute("INSERT INTO wb_region (name) VALUES (%s)", (name,))
            for name in sorted({meta[c]["IncomeGroup"] for c in subset}):
                cur.execute("INSERT INTO income_group (name) VALUES (%s)", (name,))

            cur.execute("SELECT code, who_region_id FROM who_region")
            who_id = dict(cur.fetchall())
            cur.execute("SELECT name, wb_region_id FROM wb_region")
            wb_id = dict(cur.fetchall())
            cur.execute("SELECT name, income_group_id FROM income_group")
            inc_id = dict(cur.fetchall())

            for iso3 in sorted(subset):
                cur.execute(
                    "INSERT INTO country (iso3, name, who_region_id, wb_region_id, income_group_id) "
                    "VALUES (%s, %s, %s, %s, %s)",
                    (iso3, wb_by_code[iso3]["Country Name"],
                     who_id.get(country_who.get(iso3)),
                     wb_id.get(meta[iso3]["Region"]),
                     inc_id.get(meta[iso3]["IncomeGroup"])))

            cur.execute("SELECT iso3, country_id FROM country")
            country_id = dict(cur.fetchall())
            cur.execute("SELECT code, indicator_id FROM indicator")
            indicator_id = dict(cur.fetchall())
            cur.execute("SELECT code, sex_id FROM sex")
            sex_id = dict(cur.fetchall())

            for key in ("PAA", "OB", "LE"):
                obs = [o for o in observations[key] if o[2] in sex_id]
                cur.execute("INSERT INTO import_batch (source_id, rows_read, rows_loaded, rows_rejected) "
                            "VALUES (%s, %s, %s, %s) RETURNING batch_id",
                            (source_id[key], rows_read[key], len(obs), rows_read[key] - len(obs)))
                batch_id = cur.fetchone()[0]
                cur.executemany(
                    "INSERT INTO observation (country_id, indicator_id, sex_id, year, value, "
                    "ci_low, ci_high, batch_id) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                    [(country_id[o[0]], indicator_id[o[1]], sex_id[o[2]], o[3], o[4], o[5], o[6], batch_id)
                     for o in obs])
                print(f"  {key}: read {rows_read[key]}, loaded {len(obs)}")

            for table in ("data_source", "import_batch", "who_region", "wb_region",
                          "income_group", "country", "sex", "indicator", "observation"):
                cur.execute(f"SELECT count(*) FROM {table}")
                print(f"  table {table}: {cur.fetchone()[0]} rows")
    print("Done.")


main()