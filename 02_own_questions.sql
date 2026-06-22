-- =====================================================================
-- 02_own_questions.sql
-- Global AI Adoption — Self-Defined Questions (with interpretation)
-- Dialect: GoogleSQL (BigQuery)
-- Replace `ai_adoption` with your own project.dataset before running.
-- At least two queries use analytical (window) functions.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. Which countries spend the most on AI relative to GDP?
--     Total spend (public + private) as a % of GDP shows who actually
--     prioritizes AI, not just who has the most money.
--     Insight: Israel (3.50%) and Singapore (3.03%) lead; USA only 8th
--     (1.68%) despite the largest absolute spend (~$385.5B).
-- ---------------------------------------------------------------------
SELECT
  country_name,
  ROUND((ai_spend_total / country_gdp) * 100, 2) AS ai_spend_to_gdp
FROM (
  SELECT
    reg.country_name,
    SUM(i.public_ai_spend_usd + i.private_ai_investment_usd) AS ai_spend_total,
    MAX(reg.gdp_usd) AS country_gdp
  FROM `ai_adoption.investment` i
  LEFT JOIN `ai_adoption.regions` reg
    ON reg.country_code = i.country_code
  GROUP BY reg.country_name
)
ORDER BY ai_spend_total / country_gdp DESC;


-- ---------------------------------------------------------------------
-- Q2. [WINDOW FUNCTION] Top countries by average annual growth in the
--     share of AI users.
--     Insight: USA leads (+7.57 pp/yr, 62.5% -> 85.2%), then Israel
--     (+6.80) and Denmark (+6.73); Finland closes the top 10 (+5.80).
-- ---------------------------------------------------------------------
WITH prev_year AS (
  SELECT
    reg.country_name,
    a.year,
    a.ai_users_share,
    LAG(a.ai_users_share) OVER (
      PARTITION BY a.country_code ORDER BY a.year
    ) AS prev_year_share,
    a.ai_users_share - LAG(a.ai_users_share) OVER (
      PARTITION BY a.country_code ORDER BY a.year
    ) AS growth_from_prev_year
  FROM `ai_adoption.adoption` a
  LEFT JOIN `ai_adoption.regions` reg
    ON reg.country_code = a.country_code
)
SELECT
  country_name,
  ROUND(AVG(growth_from_prev_year), 2) AS growth_average
FROM prev_year
GROUP BY country_name
ORDER BY growth_average DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- Q3. [WINDOW FUNCTION] Each country's deepfake-risk rank within its
--     continent, and how the rank moved from 2022 to 2025.
--     Insight: most continents' rankings are stable (China & USA stay on
--     top regionally); Europe shifts most — Germany +2 (5th->3rd),
--     Finland +1 (10th->9th), while several others drop one place.
-- ---------------------------------------------------------------------
WITH ranked AS (
  SELECT
    reg.country_name,
    reg.continent,
    r.year,
    r.deepfake_incidents,
    DENSE_RANK() OVER (
      PARTITION BY reg.continent, r.year ORDER BY r.deepfake_incidents DESC
    ) AS rank_in_continent
  FROM `ai_adoption.risks` r
  LEFT JOIN `ai_adoption.regions` reg
    ON reg.country_code = r.country_code
)
SELECT
  continent,
  country_name,
  MAX(CASE WHEN year = 2022 THEN deepfake_incidents END) AS incidents_2022,
  MAX(CASE WHEN year = 2022 THEN rank_in_continent  END) AS rank_2022,
  MAX(CASE WHEN year = 2025 THEN deepfake_incidents END) AS incidents_2025,
  MAX(CASE WHEN year = 2025 THEN rank_in_continent  END) AS rank_2025,
  MAX(CASE WHEN year = 2022 THEN rank_in_continent END)
    - MAX(CASE WHEN year = 2025 THEN rank_in_continent END) AS rank_change
FROM ranked
GROUP BY continent, country_name
ORDER BY continent, rank_2025;


-- ---------------------------------------------------------------------
-- Q4. Is there a link between reskilling programs and the AI wage premium?
--     wage_per_reskilling = avg wage premium / avg reskilling reach.
--     Insight: India (1.75) and Kazakhstan (1.72) show the highest
--     return — high premium with modest reskilling reach — while
--     Germany (1.05), UK (1.09) and Finland (1.10) have wide reskilling
--     coverage but a proportionally smaller premium (closer to market
--     saturation).
-- ---------------------------------------------------------------------
SELECT
  reg.country_name,
  ROUND(AVG(w.reskilling_program_reach), 2) AS avg_reskilling,
  ROUND(AVG(w.ai_wage_premium), 2)          AS avg_wage,
  ROUND(AVG(w.ai_wage_premium) / AVG(w.reskilling_program_reach), 3) AS wage_per_reskilling
FROM `ai_adoption.workforce` w
LEFT JOIN `ai_adoption.regions` reg
  ON w.country_code = reg.country_code
GROUP BY reg.country_name
ORDER BY wage_per_reskilling DESC;
