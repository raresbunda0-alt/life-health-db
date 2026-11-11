import csv
import json
from collections import Counter
from pathlib import Path

RAW = Path("data/raw")


def analyze_who(filename):
    print("=" * 60)
    print("WHO FILE:", filename)
    with open(RAW / filename, encoding="utf-8") as f:
        rows = json.load(f)["value"]

    print("Total rows:", len(rows))
    print("Indicator codes:", dict(Counter(r["IndicatorCode"] for r in rows)))
    print("Location types:", dict(Counter(r["SpatialDimType"] for r in rows)))
    print("Sex values:", dict(Counter(r["Dim1"] for r in rows)))
    print("Age groups (top 10):", Counter(r["Dim2"] for r in rows).most_common(10))
    print("Number of different age groups:", len(set(r["Dim2"] for r in rows)))

    countries = set(r["SpatialDim"] for r in rows if r["SpatialDimType"] == "COUNTRY")
    years = sorted(set(r["TimeDim"] for r in rows))
    print("Distinct countries:", len(countries))
    print("Years:", years[0], "to", years[-1], "| distinct years:", len(years))
    print("WHO regions:", dict(Counter(r["ParentLocationCode"] for r in rows)))

    missing = sum(1 for r in rows if r["NumericValue"] is None)
    print("Rows with missing NumericValue:", missing)
    values = [r["NumericValue"] for r in rows if r["NumericValue"] is not None]
    print("Value range:", round(min(values), 2), "to", round(max(values), 2))

    keys = Counter(
        (r["SpatialDim"], r["TimeDim"], r["Dim1"], r["Dim2"], r["Dim3"]) for r in rows
    )
    print("Duplicate (country, year, sex, age group) combinations:",
          sum(1 for c in keys.values() if c > 1))

    adult_both = [r for r in rows if r["Dim2"] == "AGEGROUP_YEARS18-PLUS"
                  and r["Dim1"] == "SEX_BTSX"]
    print("Rows for 18+ and both sexes:", len(adult_both))
    return countries


def read_world_bank_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        lines = f.read().splitlines()
    start = next(i for i, line in enumerate(lines)
                 if line.startswith('"Country Name"') or line.startswith('"Country Code"'))
    return list(csv.DictReader(lines[start:]))


def analyze_world_bank():
    print("=" * 60)
    print("WORLD BANK: life expectancy")
    data = read_world_bank_csv(RAW / "API_SP.DYN.LE00.IN_DS2_en_csv_v2_260452.csv")
    meta = read_world_bank_csv(RAW / "Metadata_Country_API_SP.DYN.LE00.IN_DS2_en_csv_v2_260452.csv")

    print("Rows (countries and aggregates):", len(data))
    aggregates = set(m["Country Code"] for m in meta if not m["Region"].strip())
    real_countries = set(m["Country Code"] for m in meta if m["Region"].strip())
    print("Aggregates (World, income groups, regions):", len(aggregates))
    print("Real countries:", len(real_countries))
    print("Regions:", dict(Counter(m["Region"] for m in meta if m["Region"].strip())))
    print("Income groups:", dict(Counter(m["IncomeGroup"] for m in meta if m["Region"].strip())))

    year_cols = [k for k in data[0].keys() if k and k.isdigit()]
    print("Year columns:", year_cols[0], "to", year_cols[-1])

    total_cells = 0
    empty_cells = 0
    for row in data:
        if row["Country Code"] in real_countries:
            for y in year_cols:
                total_cells += 1
                if not row[y].strip():
                    empty_cells += 1
    print("Country-year cells:", total_cells, "| empty:", empty_cells)
    return real_countries


def main():
    who_pa = analyze_who("who_NCD_PAA.json")
    who_ob = analyze_who("who_obesity_crude.json")
    wb = analyze_world_bank()

    print("=" * 60)
    print("COUNTRY CODE COMPARISON")
    print("In WHO physical activity but not in World Bank:", sorted(who_pa - wb))
    print("In WHO obesity but not in World Bank:", sorted(who_ob - wb))
    print("In World Bank but not in WHO obesity:", sorted(wb - who_ob))
    print("Countries present in all three sources:", len(who_pa & who_ob & wb))


main()