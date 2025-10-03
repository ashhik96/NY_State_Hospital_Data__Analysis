USE hospital_sql_analysis;

SET SQL_MODE = 'STRICT_ALL_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

/* ---------------------------------------------------------------------
   1) Canonical “Unknown” bootstrap rows (safe to re-run)
--------------------------------------------------------------------- */
INSERT IGNORE INTO counties (county_code, county_name) VALUES ('UNK','Unknown');
INSERT IGNORE INTO facilities (facility_id, facility_code, facility_name, county_code)
VALUES (NULL, 'UNK', 'Unknown Facility', 'UNK');

/* ---------------------------------------------------------------------
   2) Normalize COUNTY dimension from staging
      - Prefer code when provided; otherwise derive a code from the name.
--------------------------------------------------------------------- */
-- Helper: derive a simple code from county name (first 6 uppercase chars)
-- (MySQL lacks computed columns for this ad-hoc step; we do it inline.)

-- Upsert distinct counties by NAME first
INSERT INTO counties (county_code, county_name)
SELECT
  -- choose best available code: trimmed raw code else derived
  COALESCE(NULLIF(TRIM(county_code_raw), ''),
           LEFT(UPPER(REPLACE(TRIM(county_name_raw), ' ', '')), 6),
           'UNK')                         AS county_code,
  COALESCE(NULLIF(TRIM(county_name_raw), ''), 'Unknown') AS county_name
FROM (
  SELECT DISTINCT county_code_raw, county_name_raw
  FROM stg_discharges
) s
ON DUPLICATE KEY UPDATE
  county_name = VALUES(county_name);

-- Add quick lookup index by name (idempotent if run once in Schema.sql)
CREATE INDEX IF NOT EXISTS ix_counties_name ON counties (county_name);

/* ---------------------------------------------------------------------
   3) Normalize FACILITY dimension
      - Map each raw facility to a county_code (by code if present, else name).
--------------------------------------------------------------------- */
-- A: Resolve county_code for each row in staging
DROP TEMPORARY TABLE IF EXISTS tmp_facility_to_county;
CREATE TEMPORARY TABLE tmp_facility_to_county AS
SELECT
  TRIM(facility_name_raw)                                       AS facility_name_clean,
  COALESCE(
    NULLIF(TRIM(county_code_raw), ''),
    (SELECT c.county_code
       FROM counties c
      WHERE c.county_name = COALESCE(NULLIF(TRIM(county_name_raw), ''), 'Unknown')
      LIMIT 1),
    'UNK'
  ) AS county_code_clean
FROM stg_discharges
WHERE NULLIF(TRIM(facility_name_raw), '') IS NOT NULL
GROUP BY TRIM(facility_name_raw),
         COALESCE(NULLIF(TRIM(county_code_raw), ''),
                  (SELECT c.county_code
                     FROM counties c
                    WHERE c.county_name = COALESCE(NULLIF(TRIM(county_name_raw), ''), 'Unknown')
                    LIMIT 1),
                  'UNK');

-- B: Upsert facilities
INSERT INTO facilities (facility_code, facility_name, county_code)
SELECT
  NULL AS facility_code,
  t.facility_name_clean,
  t.county_code_clean
FROM tmp_facility_to_county t
ON DUPLICATE KEY UPDATE
  county_code = VALUES(county_code);

/* ---------------------------------------------------------------------
   4) (Optional) Normalize PAYERS by mapping raw → canonical buckets
--------------------------------------------------------------------- */
-- Seeded in Schema.sql; adjust mappings as needed for your data.
DROP TEMPORARY TABLE IF EXISTS tmp_payer_map;
CREATE TEMPORARY TABLE tmp_payer_map (
  raw_label   VARCHAR(64) PRIMARY KEY,
  payer_code  VARCHAR(40) NOT NULL
) ENGINE=InnoDB;

INSERT INTO tmp_payer_map (raw_label, payer_code) VALUES
  ('MEDICARE',   'Medicare'),
  ('MEDICAID',   'Medicaid'),
  ('COMMERCIAL', 'Commercial'),
  ('PRIVATE',    'Commercial'),
  ('BLUE CROSS', 'Commercial'),
  ('HMO',        'Commercial'),
  ('SELF PAY',   'Other'),
  ('SELF-PAY',   'Other'),
  ('OTHER',      'Other'),
  ('UNKNOWN',    'Unknown');

-- Expand map using observed distinct raw values (best-effort autosnap)
-- (Leaves unmapped values as-is; you can add specific rows above as needed)
INSERT IGNORE INTO tmp_payer_map (raw_label, payer_code)
SELECT DISTINCT UPPER(TRIM(payer_raw)) AS raw_label, 'Other'
FROM stg_discharges
WHERE NULLIF(TRIM(payer_raw), '') IS NOT NULL;

/* ---------------------------------------------------------------------
   5) Add derived columns on FACT (age_group). Idempotent.
--------------------------------------------------------------------- */
ALTER TABLE discharges
  ADD COLUMN IF NOT EXISTS age_group VARCHAR(20) NULL AFTER age;

/* ---------------------------------------------------------------------
   6) Load FACT: DISCHARGES with full cleaning & transformations
      - Date parsing (supports YYYY-MM-DD and MM/DD/YYYY)
      - Charges parsing ($, commas)
      - LOS cleaning (or compute from dates when missing)
      - Age bounds, gender/race normalization
      - Facility join by cleaned name
      - Payer normalization via tmp_payer_map (optional)
--------------------------------------------------------------------- */

-- Helper inline functions for date parsing via COALESCE of patterns
-- MySQL: STR_TO_DATE returns NULL if pattern fails

INSERT INTO discharges (
  facility_id,
  admission_date,
  discharge_date,
  length_of_stay,
  age,
  gender,
  race_ethnicity,
  primary_diagnosis,
  payer,
  total_charges,
  source_row_id,
  age_group
)
SELECT
  /* facility_id: join by cleaned facility name */
  COALESCE(
    (SELECT f.facility_id
       FROM facilities f
      WHERE f.facility_name = TRIM(s.facility_name_raw)
      LIMIT 1),
    (SELECT f2.facility_id FROM facilities f2
      WHERE REPLACE(UPPER(f2.facility_name),' ','') = REPLACE(UPPER(TRIM(s.facility_name_raw)),' ','')
      LIMIT 1),
    (SELECT facility_id FROM facilities WHERE facility_name = 'Unknown Facility' LIMIT 1)
  ) AS facility_id,

  /* admission_date: try ISO then US */
  COALESCE(
    STR_TO_DATE(NULLIF(TRIM(s.admission_date_raw), ''), '%Y-%m-%d'),
    STR_TO_DATE(NULLIF(TRIM(s.admission_date_raw), ''), '%m/%d/%Y')
  ) AS admission_date,

  /* discharge_date: try ISO then US */
  COALESCE(
    STR_TO_DATE(NULLIF(TRIM(s.discharge_date_raw), ''), '%Y-%m-%d'),
    STR_TO_DATE(NULLIF(TRIM(s.discharge_date_raw), ''), '%m/%d/%Y')
  ) AS discharge_date,

  /* length_of_stay: prefer numeric cleaned; else compute from dates */
  CASE
    WHEN CAST(NULLIF(s.length_of_stay_raw,'') AS SIGNED) > 0
      THEN CAST(NULLIF(s.length_of_stay_raw,'') AS SIGNED)
    ELSE
      CASE
        WHEN COALESCE(
               STR_TO_DATE(NULLIF(TRIM(s.discharge_date_raw), ''), '%Y-%m-%d'),
               STR_TO_DATE(NULLIF(TRIM(s.discharge_date_raw), ''), '%m/%d/%Y')
             ) IS NOT NULL
         AND COALESCE(
               STR_TO_DATE(NULLIF(TRIM(s.admission_date_raw), ''), '%Y-%m-%d'),
               STR_TO_DATE(NULLIF(TRIM(s.admission_date_raw), ''), '%m/%d/%Y')
             ) IS NOT NULL
        THEN GREATEST(
               DATEDIFF(
                 COALESCE(
                   STR_TO_DATE(NULLIF(TRIM(s.discharge_date_raw), ''), '%Y-%m-%d'),
                   STR_TO_DATE(NULLIF(TRIM(s.discharge_date_raw), ''), '%m/%d/%Y')
                 ),
                 COALESCE(
                   STR_TO_DATE(NULLIF(TRIM(s.admission_date_raw), ''), '%Y-%m-%d'),
                   STR_TO_DATE(NULLIF(TRIM(s.admission_date_raw), ''), '%m/%d/%Y')
                 )
               ),
               0
             )
        ELSE NULL
      END
  END AS length_of_stay,

  /* age: numeric bound 0..120 */
  CASE
    WHEN CAST(NULLIF(s.age_raw,'') AS SIGNED) BETWEEN 0 AND 120
      THEN CAST(s.age_raw AS UNSIGNED)
    ELSE NULL
  END AS age,

  /* gender normalization */
  CASE
    WHEN UPPER(TRIM(s.gender_raw)) IN ('M','MALE') THEN 'Male'
    WHEN UPPER(TRIM(s.gender_raw)) IN ('F','FEMALE') THEN 'Female'
    WHEN UPPER(TRIM(s.gender_raw)) IN ('OTHER','O','NON-BINARY','NONBINARY') THEN 'Other'
    WHEN NULLIF(TRIM(s.gender_raw),'') IS NULL THEN 'Unknown'
    ELSE 'Unknown'
  END AS gender,

  /* race/ethnicity normalization (expand as needed) */
  CASE
    WHEN UPPER(s.race_ethnicity_raw) LIKE '%BLACK%' THEN 'Black/African American'
    WHEN UPPER(s.race_ethnicity_raw) LIKE '%HISP%'  THEN 'Hispanic/Latino'
    WHEN UPPER(s.race_ethnicity_raw) LIKE '%ASIAN%' THEN 'Asian'
    WHEN UPPER(s.race_ethnicity_raw) LIKE '%WHITE%' THEN 'White'
    WHEN UPPER(s.race_ethnicity_raw) LIKE '%NATIVE%' OR UPPER(s.race_ethnicity_raw) LIKE '%AMERICAN INDIAN%' THEN 'American Indian/Alaska Native'
    WHEN UPPER(s.race_ethnicity_raw) LIKE '%PACIFIC%' OR UPPER(s.race_ethnicity_raw) LIKE '%HAWAII%' THEN 'Native Hawaiian/Other Pacific Islander'
    WHEN NULLIF(TRIM(s.race_ethnicity_raw),'') IS NULL THEN 'Unknown'
    ELSE 'Other'
  END AS race_ethnicity,

  /* primary diagnosis: trimmed text */
  NULLIF(TRIM(s.primary_diagnosis_raw), '') AS primary_diagnosis,

  /* payer: mapped to canonical code where possible */
  COALESCE(
    (SELECT m.payer_code FROM tmp_payer_map m
      WHERE m.raw_label = UPPER(TRIM(s.payer_raw)) LIMIT 1),
    'Other'
  ) AS payer,

  /* total_charges: strip $ and commas and cast */
  CASE
    WHEN NULLIF(TRIM(s.total_charges_raw), '') IS NULL THEN NULL
    ELSE CAST(REPLACE(REPLACE(TRIM(s.total_charges_raw), '$',''), ',', '') AS DECIMAL(12,2))
  END AS total_charges,

  /* source row id for traceability */
  NULLIF(TRIM(s.source_row_id), '') AS source_row_id,

  /* age_group derived */
  CASE
    WHEN CAST(NULLIF(s.age_raw,'') AS SIGNED) < 18 THEN '0–17'
    WHEN CAST(NULLIF(s.age_raw,'') AS SIGNED) BETWEEN 18 AND 29 THEN '18–29'
    WHEN CAST(NULLIF(s.age_raw,'') AS SIGNED) BETWEEN 30 AND 44 THEN '30–44'
    WHEN CAST(NULLIF(s.age_raw,'') AS SIGNED) BETWEEN 45 AND 64 THEN '45–64'
    WHEN CAST(NULLIF(s.age_raw,'') AS SIGNED) >= 65 THEN '65+'
    ELSE NULL
  END AS age_group

FROM stg_discharges s;

-- Enforce sanity constraints post-load (idempotent; CHECK constraints exist in schema)
UPDATE discharges SET length_of_stay = NULL WHERE length_of_stay IS NOT NULL AND length_of_stay < 0;
UPDATE discharges SET total_charges   = NULL WHERE total_charges   IS NOT NULL AND total_charges   < 0;
UPDATE discharges SET age             = NULL WHERE age             IS NOT NULL AND (age < 0 OR age > 120);

/* ---------------------------------------------------------------------
   7) QA / Health checks (quick spot checks)
--------------------------------------------------------------------- */
-- Row counts
SELECT 'staging_rows' AS metric, COUNT(*) AS value FROM stg_discharges
UNION ALL
SELECT 'fact_rows_loaded', COUNT(*) FROM discharges;

-- Null/Unknown rates on key dims
SELECT
  SUM(gender = 'Unknown')            AS unknown_gender,
  SUM(race_ethnicity = 'Unknown')    AS unknown_race_eth,
  SUM(primary_diagnosis IS NULL)     AS null_primary_dx,
  SUM(payer = 'Unknown')             AS unknown_payer
FROM discharges;

-- Facility & county coverage
SELECT
  COUNT(*)                                          AS discharges_rows,
  SUM(facility_id IS NULL)                          AS null_facility_id,
  SUM(facility_id = (SELECT facility_id FROM facilities WHERE facility_name='Unknown Facility' LIMIT 1)) AS unknown_facility_rows
FROM discharges;

-- Basic distribution sanity: admissions per hospital (top 10)
SELECT
  c.county_name,
  COUNT(*) AS total_admissions,
  COUNT(DISTINCT f.facility_id) AS hospital_count,
  ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT f.facility_id),0), 2) AS adm_per_hosp
FROM discharges d
JOIN facilities f ON d.facility_id = f.facility_id
JOIN counties   c ON f.county_code  = c.county_code
GROUP BY c.county_name
ORDER BY adm_per_hosp DESC
LIMIT 10;
