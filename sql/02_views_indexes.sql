-- 02_views_indexes.sql : a "wide" view and indexes

-- One row per country and year, with all three indicators side by side
CREATE OR REPLACE VIEW v_country_year AS
SELECT c.country_id, c.iso3, c.name AS country,
       wr.name AS who_region, wb.name AS wb_region, ig.name AS income_group,
       o.year,
       MAX(CASE WHEN i.code = 'SP.DYN.LE00.IN' THEN o.value END) AS life_expectancy,
       MAX(CASE WHEN i.code = 'NCD_BMI_30C' AND s.code = 'SEX_BTSX' THEN o.value END) AS obesity,
       MAX(CASE WHEN i.code = 'NCD_BMI_30C' AND s.code = 'SEX_MLE'  THEN o.value END) AS obesity_male,
       MAX(CASE WHEN i.code = 'NCD_BMI_30C' AND s.code = 'SEX_FMLE' THEN o.value END) AS obesity_female,
       MAX(CASE WHEN i.code = 'NCD_PAA' AND s.code = 'SEX_BTSX' THEN o.value END) AS inactivity,
       MAX(CASE WHEN i.code = 'NCD_PAA' AND s.code = 'SEX_MLE'  THEN o.value END) AS inactivity_male,
       MAX(CASE WHEN i.code = 'NCD_PAA' AND s.code = 'SEX_FMLE' THEN o.value END) AS inactivity_female
FROM observation o
JOIN country   c ON c.country_id   = o.country_id
JOIN indicator i ON i.indicator_id = o.indicator_id
JOIN sex       s ON s.sex_id       = o.sex_id
LEFT JOIN who_region    wr ON wr.who_region_id    = c.who_region_id
LEFT JOIN wb_region     wb ON wb.wb_region_id     = c.wb_region_id
LEFT JOIN income_group  ig ON ig.income_group_id  = c.income_group_id
GROUP BY c.country_id, c.iso3, c.name, wr.name, wb.name, ig.name, o.year;

-- Indexes for common filters and joins
CREATE INDEX IF NOT EXISTS idx_obs_indicator_year ON observation (indicator_id, year);
CREATE INDEX IF NOT EXISTS idx_country_who_region ON country (who_region_id);
CREATE INDEX IF NOT EXISTS idx_country_wb_region  ON country (wb_region_id);
CREATE INDEX IF NOT EXISTS idx_country_income     ON country (income_group_id);