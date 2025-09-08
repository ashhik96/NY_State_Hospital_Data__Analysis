CREATE DATABASE IF NOT EXISTS sparcs_ny;
USE sparcs_ny;

---------------------------------------------------------
-- Inpatient Discharges 2022
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS sparcs_inpatient_2022 (
  facility_id VARCHAR(20),
  facility_name VARCHAR(255),
  hospital_county VARCHAR(100),
  health_service_area VARCHAR(100),
  age_group VARCHAR(20),
  gender VARCHAR(20),
  race VARCHAR(50),
  ethnicity VARCHAR(50),
  type_of_admission VARCHAR(50),
  patient_disposition VARCHAR(100),
  discharge_year YEAR,
  apr_drg_code VARCHAR(10),
  apr_drg_description VARCHAR(255),
  apr_mdc_code VARCHAR(10),
  apr_mdc_description VARCHAR(255),
  apr_severity_of_illness VARCHAR(100),
  apr_risk_of_mortality VARCHAR(100),
  length_of_stay INT,
  total_charges VARCHAR(50),   -- cleaned later
  total_costs VARCHAR(50),     -- cleaned later
  payment_typology_1 VARCHAR(100),
  payment_typology_2 VARCHAR(100),
  payment_typology_3 VARCHAR(100)
);

---------------------------------------------------------
-- Emergency Department Summary Encounters 2022
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS sparcs_ed_2022 (
  year YEAR,
  quarter TINYINT,
  facility_id VARCHAR(20),
  facility_name VARCHAR(255),
  facility_type_description VARCHAR(100),
  facility_county_fips VARCHAR(10),
  facility_county VARCHAR(100),
  facility_region VARCHAR(100),
  operating_certificate_number VARCHAR(50),
  operator_name VARCHAR(255),
  total_ed_encounters INT,
  treat_and_release_ed_encounters INT,
  ed_encounters_ambulatory_surgery INT,
  ed_encounters_admitted_inpatient INT
);

---------------------------------------------------------
-- CMS Hospital General Information
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms_hospitals (
  ccn VARCHAR(20),
  hospital_name VARCHAR(255),
  address VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(20),
  zip_code VARCHAR(20),
  phone VARCHAR(50),
  hospital_type VARCHAR(100),
  ownership VARCHAR(100),
  emergency_services VARCHAR(10),
  overall_rating VARCHAR(10)
);
