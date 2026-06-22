-- =====================================================================
-- 01_analytical_questions.sql
-- Global AI Adoption — Guided Analytical Questions
-- Dialect: GoogleSQL (BigQuery)
-- Replace `ai_adoption` with your own project.dataset before running.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. Highest enterprise AI adoption relative to digital infrastructure.
--     A high ratio flags countries where adoption outpaces readiness
--     (or where infrastructure is underused). Returns all ties at rank 1.
-- ---------------------------------------------------------------------
SELECT
  country_name,
  year,
  enterprise_ai_adoption,
  digital_infrastructure_idx,
  coefficient
FROM (
  SELECT
    reg.country_name,
    a.year,
    a.enterprise_ai_adoption,
    r.digital_infrastructure_idx,
    a.enterprise_ai_adoption / r.digital_infrastructure_idx AS coefficient,
    DENSE_RANK() OVER (
      ORDER BY a.enterprise_ai_adoption / r.digital_infrastructure_idx DESC
    ) AS rank
  FROM `ai_adoption.adoption` a
  LEFT JOIN `ai_adoption.readiness` r
    ON a.country_code = r.country_code AND r.year = a.year
  LEFT JOIN `ai_adoption.regions` reg
    ON reg.country_code = a.country_code
) t
WHERE t.rank = 1;


-- ---------------------------------------------------------------------
-- Q2. AI users vs. automation-risk per country (latest available year).
-- ---------------------------------------------------------------------
SELECT
  reg.country_name,
  a.ai_users_share,
  w.jobs_automated_share,
  reg.population,
  reg.gdp_usd
FROM `ai_adoption.adoption` a
LEFT JOIN `ai_adoption.regions` reg
  ON reg.country_code = a.country_code
LEFT JOIN `ai_adoption.workforce` w
  ON w.country_code = a.country_code AND w.year = a.year
WHERE a.year = (SELECT MAX(year) FROM `ai_adoption.adoption`)
ORDER BY a.ai_users_share DESC;


-- ---------------------------------------------------------------------
-- Q3. Global snapshot for the latest year:
--     total private investment, avg enterprise adoption,
--     total AI jobs created, avg compute access.
-- ---------------------------------------------------------------------
SELECT
  SUM(i.private_ai_investment_usd) AS sum_private_invest,
  AVG(a.enterprise_ai_adoption)    AS avg_ai_adoption,
  SUM(w.ai_created_jobs)           AS sum_ai_jobs,
  AVG(red.compute_access_score)    AS avg_compute_access
FROM `ai_adoption.adoption` a
LEFT JOIN `ai_adoption.investment` i
  ON a.country_code = i.country_code AND i.year = a.year
LEFT JOIN `ai_adoption.readiness` red
  ON red.country_code = a.country_code AND red.year = a.year
LEFT JOIN `ai_adoption.workforce` w
  ON w.country_code = a.country_code AND w.year = a.year
WHERE a.year = (SELECT MAX(year) FROM `ai_adoption.adoption`);


-- ---------------------------------------------------------------------
-- Q4. Successful AI-transition countries:
--     AI jobs grew from first to last observation AND last-year
--     automation risk is below the dataset average.
-- ---------------------------------------------------------------------
WITH first_year AS (
  SELECT country_code, ai_created_jobs AS jobs_first
  FROM `ai_adoption.workforce`
  WHERE year = (SELECT MIN(year) FROM `ai_adoption.workforce`)
),
last_year AS (
  SELECT country_code, ai_created_jobs AS jobs_last, jobs_automated_share
  FROM `ai_adoption.workforce`
  WHERE year = (SELECT MAX(year) FROM `ai_adoption.workforce`)
),
avg_automation_risk AS (
  SELECT AVG(jobs_automated_share) AS avg_automation
  FROM `ai_adoption.workforce`
  WHERE year = (SELECT MAX(year) FROM `ai_adoption.workforce`)
)
SELECT
  reg.country_name,
  f.jobs_first,
  l.jobs_last,
  l.jobs_automated_share,
  l.jobs_last - f.jobs_first AS difference
FROM first_year f
JOIN `ai_adoption.regions` reg ON reg.country_code = f.country_code
JOIN last_year l              ON l.country_code = reg.country_code
CROSS JOIN avg_automation_risk av
WHERE l.jobs_last > f.jobs_first
  AND l.jobs_automated_share < av.avg_automation
ORDER BY difference DESC;


-- ---------------------------------------------------------------------
-- Q5. Germany year-by-year AI trajectory.
-- ---------------------------------------------------------------------
SELECT
  a.year,
  reg.country_name,
  a.ai_users_share,
  a.enterprise_ai_adoption,
  w.ai_created_jobs,
  w.reskilling_program_reach,
  i.private_ai_investment_usd
FROM `ai_adoption.adoption` a
LEFT JOIN `ai_adoption.workforce` w
  ON a.country_code = w.country_code AND a.year = w.year
LEFT JOIN `ai_adoption.investment` i
  ON i.country_code = a.country_code AND i.year = a.year
LEFT JOIN `ai_adoption.regions` reg
  ON reg.country_code = a.country_code
WHERE reg.country_name = 'Germany'
ORDER BY a.year;


-- ---------------------------------------------------------------------
-- Q6. Year-over-year enterprise-adoption trend with LAG().
--     trend: "Accelerating" (>0), "Slowing" (<0), "No change" (=0).
-- ---------------------------------------------------------------------
WITH changes AS (
  SELECT
    a.country_code,
    a.year,
    a.enterprise_ai_adoption AS current_adoption,
    LAG(a.enterprise_ai_adoption) OVER (
      PARTITION BY a.country_code ORDER BY a.year
    ) AS prev_adoption,
    ROUND(
      (a.enterprise_ai_adoption
        - LAG(a.enterprise_ai_adoption) OVER (PARTITION BY a.country_code ORDER BY a.year))
      / LAG(a.enterprise_ai_adoption) OVER (PARTITION BY a.country_code ORDER BY a.year) * 100, 2
    ) AS related_change_pct
  FROM `ai_adoption.adoption` a
)
SELECT
  reg.country_name,
  c.year,
  c.current_adoption,
  c.prev_adoption,
  c.related_change_pct,
  CASE
    WHEN c.related_change_pct > 0 THEN 'Accelerating'
    WHEN c.related_change_pct < 0 THEN 'Slowing'
    ELSE 'No change'
  END AS trend
FROM changes c
LEFT JOIN `ai_adoption.regions` reg
  ON reg.country_code = c.country_code
ORDER BY reg.country_name, c.year;


-- ---------------------------------------------------------------------
-- Q7. Top private-AI investor per year (rank 1 only) for 2022–2024.
-- ---------------------------------------------------------------------
WITH ranking AS (
  SELECT
    country_code,
    year,
    private_ai_investment_usd,
    DENSE_RANK() OVER (
      PARTITION BY year ORDER BY private_ai_investment_usd DESC
    ) AS rank_country
  FROM `ai_adoption.investment`
)
SELECT
  reg.country_name,
  r.year,
  r.private_ai_investment_usd,
  r.rank_country
FROM `ai_adoption.regions` reg
JOIN ranking r ON reg.country_code = r.country_code
WHERE r.rank_country = 1
ORDER BY r.year;


-- ---------------------------------------------------------------------
-- Q8. Population-weighted misinformation risk (latest year), top 25.
--     weighted_risk = ai_misinformation_idx * (population / 1,000,000)
--     Filtering to MAX(year) keeps one row per country.
-- ---------------------------------------------------------------------
SELECT
  reg.country_name,
  ri.year,
  ri.ai_misinformation_idx,
  reg.population,
  ri.ai_misinformation_idx * (reg.population / 1000000) AS weighted_risk
FROM `ai_adoption.risks` ri
JOIN `ai_adoption.regions` reg
  ON ri.country_code = reg.country_code
WHERE ri.year = (SELECT MAX(year) FROM `ai_adoption.risks`)
ORDER BY weighted_risk DESC
LIMIT 25;


-- ---------------------------------------------------------------------
-- Q9. 3-year adoption forecast for Kazakhstan.
--     growth_factor = current / previous (avg over last 5 years),
--     forecast(+N) = current_adoption * growth_factor ^ N
-- ---------------------------------------------------------------------
WITH gf_table AS (
  SELECT
    reg.country_name,
    a.year,
    a.enterprise_ai_adoption AS current_adoption,
    LAG(a.enterprise_ai_adoption) OVER (
      PARTITION BY a.country_code ORDER BY a.year
    ) AS prev_adoption,
    ROUND(
      a.enterprise_ai_adoption
      / LAG(a.enterprise_ai_adoption) OVER (PARTITION BY a.country_code ORDER BY a.year), 2
    ) AS growth_factor
  FROM `ai_adoption.adoption` a
  LEFT JOIN `ai_adoption.regions` reg
    ON reg.country_code = a.country_code
  WHERE reg.country_name = 'Kazakhstan'
    AND a.year >= (SELECT MAX(year) - 4 FROM `ai_adoption.adoption`)
),
avg_growth AS (
  SELECT AVG(growth_factor) AS avg_growth_factor
  FROM gf_table
)
SELECT
  gf.country_name,
  gf.current_adoption * POWER(ag.avg_growth_factor, 1) AS one_year_pred,
  gf.current_adoption * POWER(ag.avg_growth_factor, 2) AS two_year_pred,
  gf.current_adoption * POWER(ag.avg_growth_factor, 3) AS three_year_pred
FROM gf_table gf
CROSS JOIN avg_growth ag
WHERE gf.year = (SELECT MAX(year) FROM `ai_adoption.adoption`);
