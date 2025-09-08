<p align="center">
  <img src="file:///C:/Users/drrahman/Downloads/hospital.svg" alt="Healthcare Icon" width="150"/>
</p>

# New York State Inpatient and Emergency Department Trends (2022)

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
**Note:** If clicking a link results in an error, please right-click/drag it to a new tab.

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
  Birth-related discharges (normal newborns and neonatal intensive care), Vaginal Delivery, and Severe Infections such as Septicemia are the top drivers of inpatient stays.  
- **How long do patients stay?**  
  Average hospital stay ranges from **~3 days for mild cases** to **over 14 days for the most severe cases**.  
- **What drives high hospital costs?**  
  Rare, highly specialized procedures such as **heart/lung transplants, ECMO (artificial heart-lung support), and neonatal intensive care** drive **multi-million dollar average charges per admission**.  
- **Who pays for care?**  
  Medicaid and Medicare are the top payers, but over **50% of cases are reported with “unknown/unreported” payer information**, limiting transparency in financial data.  

### 🚑 Emergency Department
- **How many visits occur statewide?**  
  New York reported **30.6M ED visits** in 2022.  
- **Which hospitals see the highest volumes?**  
  Large urban hospitals like **NY–Presbyterian, Lincoln Medical, and Elmhurst Hospital** lead in ED volume.  
- **What percentage of ED visits result in admission?**  
  Roughly **17% of ED encounters required inpatient admission**, showing the critical role EDs play in hospital utilization.  
- **Are seasonal trends available?**  
  Quarterly data was **not provided** in the summary dataset — only annual totals are available.  

### 🏥 CMS Linkages
- **How do hospital ownership types compare in costs?**  
  **Local government hospitals** have the highest average charges (~$39K), while **for-profit (proprietary) hospitals** average closer to ~$12K per admission.  
- **How do hospital types compare in admissions?**  
  **Acute Care Hospitals** dominate with **1.12M+ admissions**, while **Psychiatric** and **Critical Access hospitals** serve smaller but important patient groups.  

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
