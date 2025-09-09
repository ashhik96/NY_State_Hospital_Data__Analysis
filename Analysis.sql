USE sparcs_ny;

---------------------------------------------------------
-- Inpatient Analytics
---------------------------------------------------------

-- 1. Top 10 Conditions Driving Admissions
SELECT apr_drg_description, COUNT(*) AS admission_count
FROM sparcs_inpatient_2022
GROUP BY apr_drg_description
ORDER BY admission_count DESC
LIMIT 10;

-- >>> Birth-related hospitalizations (normal newborns and neonatal intensive care), Vaginal Delivery, and Severe Infections such as Septicemia are the top drivers of inpatient stays.


-- 2. Average Length of Stay by Severity
SELECT apr_severity_of_illness, AVG(length_of_stay) AS avg_los
FROM sparcs_inpatient_2022
WHERE length_of_stay IS NOT NULL
GROUP BY apr_severity_of_illness
ORDER BY avg_los DESC;


-- 3. Charges vs. Costs by Condition (Top 10 by Avg Charges)
SELECT apr_drg_description,
       ROUND(AVG(total_charges),2) AS avg_charges,
       ROUND(AVG(total_costs),2)   AS avg_costs
FROM sparcs_inpatient_2022
WHERE total_charges IS NOT NULL AND total_costs IS NOT NULL
GROUP BY apr_drg_description
ORDER BY avg_charges DESC
LIMIT 10;


-- 4. Payer Mix Distribution
SELECT payment_typology_1, COUNT(*) AS cases
FROM sparcs_inpatient_2022
GROUP BY payment_typology_1
ORDER BY cases DESC;

---------------------------------------------------------
-- ED Summary Analytics (Annual Totals)
---------------------------------------------------------

-- 5. Top Facilities by ED Encounters
SELECT facility_name, SUM(total_ed_encounters) AS total_encounters
FROM sparcs_ed_2022
WHERE year = 2022
GROUP BY facility_name
ORDER BY total_encounters DESC
LIMIT 10;

-- 6. Statewide ED Admission Rate
SELECT 
  SUM(ed_encounters_admitted_inpatient) / SUM(total_ed_encounters) * 100 AS admit_rate_pct
FROM sparcs_ed_2022
WHERE year = 2022;

-- 7. Statewide Annual ED Encounters
SELECT year, SUM(total_ed_encounters) AS total_ed
FROM sparcs_ed_2022
WHERE year = 2022
GROUP BY year;

---------------------------------------------------------
-- CMS-Linked Insights (Join on Facility Name)
---------------------------------------------------------

-- 8. Average Charges by Ownership Type
SELECT c.ownership, ROUND(AVG(i.total_charges),2) AS avg_charges
FROM sparcs_inpatient_2022 i
JOIN cms_hospitals c
  ON UPPER(TRIM(i.facility_name)) = UPPER(TRIM(c.hospital_name))
WHERE i.total_charges IS NOT NULL
GROUP BY c.ownership
ORDER BY avg_charges DESC;

-- 9. Admissions by Hospital Type
SELECT c.hospital_type, COUNT(*) AS admission_count
FROM sparcs_inpatient_2022 i
JOIN cms_hospitals c
  ON UPPER(TRIM(i.facility_name)) = UPPER(TRIM(c.hospital_name))
GROUP BY c.hospital_type
ORDER BY admission_count DESC;
