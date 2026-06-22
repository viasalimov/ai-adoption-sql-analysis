# Global AI Adoption — SQL Analysis (BigQuery / GoogleSQL)

A SQL analytics project exploring the global spread of Artificial Intelligence across **30 countries (2022–2025)**, covering business & population adoption, investment, the labor market, technological readiness, and AI-related risks.

Data is based on figures modeled after **Stanford HAI AI Index, OECD AI Policy Observatory, World Bank Digital Development, and IMF AI Monitor** reports.

The analysis is written in **GoogleSQL (BigQuery)** and demonstrates data cleaning, multi-table joins, subqueries, CTEs, and analytical **window functions** (`LAG`, `DENSE_RANK`, `PARTITION BY`), plus growth forecasting with `POWER()`.

---

## Dataset

Six tables, all linked by `country_code` + `year`:

| Table | Description | Key columns |
|---|---|---|
| `regions` | Country reference data | `country_name`, `continent`, `income_group`, `population`, `gdp_usd` |
| `adoption` | AI adoption by business & population | `ai_users_share`, `enterprise_ai_adoption`, `generative_ai_share`, `ai_skill_penetration` |
| `investment` | AI investment & R&D | `private_ai_investment_usd`, `public_ai_spend_usd`, `ai_startups_count`, `ai_patents_filed`, `ai_research_papers` |
| `workforce` | Labor-market impact | `jobs_automated_share`, `ai_created_jobs`, `reskilling_program_reach`, `ai_wage_premium` |
| `readiness` | Technological readiness | `digital_infrastructure_idx`, `data_regulation_score`, `ai_ethics_framework`, `compute_access_score`, `electricity_reliability` |
| `risks` | AI-related risks | `deepfake_incidents`, `ai_bias_cases`, `data_breach_via_ai`, `ai_misinformation_idx` |

Raw CSVs are in [`/data`](./data). Scope: 30 countries × 4 years (2022–2025).

> **Note on table references:** the SQL files use fully-qualified names in the form
> `` `ai_adoption.<table>` ``. Replace `ai_adoption` with your own BigQuery dataset
> (e.g. `` `your-project.your_dataset.adoption` ``) before running.

---

## Repository structure

```
ai-adoption-sql-analysis/
├── data/                        # 6 source CSVs
├── sql/
│   ├── 00_data_cleaning.sql     # duplicate checks, regex validation, type casts, NULL handling
│   ├── 01_analytical_questions.sql   # 9 guided business questions
│   └── 02_own_questions.sql     # 4 self-defined questions + window functions
└── results/
    └── key_findings.md          # summary of insights
```

---

## What's inside

### `00_data_cleaning.sql`
- Duplicate-row detection with `GROUP BY ALL ... HAVING COUNT(*) > 1`
- `country_code` format validation across all 6 tables via `REGEXP_CONTAINS(... r'^[A-Za-z]{3}$')` + `UNION ALL`
- Cleaning parenthetical text from country names with `REGEXP_REPLACE`
- Data-type review and `CAST` to `FLOAT64`
- Reasoned `COALESCE` handling of `NULL` in `generative_ai_share`

### `01_analytical_questions.sql`
Nine business questions, including:
- AI adoption vs. digital-infrastructure ratio, ranked with `DENSE_RANK()`
- Latest-year AI usage vs. automation risk per country
- Global roll-up (total investment, avg adoption, jobs created, compute access)
- Successful AI-transition countries (CTE-based first-vs-last-year comparison + below-average automation risk)
- Year-over-year adoption trend with `LAG()` and a `CASE` trend label
- Top investor per year with `DENSE_RANK() OVER (PARTITION BY year ...)`
- Population-weighted misinformation risk
- 1/2/3-year adoption forecast for Kazakhstan using an average growth factor and `POWER()`

### `02_own_questions.sql`
Four self-defined questions with interpretation:
1. **AI spend as % of GDP** — who *prioritizes* AI vs. who just has more money (Israel 3.50%, Singapore 3.03% lead; USA only 8th despite largest absolute spend).
2. **Fastest-growing AI user base** — avg YoY growth via `LAG()` (USA +7.57 pp/yr).
3. **Deepfake risk rank within continent, 2022 vs 2025** — `DENSE_RANK()` partitioned by continent + pivot with `CASE`.
4. **Reskilling vs. AI wage premium** — where investing in people pays off (India 1.75, Kazakhstan 1.72 highest return).

See [`results/key_findings.md`](./results/key_findings.md) for the full write-up.

---

## Tech & techniques

`GoogleSQL` · `BigQuery` · Window functions (`LAG`, `DENSE_RANK`, `PARTITION BY`) · CTEs · subqueries · multi-table `JOIN` · `REGEXP_CONTAINS` / `REGEXP_REPLACE` · `COALESCE` · `CAST` · `POWER` · conditional aggregation (`CASE` pivots)

Visualizations were produced in Google Sheets / Looker Studio.
