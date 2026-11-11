-- 03_queries.sql : 17 questions about life expectancy, obesity and inactivity
-- All queries use the view v_country_year (one row per country and year).

-- Q1. Which 10 countries had the highest life expectancy in 2022?
SELECT country, who_region, life_expectancy
FROM v_country_year
WHERE year = 2022
ORDER BY life_expectancy DESC
LIMIT 10;

-- Q2. Which countries in 2022 had obesity of at least 25% AND physical inactivity of at least 35%?
SELECT country, who_region, obesity, inactivity
FROM v_country_year
WHERE year = 2022 AND obesity >= 25 AND inactivity >= 35
ORDER BY obesity DESC;

-- Q3. What was the average life expectancy in 2022 per WHO region and income group?
SELECT who_region, income_group, COUNT(*) AS countries,
       ROUND(AVG(life_expectancy), 1) AS avg_life_expectancy
FROM v_country_year
WHERE year = 2022
GROUP BY who_region, income_group
ORDER BY who_region, avg_life_expectancy DESC;

-- Q4. Which WHO regions had an average physical inactivity above 30% in 2022?
SELECT who_region, COUNT(*) AS countries, ROUND(AVG(inactivity), 1) AS avg_inactivity
FROM v_country_year
WHERE year = 2022
GROUP BY who_region
HAVING AVG(inactivity) > 30
ORDER BY avg_inactivity DESC;

-- Q5. Which 10 countries gained the most years of life expectancy between 2000 and 2022?
SELECT b.country, b.who_region,
       a.life_expectancy AS le_2000, b.life_expectancy AS le_2022,
       ROUND(b.life_expectancy - a.life_expectancy, 1) AS gain_years
FROM v_country_year a
JOIN v_country_year b ON b.country_id = a.country_id
WHERE a.year = 2000 AND b.year = 2022
ORDER BY gain_years DESC
LIMIT 10;

-- Q6. In which 10 countries did adult obesity increase the most between 2000 and 2022?
SELECT b.country, b.who_region,
       a.obesity AS obesity_2000, b.obesity AS obesity_2022,
       ROUND(b.obesity - a.obesity, 1) AS increase_points
FROM v_country_year a
JOIN v_country_year b ON b.country_id = a.country_id
WHERE a.year = 2000 AND b.year = 2022
ORDER BY increase_points DESC
LIMIT 10;

-- Q7. How strongly are obesity and life expectancy correlated in each WHO region (2022)?
SELECT who_region, COUNT(*) AS countries,
       ROUND(CORR(obesity, life_expectancy)::numeric, 2) AS correlation
FROM v_country_year
WHERE year = 2022
GROUP BY who_region
ORDER BY correlation;

-- Q8. In which 10 countries are women much more inactive than men (2022)?
SELECT country, who_region, inactivity_male, inactivity_female,
       ROUND(inactivity_female - inactivity_male, 1) AS gap_points
FROM v_country_year
WHERE year = 2022
ORDER BY gap_points DESC
LIMIT 10;

-- Q9. Which countries have obesity above the average of their own WHO region (2022)?
SELECT v.country, v.who_region, v.obesity,
       (SELECT ROUND(AVG(x.obesity), 1) FROM v_country_year x
        WHERE x.who_region = v.who_region AND x.year = 2022) AS region_avg
FROM v_country_year v
WHERE v.year = 2022
  AND v.obesity > (SELECT AVG(x.obesity) FROM v_country_year x
                   WHERE x.who_region = v.who_region AND x.year = 2022)
ORDER BY v.obesity DESC
LIMIT 15;

-- Q10. Per income group: in how many countries did obesity and life expectancy rise from 2000 to 2022?
WITH a AS (SELECT * FROM v_country_year WHERE year = 2000),
     b AS (SELECT * FROM v_country_year WHERE year = 2022)
SELECT b.income_group, COUNT(*) AS countries,
       SUM(CASE WHEN b.obesity > a.obesity THEN 1 ELSE 0 END) AS obesity_rose,
       SUM(CASE WHEN b.life_expectancy > a.life_expectancy THEN 1 ELSE 0 END) AS life_exp_rose,
       SUM(CASE WHEN b.obesity > a.obesity AND b.life_expectancy > a.life_expectancy
                THEN 1 ELSE 0 END) AS both_rose
FROM a JOIN b ON b.country_id = a.country_id
GROUP BY b.income_group
ORDER BY b.income_group;

-- Q11. Which are the 3 most physically inactive countries in each income group (2022)?
WITH ranked AS (
    SELECT income_group, country, inactivity,
           RANK() OVER (PARTITION BY income_group ORDER BY inactivity DESC) AS rnk
    FROM v_country_year
    WHERE year = 2022
)
SELECT * FROM ranked WHERE rnk <= 3 ORDER BY income_group, rnk;

-- Q12. How many countries per WHO region have complete data for all 3 indicators in all 23 years?
SELECT who_region, COUNT(*) AS complete_countries
FROM (
    SELECT country_id, who_region
    FROM v_country_year
    WHERE life_expectancy IS NOT NULL AND obesity IS NOT NULL AND inactivity IS NOT NULL
    GROUP BY country_id, who_region
    HAVING COUNT(*) = 23
) t
GROUP BY who_region
ORDER BY who_region;

-- Q13. Is life expectancy different in countries with low, medium and high inactivity (2022)?
WITH y AS (
    SELECT life_expectancy,
           CASE WHEN inactivity < 20 THEN '1 low (under 20%)'
                WHEN inactivity < 35 THEN '2 medium (20-35%)'
                ELSE '3 high (35% or more)' END AS inactivity_level
    FROM v_country_year
    WHERE year = 2022
)
SELECT inactivity_level, COUNT(*) AS countries,
       ROUND(AVG(life_expectancy), 1) AS avg_life_expectancy,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY life_expectancy))::numeric, 1) AS median_life_expectancy
FROM y
GROUP BY inactivity_level
ORDER BY inactivity_level;

-- Q14. In which 5 years did the average obesity of all countries rise the most compared with the previous year?
WITH yearly AS (
    SELECT year, AVG(obesity) AS avg_obesity
    FROM v_country_year
    GROUP BY year
), changes AS (
    SELECT year, avg_obesity,
           avg_obesity - LAG(avg_obesity) OVER (ORDER BY year) AS change
    FROM yearly
)
SELECT year, ROUND(avg_obesity, 2) AS avg_obesity, ROUND(change, 2) AS change_points
FROM changes
WHERE change IS NOT NULL
ORDER BY change DESC
LIMIT 5;

-- Q15. How many rows were read, loaded and rejected for each source, and how old is the download?
SELECT ds.name AS source, b.started_at::date AS import_date,
       b.rows_read, b.rows_loaded, b.rows_rejected,
       ROUND(100.0 * b.rows_loaded / b.rows_read, 1) AS percent_loaded,
       CURRENT_DATE - ds.retrieved_on AS days_since_download
FROM import_batch b
JOIN data_source ds ON ds.source_id = b.source_id
ORDER BY b.batch_id;

-- Q16. (Complex) In 2022, which are the 3 countries with the highest life expectancy in each WHO region,
--      and are their obesity and inactivity above or below their region's average?
WITH y AS (
    SELECT * FROM v_country_year WHERE year = 2022
), r AS (
    SELECT who_region, AVG(obesity) AS avg_obesity, AVG(inactivity) AS avg_inactivity
    FROM y GROUP BY who_region
), ranked AS (
    SELECT y.who_region, y.country, y.income_group, y.life_expectancy, y.obesity, y.inactivity,
           RANK() OVER (PARTITION BY y.who_region ORDER BY y.life_expectancy DESC) AS rank_in_region,
           CASE WHEN y.obesity > r.avg_obesity AND y.inactivity > r.avg_inactivity THEN 'both above region average'
                WHEN y.obesity > r.avg_obesity THEN 'obesity above region average'
                WHEN y.inactivity > r.avg_inactivity THEN 'inactivity above region average'
                ELSE 'both at or below region average' END AS risk_profile
    FROM y JOIN r ON r.who_region = y.who_region
)
SELECT * FROM ranked WHERE rank_in_region <= 3 ORDER BY who_region, rank_in_region;

-- Q17. How did Romania change from 2000 to 2022 in life expectancy, obesity and inactivity?
SELECT year, life_expectancy, obesity, inactivity
FROM v_country_year
WHERE iso3 = 'ROU'
ORDER BY year;