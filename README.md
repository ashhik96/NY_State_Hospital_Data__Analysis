# New York State Healthcare Data Analysis: Inpatient and Emergency Department Trends (2022)

## 📌 Project Overview
This project analyzes **New York State healthcare data** using **MySQL**, focusing on:
- **Inpatient hospital discharges (SPARCS 2022)** → What are the most common reasons for admission? How long do patients stay?
- **Emergency Department (ED) encounters (SPARCS 2022 summary data)** → How many visits occur statewide? Which hospitals see the highest volumes? What percentage of ED visits result in admission?
- **Hospital General Information (CMS = Centers for Medicare & Medicaid Services)** → How do hospital types (Acute Care, Psychiatric, Children’s) and ownership (Government, Non-Profit, Proprietary) relate to costs and admissions?

The project demonstrates SQL techniques such as:
- Cleaning and preparing **2M+ inpatient records** for analysis
- Summarizing admissions, payer mix, and costs with `GROUP BY` and aggregations
- Using `JOIN`s to link SPARCS admissions with CMS hospital characteristics
- Extracting insights into patient outcomes, hospital utilization, and cost drivers

---

## 📂 Dataset Sources
- [SPARCS Inpatient Discharges (De-Identified, 2022)](https://health.data.ny.gov/Health/Hospital-Inpatient-Discharges-SPARCS-De-Identified/5dtw-tffi)
- [SPARCS Emergency Department Encounters (De-Identified, Summary, 2022)](https://health.data.ny.gov/d/5gzv-zv2z)
- [CMS Hospital General Information](https://data.cms.gov/provider-data/dataset/xubh-q36u)

---

## ⚙️ Project Pipeline
1. **Schema Creation** → `Schema.sql`
   - Defines tables for Inpatient, ED, and CMS datasets.
   - Ensures correct column types for millions of rows.
   - Provides structure for relational joins later in analysis.

2. **Data Cleaning & Indexing** → `Cleaning.sql`
   - Cleans charges/costs (removes commas, converts to decimals).
   - Replaces invalid values (e.g., LOS = 0 set to NULL).
   - Adds indexes to improve query performance on large tables.
   - Demonstrates SQL cleaning skills with `TRIM`, `UPPER`, and type conversion (`VARCHAR` → `DECIMAL`).

3. **Analysis Queries** → `Analysis.sql`
   - SQL queries to extract insights from inpatient, ED, and CMS data.
   - Uses `GROUP BY`, `COUNT`, `AVG`, `SUM`, and `ROUND` for KPIs.
   - Incorporates `JOIN`s to link inpatient data with CMS attributes.
   - Highlights advanced query building with string cleaning + joins (`UPPER(TRIM(...))`).

---

## 🔍 Key Insights

### 🏥 Inpatient (SPARCS 2022)
- **What are the most common reasons for admission?**
  Neonates, Vaginal Delivery, and Septicemia account for the largest share of inpatient stays.
- **How long do patients stay?**
  Average length of stay ranges from **2.9 days (Minor severity)** to **14.2 days (Extreme severity)**.
- **What drives high hospital costs?**
  Specialized procedures such as transplants, ECMO, and neonatal intensive care drive **multi-million dollar average charges**.
- **Who pays for care?**
  Medicaid and Medicare are the top payers, though **50%+ of cases report unknown/unreported payer information**.

### 🚑 Emergency Department
- **How many visits occur statewide?**
  New York reported **30.6M ED encounters** in 2022.
- **Which hospitals see the highest volumes?**
  NY–Presbyterian, Lincoln Medical, and Elmhurst Hospital lead in ED volume.
- **What percentage of ED visits result in admission?**
  Roughly **16.8%** of ED encounters required inpatient admission.
- **Are seasonal trends available?**
  Quarterly data was not provided in the summary dataset — only annual totals are available.

### 🏥 CMS Linkages
- **How do hospital ownership types compare in costs?**
  Local government hospitals have the highest average charges (~$39K), while proprietary hospitals average around ~$12K.
- **How do hospital types compare in admissions?**
  Acute Care Hospitals dominate with **1.12M+ admissions**, followed by Psychiatric and Critical Access hospitals.

---

## 📌 Limitations
- ED dataset is summary-level only (no patient demographics).
- CMS linkage via facility_name not perfect (naming differences across datasets).
- Large number of unknown/unreported payers in SPARCS data.

---

## 👤 Author
**Ashik Rahman**
- [LinkedIn](https://www.linkedin.com/in/ashik-rahman-998364379)
- [GitHub](https://github.com/ashhik96)

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
