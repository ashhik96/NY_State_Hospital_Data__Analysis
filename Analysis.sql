USE hospital_sql_analysis;

SET SQL_MODE = 'STRICT_ALL_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

/* ---------------------------------------------------------------------
   1) Admissions, Avg Charges, Avg LOS by Diagnosis
   - Provides ranking for top drivers
--------------------------------------------------------------------- */
WITH dx AS (
  SELECT
      primary_diagnosis,
      COUNT(*)                        AS total_admissions,
      ROUND(AVG(total_charges),2)     AS avg_charges,
      ROUND(AVG(length_of_stay),1)    AS avg_los
  FROM discharges
  GROUP BY primary_diagnosis
)
SELECT
    primary_diagnosis,
    total_admissions,
    avg_charges,
    avg_los,
    RANK() OVER (ORDER BY total_admissions DESC) AS diagnosis_rank
FROM dx
ORDER BY diagnosis_rank
LIMIT 50;


/* ---------------------------------------------------------------------
   2) Admissions per Hospital by County (Burden)
   - Shows total admissions, hospital count, and burden ratio
--------------------------------------------------------------------- */
WITH burden AS (
  SELECT
      c.county_name,
      COUNT(*)                              AS total_admissions,
      COUNT(DISTINCT f.facility_id)         AS hospital_count,
      ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT f.facility_id),0), 2) AS admissions_per_hospital
  FROM discharges d
  JOIN facilities f ON d.facility_id = f.facility_id
  JOIN counties   c ON f.county_code = c.county_code
  GROUP BY c.county_name
)
SELECT
    county_name,
    total_admissions,
    hospital_count,
    admissions_per_hospital,
    PERCENT_RANK() OVER (ORDER BY admissions_per_hospital) AS burden_percentile
FROM burden
ORDER BY admissions_per_hospital DESC;


/* ---------------------------------------------------------------------
   3) Demographic Breakdown (Gender × Race/Ethnicity)
   - Used for Tableau filters and disparity analysis
--------------------------------------------------------------------- */
WITH base AS (
  SELECT
      gender,
      race_ethnicity,
      COUNT(*) AS admissions
  FROM discharges
  GROUP BY gender, race_ethnicity
),
tot AS (
  SELECT SUM(admissions) AS N_total FROM base
)
SELECT
    b.gender,
    b.race_ethnicity,
    b.admissions,
    ROUND(100.0 * b.admissions / t.N_total, 2) AS pct_of_total
FROM base b CROSS JOIN tot t
ORDER BY b.race_ethnicity, b.gender;


/* ---------------------------------------------------------------------
   4) Payer Mix (Share of Admissions by Payer Category)
--------------------------------------------------------------------- */
WITH payer_counts AS (
  SELECT payer, COUNT(*) AS admissions
  FROM discharges
  GROUP BY payer
),
tot AS (
  SELECT SUM(admissions) AS N_total FROM payer_counts
)
SELECT
    p.payer,
    p.admissions,
    ROUND(100.0 * p.admissions / t.N_total, 2) AS pct_of_total
FROM payer_counts p CROSS JOIN tot t
ORDER BY pct_of_total DESC;


/* ---------------------------------------------------------------------
   5) Top 5 Diagnoses per County
   - Partitioned ranking, local “Top-N” insight
--------------------------------------------------------------------- */
WITH county_dx AS (
  SELECT
      c.county_name,
      d.primary_diagnosis,
      COUNT(*) AS admissions
  FROM discharges d
  JOIN facilities f ON d.facility_id = f.facility_id
  JOIN counties   c ON f.county_code = c.county_code
  GROUP BY c.county_name, d.primary_diagnosis
),
ranked AS (
  SELECT
      county_name,
      primary_diagnosis,
      admissions,
      ROW_NUMBER() OVER (PARTITION BY county_name ORDER BY admissions DESC) AS rn
  FROM county_dx
)
SELECT county_name, primary_diagnosis, admissions
FROM ranked
WHERE rn <= 5
ORDER BY county_name, admissions DESC;
