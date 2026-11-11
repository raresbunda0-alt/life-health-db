\# Source analysis notes



Download date: 11.11.2026



\## Sources

1\. WHO Global Health Observatory: Physical activity, insufficient, among adults aged 18+ years (age-standardized estimate) (%)

&#x20;  - Code: NCD\_PAA

&#x20;  - URL: https://ghoapi.azureedge.net/api/NCD\_PAA

&#x20;  - File: data/raw/who\_NCD\_PAA.json (JSON, 25 MB)

2\. WHO Global Health Observatory: Obesity among adults, BMI >= 30, prevalence (crude estimate) (%)

&#x20;  - Code: NCD\_BMI\_30C

&#x20;  - URL: https://ghoapi.azureedge.net/api/NCD\_BMI\_30C

&#x20;  - File: data/raw/who\_obesity\_crude.json (JSON, 17 MB)

3\. World Bank: Life expectancy at birth, total (years)

&#x20;  - Code: SP.DYN.LE00.IN

&#x20;  - URL: https://data.worldbank.org/indicator/SP.DYN.LE00.IN

&#x20;  - Files: data/raw/API\_SP.DYN.LE00.IN\_DS2\_en\_csv\_v2\_260452.csv, Metadata\_Country\_...csv, Metadata\_Indicator\_...csv



License: World Bank data is CC BY 4.0. WHO GHO data: CC BY-NC-SA 3.0 IGO (non-commercial use, attribution required) and copied here.



\## Size and structure

| | WHO physical activity | WHO obesity (crude) | World Bank life expectancy |

|---|---|---|---|

| Rows | 41,262 | 28,350 | 266 (one per country) |

| Years | 2000-2022 | 1980-2024 | 1960-2025 (as columns) |

| Countries | 196 | 199 | 217 (plus 48 aggregates) |

| Sex | male, female, both | male, female, both | total only |

| Age groups | 4 (18+, 60-69, 70-79, 80+) | only 18+ | not applicable |

| Missing values | 0 | 0 | 251 empty cells (about 1.75%) |

| Duplicates | 0 | 0 | not applicable |



\## Problems found in the source data

1\. WHO files contain non-country rows (regions, World Bank income groups, global): 759 in physical activity, 1,485 in obesity.

2\. Physical activity has 4 age groups. Only 18+ is kept.

3\. WHO files have only ISO3 codes, no country names. Names come from the World Bank metadata.

4\. The World Bank file has years as columns (wide format), so it must be converted to one row per country and year.

5\. The World Bank file contains 48 aggregates (World, regions, income groups). They are removed using the Region column of the metadata file.

6\. Country mismatches: WHO has COK, NIU, TKL, which the World Bank does not have. The World Bank has 21 territories that WHO obesity does not have (for example ABW, HKG, MAC, XKX).

7\. Physical activity is age-standardized and obesity is crude, so the two are not directly comparable.

8\. The World Bank CSV has 4 non-data lines before the header and an extra comma at the end of each line.



\## Chosen subset

\- Countries: the 192 present in all three sources

\- Years: 2000-2022 (overlap of all three sources)

\- Age group: 18+ only

\- Sex: both sexes, male, female for WHO data; life expectancy has total only

