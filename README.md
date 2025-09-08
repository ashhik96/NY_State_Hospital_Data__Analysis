# Healthcare Data Analysis with SQL (SPARCS + CMS)

## 📌 Project Overview
This project analyzes **New York State healthcare data** using **MySQL**.  
The focus is on:
- **Inpatient hospital discharges (SPARCS 2022)**  
- **Emergency Department (ED) encounters (SPARCS 2022 summary data)**  
- **Hospital General Information (CMS)**  

The project demonstrates SQL skills in:
- Data cleaning and schema design  
- Large-scale data loading (2M+ rows inpatient)  
- Analytical queries to uncover healthcare insights  
- Linking multiple datasets (SPARCS + CMS)  

---

## 📂 Dataset Sources
- [SPARCS Inpatient Discharges (De-Identified, 2022)](https://health.data.ny.gov/Health/Hospital-Inpatient-Discharges-SPARCS-De-Identified/5dtw-tffi)
- [SPARCS Emergency Department Encounters (De-Identified, Summary, 2022)](https://health.data.ny.gov/Health/Hospital-Emergency-Department-Discharges-SPARCS-De/5gzv-zv2z)
- [CMS Hospital General Information](https://data.cms.gov/provider-data/dataset/xubh-q36u)  

---

## ⚙️ Project Pipeline
1. **Schema Creation** → `Schema.sql`  
   - Defines tables for Inpatient, ED, and CMS datasets.  
2. **Data Cleaning & Indexing** → `Cleaning.sql`  
   - Cleans charges/costs, replaces invalid values, and adds indexes.  
3. **Analysis Queries** → `Analysis.sql`  
   - SQL queries to extract insights from inpatient, ED, and CMS data.  

---

## 🔍 Key Insights

### 🏥 Inpatient (SPARCS 2022)
- **Top DRGs by Admissions**: Neonates, Vaginal Delivery, Septicemia dominate admissions.  
- **Average LOS**: Ranges from **2.9 days (Minor)** to **14.2 days (Extreme)**.  
- **Charges vs Costs**: Specialized cases like transplants/ECMO drive multi-million average charges.  
- **Payer Mix**: Medicaid + Medicare represent the largest share; 50%+ are “Unknown/Unreported”.  

### 🚑 Emergency Department
- **Total Statewide ED Encounters (2022)**: **30.6M**  
- **Top Facilities**: NY–Presbyterian, Lincoln Medical, Elmhurst Hospital.  
- **Admission Rate**: ~**16.8%** of ED visits result in inpatient admission.  
- **Seasonality**: *Quarterly breakdown unavailable in summary dataset — only annual totals provided.*  

### 🏥 CMS Linkages
- **Avg Charges by Ownership**: Local government hospitals highest ($39K avg), proprietary lowest ($12K avg).  
- **Admissions by Hospital Type**: Acute Care Hospitals dominate (1.12M+), followed by Psychiatric and Critical Access Hospitals.  

---

## 📜 Example Queries
```sql
-- Top 10 Conditions Driving Admissions
SELECT apr_drg_description, COUNT(*) AS admission_count
FROM sparcs_inpatient_2022
GROUP BY apr_drg_description
ORDER BY admission_count DESC
LIMIT 10;

-- Admissions by Hospital Type
SELECT c.hospital_type, COUNT(*) AS admission_count
FROM sparcs_inpatient_2022 i
JOIN cms_hospitals c
  ON UPPER(TRIM(i.facility_name)) = UPPER(TRIM(c.hospital_name))
GROUP BY c.hospital_type
ORDER BY admission_count DESC;

