-- 04_functions_triggers.sql : functions, a procedure, triggers and an audit table
-- Run after 01_schema.sql, the import, and 02_views_indexes.sql.

-- ---------- Functions ----------

-- Time series of one country (uses the view from file 02)
CREATE OR REPLACE FUNCTION get_country_trend(p_iso3 CHAR(3))
RETURNS TABLE (year SMALLINT, life_expectancy NUMERIC, obesity NUMERIC, inactivity NUMERIC)
LANGUAGE sql STABLE AS $$
    SELECT v.year::smallint, v.life_expectancy::numeric, v.obesity::numeric, v.inactivity::numeric
    FROM v_country_year v
    WHERE v.iso3 = p_iso3
    ORDER BY v.year;
$$;

-- Percentage change between two values
CREATE OR REPLACE FUNCTION pct_change(old_val NUMERIC, new_val NUMERIC)
RETURNS NUMERIC
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN old_val IS NULL OR old_val = 0 OR new_val IS NULL THEN NULL
                ELSE ROUND(100.0 * (new_val - old_val) / old_val, 1) END;
$$;

-- ---------- Procedure ----------

-- Recalculates the loaded/rejected counts of every import batch from the real data
CREATE OR REPLACE PROCEDURE refresh_batch_stats()
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE import_batch b
    SET rows_loaded   = (SELECT COUNT(*) FROM observation o WHERE o.batch_id = b.batch_id),
        rows_rejected = GREATEST(b.rows_read - (SELECT COUNT(*) FROM observation o
                                                 WHERE o.batch_id = b.batch_id), 0);
END;
$$;

-- ---------- Trigger 1: business rules that a simple CHECK cannot express ----------

CREATE OR REPLACE FUNCTION trg_check_observation_range()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_unit VARCHAR(20);
    v_code VARCHAR(50);
    v_sex  VARCHAR(20);
BEGIN
    SELECT unit, code INTO v_unit, v_code FROM indicator WHERE indicator_id = NEW.indicator_id;
    SELECT code INTO v_sex FROM sex WHERE sex_id = NEW.sex_id;

    IF v_unit = '%' AND NEW.value > 100 THEN
        RAISE EXCEPTION 'Percentage indicator % cannot exceed 100 (got %)', v_code, NEW.value
            USING ERRCODE = 'check_violation';
    END IF;

    IF v_unit = 'years' AND NEW.value > 120 THEN
        RAISE EXCEPTION 'Life expectancy cannot exceed 120 years (got %)', NEW.value
            USING ERRCODE = 'check_violation';
    END IF;

    IF v_code = 'SP.DYN.LE00.IN' AND v_sex <> 'SEX_BTSX' THEN
        RAISE EXCEPTION 'Life expectancy is stored for both sexes only (got %)', v_sex
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_observation_range ON observation;
CREATE TRIGGER trg_observation_range
    BEFORE INSERT OR UPDATE ON observation
    FOR EACH ROW EXECUTE FUNCTION trg_check_observation_range();

-- ---------- Trigger 2: audit log of changed and deleted values ----------

CREATE TABLE IF NOT EXISTS audit_log (
    audit_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name  VARCHAR(50) NOT NULL,
    operation   VARCHAR(10) NOT NULL CHECK (operation IN ('UPDATE', 'DELETE')),
    record_id   BIGINT      NOT NULL,
    old_value   NUMERIC(8,3),
    new_value   NUMERIC(8,3),
    changed_at  TIMESTAMP   NOT NULL DEFAULT now(),
    changed_by  TEXT        NOT NULL DEFAULT current_user
);

CREATE OR REPLACE FUNCTION trg_audit_observation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.value IS DISTINCT FROM OLD.value THEN
            INSERT INTO audit_log (table_name, operation, record_id, old_value, new_value)
            VALUES ('observation', 'UPDATE', OLD.observation_id, OLD.value, NEW.value);
        END IF;
        RETURN NEW;
    ELSE
        INSERT INTO audit_log (table_name, operation, record_id, old_value, new_value)
        VALUES ('observation', 'DELETE', OLD.observation_id, OLD.value, NULL);
        RETURN OLD;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_observation_audit ON observation;
CREATE TRIGGER trg_observation_audit
    AFTER UPDATE OR DELETE ON observation
    FOR EACH ROW EXECUTE FUNCTION trg_audit_observation();