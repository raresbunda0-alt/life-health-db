# \# Life Expectancy, Obesity and Physical Inactivity: Relational Database

# 

# Course project (Erasmus+, Databases). A PostgreSQL database that combines three open indicators

# for 192 countries, 2000-2022:

# 

# | Indicator | Source |

# |---|---|

# | Life expectancy at birth, total (years) | World Bank, SP.DYN.LE00.IN |

# | Obesity among adults, BMI >= 30, crude estimate (%) | WHO Global Health Observatory, NCD\_BMI\_30C |

# | Insufficient physical activity, adults 18+, age-standardized (%) | WHO Global Health Observatory, NCD\_PAA |

# 

# \## Data sources (all downloaded on 11.11.2026)

# \- WHO GHO API: https://ghoapi.azureedge.net/api/NCD\_PAA and https://ghoapi.azureedge.net/api/NCD\_BMI\_30C (JSON). License: CC BY-NC-SA 3.0 IGO.

# \- World Bank: https://data.worldbank.org/indicator/SP.DYN.LE00.IN (CSV). License: CC BY 4.0.

# \- The original files are in `data/raw/`.

# 

# \## Requirements

# \- PostgreSQL 18 (older versions probably work)

# \- Python 3.11 or newer

# 

# \## How to create and fill the database

# 1\. Install the Python library: `python -m pip install -r src/requirements.txt`

# 2\. Create an empty database named `life\_health\_db` (in pgAdmin: right-click Databases, Create, Database).

# 3\. Run the SQL files in this order (in pgAdmin Query Tool, or with `psql -U postgres -d life\_health\_db -f sql/FILE.sql`):

# &#x20;  1. `sql/01\_schema.sql` creates the tables

# &#x20;  2. `python src/import\_data.py` loads the data (asks for the postgres password)

# &#x20;  3. `sql/02\_views\_indexes.sql` creates the view and indexes

# &#x20;  4. `sql/04\_functions\_triggers.sql` creates the functions, procedure, triggers and audit table

# 4\. Optional: `sql/03\_queries.sql` (17 analysis queries) and `sql/05\_integrity\_tests.sql`

# &#x20;  (statements that fail on purpose). Run them one statement at a time.

# 

# Warning: `01\_schema.sql` deletes and recreates the tables. If you run it again, also run steps 2-4 again.

# 

# \## Expected result

# `observation` has 30,912 rows, `country` has 192 rows.

# 

# \## Folder structure

# \- `data/raw/` original source files

# \- `sql/` SQL scripts

# \- `src/` Python scripts: `analyze\_sources.py` (source analysis), `import\_data.py` (import)

# \- `docs/` ER diagram, logical model, source notes

# \- `report/` project report (PDF)

# 

# \## Data subset

# 192 countries present in all three sources, years 2000-2022, adults 18+. WHO regions, income-group

# rows and other age groups are excluded. See `docs/source\_notes.md` for the reasoning.

