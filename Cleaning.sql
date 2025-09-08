USE sparcs_ny;

---------------------------------------------------------
-- Inpatient Cleaning
---------------------------------------------------------

-- Disable safe updates for cleaning
SET SQL_SAFE_UPDATES = 0;

-- Replace 0 LOS with NULL
UPDATE sparcs_inpatient_2022
SET length_of_stay = NULL
WHERE length_of_stay = 0;

-- Clean charges/costs: remove commas
UPDATE sparcs_inpatient_2022
SET total_charges = REPLACE(total_charges, ',', ''),
    total_costs   = REPLACE(total_costs, ',', '');

-- Convert blanks to NULL
UPDATE sparcs_inpatient_2022
SET total_charges = NULLIF(total_charges, ''),
    total_costs   = NULLIF(total_costs, '');

-- Convert charges/costs to DECIMAL
ALTER TABLE sparcs_inpatient_2022
  MODIFY total_charges DECIMAL(12,2),
  MODIFY total_costs DECIMAL(12,2);

---------------------------------------------------------
-- ED Summary Cleaning
---------------------------------------------------------

-- Sanity check for invalid values
UPDATE sparcs_ed_2022
SET total_ed_encounters = NULL
WHERE total_ed_encounters < 0;

---------------------------------------------------------
-- CMS Hospitals Cleaning
---------------------------------------------------------

-- Trim whitespace
UPDATE cms_hospitals
SET hospital_name = TRIM(hospital_name),
    city = TRIM(city),
    state = TRIM(state);

---------------------------------------------------------
-- Indexes for Faster Queries
---------------------------------------------------------

-- Inpatient
CREATE INDEX idx_ip_facility ON sparcs_inpatient_2022 (facility_id);
CREATE INDEX idx_ip_drg ON sparcs_inpatient_2022 (apr_drg_code);
CREATE INDEX idx_ip_year ON sparcs_inpatient_2022 (discharge_year);

-- ED
CREATE INDEX idx_ed_facility ON sparcs_ed_2022 (facility_id);
CREATE INDEX idx_ed_year ON sparcs_ed_2022 (year);

-- CMS
CREATE INDEX idx_cms_name ON cms_hospitals (hospital_name);
CREATE INDEX idx_cms_ccn ON cms_hospitals (ccn);
