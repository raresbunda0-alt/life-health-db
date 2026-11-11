-- 01_schema.sql : creates the life/health database structure
-- Safe to run again: it deletes the old tables first.

DROP TABLE IF EXISTS observation CASCADE;
DROP TABLE IF EXISTS country CASCADE;
DROP TABLE IF EXISTS indicator CASCADE;
DROP TABLE IF EXISTS import_batch CASCADE;
DROP TABLE IF EXISTS data_source CASCADE;
DROP TABLE IF EXISTS sex CASCADE;
DROP TABLE IF EXISTS income_group CASCADE;
DROP TABLE IF EXISTS wb_region CASCADE;
DROP TABLE IF EXISTS who_region CASCADE;

-- 1. Where the data comes from
CREATE TABLE data_source (
    source_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(200) NOT NULL UNIQUE,
    organization  VARCHAR(200) NOT NULL,
    url           TEXT         NOT NULL,
    license       VARCHAR(300),
    retrieved_on  DATE         NOT NULL
);

-- 2. One row per import run
CREATE TABLE import_batch (
    batch_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_id      INT NOT NULL REFERENCES data_source (source_id) ON DELETE RESTRICT,
    started_at     TIMESTAMP NOT NULL DEFAULT now(),
    rows_read      INT CHECK (rows_read >= 0),
    rows_loaded    INT CHECK (rows_loaded >= 0),
    rows_rejected  INT CHECK (rows_rejected >= 0)
);

-- 3. WHO regions
CREATE TABLE who_region (
    who_region_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code           VARCHAR(10)  NOT NULL UNIQUE,
    name           VARCHAR(100) NOT NULL
);

-- 4. World Bank regions
CREATE TABLE wb_region (
    wb_region_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(100) NOT NULL UNIQUE
);

-- 5. World Bank income groups
CREATE TABLE income_group (
    income_group_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name             VARCHAR(100) NOT NULL UNIQUE
);

-- 6. Countries (region and income group are optional)
CREATE TABLE country (
    country_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    iso3             CHAR(3)      NOT NULL UNIQUE CHECK (iso3 ~ '^[A-Z]{3}$'),
    name             VARCHAR(150) NOT NULL,
    who_region_id    INT REFERENCES who_region (who_region_id)       ON DELETE SET NULL,
    wb_region_id     INT REFERENCES wb_region (wb_region_id)         ON DELETE SET NULL,
    income_group_id  INT REFERENCES income_group (income_group_id)   ON DELETE SET NULL
);

-- 7. Sex categories (same codes as in the WHO files)
CREATE TABLE sex (
    sex_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE,
    label   VARCHAR(30) NOT NULL
);

-- 8. The 3 indicators
CREATE TABLE indicator (
    indicator_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code          VARCHAR(50)  NOT NULL UNIQUE,
    name          VARCHAR(300) NOT NULL,
    unit          VARCHAR(20)  NOT NULL,
    source_id     INT NOT NULL REFERENCES data_source (source_id) ON DELETE RESTRICT
);

-- 9. The measured values
CREATE TABLE observation (
    observation_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_id      INT NOT NULL REFERENCES country (country_id)       ON DELETE CASCADE,
    indicator_id    INT NOT NULL REFERENCES indicator (indicator_id)   ON DELETE RESTRICT,
    sex_id          INT NOT NULL REFERENCES sex (sex_id)               ON DELETE RESTRICT,
    year            SMALLINT NOT NULL CHECK (year BETWEEN 1960 AND 2100),
    value           NUMERIC(8,3) NOT NULL CHECK (value >= 0),
    ci_low          NUMERIC(8,3) CHECK (ci_low >= 0),
    ci_high         NUMERIC(8,3) CHECK (ci_high >= 0),
    batch_id        INT REFERENCES import_batch (batch_id) ON DELETE SET NULL,
    UNIQUE (country_id, indicator_id, sex_id, year),
    CHECK (ci_low IS NULL OR ci_high IS NULL OR ci_low <= ci_high)
);

-- Fixed values that we define ourselves
INSERT INTO sex (code, label) VALUES
    ('SEX_BTSX', 'Both sexes'),
    ('SEX_MLE',  'Male'),
    ('SEX_FMLE', 'Female');