-- Safety & defaults
SET SQL_MODE = 'STRICT_ALL_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- (Optional) Create & use a dedicated database
CREATE DATABASE IF NOT EXISTS hospital_sql_analysis
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE hospital_sql_analysis;

-- Drop in dependency order (fact first, then dims)
DROP TABLE IF EXISTS discharges;
DROP TABLE IF EXISTS facilities;
DROP TABLE IF EXISTS counties;
DROP TABLE IF EXISTS payers;

-- ---------------------------
-- Dimension: counties
-- ---------------------------
CREATE TABLE counties (
  county_code   VARCHAR(10)  NOT NULL,
  county_name   VARCHAR(100) NOT NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (county_code),
  UNIQUE KEY uq_counties_name (county_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------
-- Dimension: facilities
-- ---------------------------
CREATE TABLE facilities (
  facility_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  facility_code   VARCHAR(32) NULL,            -- keep if the source has an external code
  facility_name   VARCHAR(255) NOT NULL,
  county_code     VARCHAR(10)  NOT NULL,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (facility_id),
  UNIQUE KEY uq_facilities_name (facility_name),
  KEY ix_facilities_county_code (county_code),
  CONSTRAINT fk_facilities_county
    FOREIGN KEY (county_code) REFERENCES counties(county_code)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------
-- (Optional) Dimension: payers
-- ---------------------------
CREATE TABLE payers (
  payer_code   VARCHAR(40)  NOT NULL,          -- e.g., 'Medicare', 'Medicaid', 'Commercial', 'Other', 'Unknown'
  display_name VARCHAR(80)  NOT NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (payer_code),
  UNIQUE KEY uq_payers_name (display_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------
-- Fact: discharges
-- ---------------------------
CREATE TABLE discharges (
  discharge_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- Foreign keys
  facility_id        INT UNSIGNED    NOT NULL,
  -- Dates & stay
  admission_date     DATE            NULL,
  discharge_date     DATE            NULL,
  length_of_stay     SMALLINT UNSIGNED NULL,
  -- Patient & clinical
  age                TINYINT UNSIGNED NULL,     -- 0–120 typical
  gender             VARCHAR(10)     NULL,      -- 'Male','Female','Other','Unknown' (kept flexible)
  race_ethnicity     VARCHAR(50)     NULL,      -- normalized buckets + 'Unknown'
  primary_diagnosis  VARCHAR(255)    NULL,      -- description field used in dashboard
  -- Financial
  payer              VARCHAR(40)     NULL,      -- raw payer label (keep even if mapped to payers.payer_code)
  total_charges      DECIMAL(12,2)   NULL,      -- full-stay charges
  -- Source & audit
  source_row_id      VARCHAR(64)     NULL,      -- optional: original file row/key
  created_at         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP       NULL ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (discharge_id),

  -- Foreign keys
  CONSTRAINT fk_discharges_facility
    FOREIGN KEY (facility_id) REFERENCES facilities(facility_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT

  -- Note: If you map payer -> payers.payer_code during cleaning, you can also enforce:
  -- ,CONSTRAINT fk_discharges_payer FOREIGN KEY (payer) REFERENCES payers(payer_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------
-- Constraints / sanity checks (MySQL 8.0 enforces CHECK)
-- ---------------------------
ALTER TABLE discharges
  ADD CONSTRAINT chk_age_range
    CHECK (age IS NULL OR (age BETWEEN 0 AND 120)),
  ADD CONSTRAINT chk_los_nonneg
    CHECK (length_of_stay IS NULL OR length_of_stay >= 0),
  ADD CONSTRAINT chk_charges_nonneg
    CHECK (total_charges IS NULL OR total_charges >= 0);

-- ---------------------------
-- High-impact indexes for analysis
-- ---------------------------
-- Fact table indexing to speed up joins, grouping, and filters used by the dashboard
CREATE INDEX ix_discharges_admission_date ON discharges (admission_date);
CREATE INDEX ix_discharges_primary_dx     ON discharges (primary_diagnosis);
CREATE INDEX ix_discharges_facility_id    ON discharges (facility_id);
-- Composite for common slicers (Gender, Race/Ethnicity)
CREATE INDEX ix_discharges_gender_race    ON discharges (gender, race_ethnicity);
-- Optional for time-bounded extracts (year predicate)
CREATE INDEX ix_discharges_admission_year ON discharges ((YEAR(admission_date)));

-- Counties quick lookups
CREATE INDEX ix_counties_name ON counties (county_name);

-- ---------------------------
-- Seed payer dimension (optional, edit as needed)
-- ---------------------------
INSERT IGNORE INTO payers (payer_code, display_name) VALUES
  ('Medicare','Medicare'),
  ('Medicaid','Medicaid'),
  ('Commercial','Commercial'),
  ('Other','Other'),
  ('Unknown','Unknown');
