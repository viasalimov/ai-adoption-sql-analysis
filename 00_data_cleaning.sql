-- =====================================================================
-- 00_data_cleaning.sql
-- Global AI Adoption — Data Cleaning
-- Dialect: GoogleSQL (BigQuery)
-- Replace `ai_adoption` with your own project.dataset before running.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Duplicate check — are there repeated rows in `adoption`?
--    (Verification only; does not modify the table.)
-- ---------------------------------------------------------------------
SELECT
  *,
  COUNT(*) AS total_rows
FROM `ai_adoption.adoption`
GROUP BY ALL
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------
-- 2. country_code validation — must be exactly three letters.
--    Scan every table and flag any non-conforming codes.
-- ---------------------------------------------------------------------
SELECT country_code, 'adoption' AS which_table
FROM `ai_adoption.adoption`
WHERE NOT REGEXP_CONTAINS(country_code, r'^[A-Za-z]{3}$')

UNION ALL
SELECT country_code, 'investment' AS which_table
FROM `ai_adoption.investment`
WHERE NOT REGEXP_CONTAINS(country_code, r'^[A-Za-z]{3}$')

UNION ALL
SELECT country_code, 'workforce' AS which_table
FROM `ai_adoption.workforce`
WHERE NOT REGEXP_CONTAINS(country_code, r'^[A-Za-z]{3}$')

UNION ALL
SELECT country_code, 'readiness' AS which_table
FROM `ai_adoption.readiness`
WHERE NOT REGEXP_CONTAINS(country_code, r'^[A-Za-z]{3}$')

UNION ALL
SELECT country_code, 'risks' AS which_table
FROM `ai_adoption.risks`
WHERE NOT REGEXP_CONTAINS(country_code, r'^[A-Za-z]{3}$')

UNION ALL
SELECT country_code, 'regions' AS which_table
FROM `ai_adoption.regions`
WHERE NOT REGEXP_CONTAINS(country_code, r'^[A-Za-z]{3}$');


-- ---------------------------------------------------------------------
-- 3. Clean country names — strip parenthetical qualifiers
--    e.g. "Korea (Republic of)" -> "Korea"
-- ---------------------------------------------------------------------
SELECT
  TRIM(REGEXP_REPLACE(country_name, r'\(.*?\)', '')) AS country_name
FROM `ai_adoption.regions`;


-- ---------------------------------------------------------------------
-- 4. Data types — review `workforce` and cast to the correct numeric type.
--    `ai_created_jobs` represents thousands of jobs and may carry decimals,
--    so FLOAT64 is more appropriate. The remaining columns are FLOAT64 by
--    meaning but can be misread as INT64 on CSV import when all values are
--    whole numbers, so we cast defensively before any calculation.
-- ---------------------------------------------------------------------
SELECT
  CAST(jobs_automated_share     AS FLOAT64) AS jobs_automated_share,
  CAST(ai_created_jobs          AS FLOAT64) AS ai_created_jobs,
  CAST(reskilling_program_reach AS FLOAT64) AS reskilling_program_reach,
  CAST(ai_wage_premium          AS FLOAT64) AS ai_wage_premium
FROM `ai_adoption.workforce`;


-- ---------------------------------------------------------------------
-- 5. NULL handling — generative_ai_share has NULLs (all in 2022).
--    Whether to replace with 0 depends on what NULL means:
--      * If NULL = "AI not used", COALESCE to 0 is needed, otherwise SUM /
--        share calculations understate the market.
--      * If NULL = "not collected / missing", keep it NULL: AVG ignores
--        NULL and averages only real observations, whereas forcing 0 would
--        bias the mean downward.
--    Query below shows the COALESCE form for the first interpretation.
-- ---------------------------------------------------------------------
SELECT
  country_code,
  year,
  COALESCE(generative_ai_share, 0) AS generative_ai_share
FROM `ai_adoption.adoption`;
