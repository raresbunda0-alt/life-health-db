-- 05_integrity_tests.sql : statements that must FAIL, proving the constraints work.
-- Run each test separately (select it, press F5). Expected result is written above it.
-- Tests T10 and T11 undo themselves, so your data stays safe.

-- T1. UNIQUE: the same country, indicator, sex and year cannot exist twice.
-- Expected: duplicate key value violates unique constraint
INSERT INTO observation (country_id, indicator_id, sex_id, year, value)
SELECT country_id, indicator_id, sex_id, year, value FROM observation LIMIT 1;

-- T2. CHECK: a value cannot be negative.
-- Expected: violates check constraint
INSERT INTO observation (country_id, indicator_id, sex_id, year, value)
VALUES ((SELECT country_id FROM country WHERE iso3 = 'ROU'),
        (SELECT indicator_id FROM indicator WHERE code = 'NCD_PAA'),
        (SELECT sex_id FROM sex WHERE code = 'SEX_BTSX'), 1999, -5);

-- T3. NOT NULL: the year is mandatory.
-- Expected: null value in column "year" violates not-null constraint
INSERT INTO observation (country_id, indicator_id, sex_id, year, value)
VALUES ((SELECT country_id FROM country WHERE iso3 = 'ROU'),
        (SELECT indicator_id FROM indicator WHERE code = 'NCD_PAA'),
        (SELECT sex_id FROM sex WHERE code = 'SEX_BTSX'), NULL, 25);

-- T4. FOREIGN KEY: the country must exist.
-- Expected: violates foreign key constraint
INSERT INTO observation (country_id, indicator_id, sex_id, year, value)
VALUES (999999,
        (SELECT indicator_id FROM indicator WHERE code = 'NCD_PAA'),
        (SELECT sex_id FROM sex WHERE code = 'SEX_BTSX'), 1999, 25);

-- T5. CHECK: the lower confidence bound cannot be above the upper one.
-- Expected: violates check constraint
INSERT INTO observation (country_id, indicator_id, sex_id, year, value, ci_low, ci_high)
VALUES ((SELECT country_id FROM country WHERE iso3 = 'ROU'),
        (SELECT indicator_id FROM indicator WHERE code = 'NCD_PAA'),
        (SELECT sex_id FROM sex WHERE code = 'SEX_BTSX'), 1999, 25, 30, 20);

-- T6. CHECK: the country code must be 3 capital letters.
-- Expected: violates check constraint
INSERT INTO country (iso3, name) VALUES ('ro1', 'Test country');

-- T7. ON DELETE RESTRICT: an indicator that has data cannot be deleted.
-- Expected: violates foreign key constraint
DELETE FROM indicator WHERE code = 'NCD_PAA';

-- T8. TRIGGER: a percentage cannot be above 100.
-- Expected: Percentage indicator NCD_PAA cannot exceed 100 (got 150)
INSERT INTO observation (country_id, indicator_id, sex_id, year, value)
VALUES ((SELECT country_id FROM country WHERE iso3 = 'ROU'),
        (SELECT indicator_id FROM indicator WHERE code = 'NCD_PAA'),
        (SELECT sex_id FROM sex WHERE code = 'SEX_BTSX'), 1999, 150);

-- T9. TRIGGER: life expectancy exists for both sexes only.
-- Expected: Life expectancy is stored for both sexes only (got SEX_MLE)
INSERT INTO observation (country_id, indicator_id, sex_id, year, value)
VALUES ((SELECT country_id FROM country WHERE iso3 = 'ROU'),
        (SELECT indicator_id FROM indicator WHERE code = 'SP.DYN.LE00.IN'),
        (SELECT sex_id FROM sex WHERE code = 'SEX_MLE'), 1999, 70);

-- T10. ON DELETE CASCADE + audit trigger: deleting a country deletes its observations.
-- This block deletes Romania, reports the numbers, then rolls back on purpose.
-- Expected: an error that says "DEMO ONLY (rolled back)" and shows the counts.
DO $$
DECLARE before_cnt INT; after_cnt INT; audit_cnt INT;
BEGIN
    SELECT COUNT(*) INTO before_cnt FROM observation;
    DELETE FROM country WHERE iso3 = 'ROU';
    SELECT COUNT(*) INTO after_cnt FROM observation;
    SELECT COUNT(*) INTO audit_cnt FROM audit_log WHERE operation = 'DELETE';
    RAISE EXCEPTION 'DEMO ONLY (rolled back). Observations before: %, after: %, audit rows: %',
        before_cnt, after_cnt, audit_cnt;
END $$;

-- T11. AUDIT trigger on UPDATE: changing a value is logged. Rolled back on purpose.
-- Expected: an error that says "DEMO ONLY (rolled back)" with 1 audit row.
DO $$
DECLARE audit_cnt INT; v_old NUMERIC; v_new NUMERIC;
BEGIN
    UPDATE observation SET value = value + 1
    WHERE observation_id = (SELECT MIN(observation_id) FROM observation);
    SELECT COUNT(*), MAX(old_value), MAX(new_value)
      INTO audit_cnt, v_old, v_new FROM audit_log WHERE operation = 'UPDATE';
    RAISE EXCEPTION 'DEMO ONLY (rolled back). Audit rows: %, old value: %, new value: %',
        audit_cnt, v_old, v_new;
END $$;