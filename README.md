# Aether Trade — End-to-End Trading Data Platform

Reference project: **web trading app → OLTP order-management system → Snowflake ELT → dbt-transformed data mart → Airflow-orchestrated reporting**, all runnable locally via Docker.

## Important architecture rule

Snowflake is **not** the real-time matching engine.

- **Web app** = order ticket / advisor UI (front office).
- **OLTP OMS** (PostgreSQL-style) = order validation, risk checks, matching, positions, cash (true real-time).
- **Snowflake** = landing, ELT, dimensional warehouse, advisor/risk/compliance reporting (near-real-time + batch).

Latency split:

| Path | Latency target |
|---|---|
| Place order → ACK in UI | 50–200 ms (OLTP only) |
| Fill → position in OMS | sub-second (OLTP) |
| Fill → Snowflake RAW | 1–5 minutes (Snowpipe / CDC micro-batch) |
| Fill → MART fact + dashboard | 5–15 minutes (native Streams+Tasks, or dbt via Airflow — see below) |

## Who owns which layer

This repo intentionally has **two ways to build the MART**, kept side by side:

| Layer | Owner | Why |
|---|---|---|
| RAW → STG | Native Snowflake: Snowpipe + Streams + Tasks (`sql/snowflake/04_pipes_streams_tasks.sql`) | Event-driven CDC micro-batch — not a batch transform problem |
| STG → MART (original) | Hand-rolled `MERGE` in `sql/snowflake/03_mart.sql` / `04_pipes_streams_tasks.sql` | The original design — kept for reference |
| STG → MART (current) | **dbt** (`dbt/aether_trade/`), scheduled by **Airflow** (`airflow/dags/`) | Tested, documented, lineage-tracked, and it's how this layer should actually be built and operated |

dbt's models write to their own schema (`MART_DBT` by default) so they never collide with the tables the raw SQL created. See `dbt/README.md` for the full rationale and layout.

## What is in this repo

| Path | Content |
|---|---|
| `docs/` | High-Level Design and Low-Level Design (Word), data dictionary |
| `sql/oltp/` | OLTP DDL + seed |
| `sql/snowflake/` | RAW / STG / MART DDL, pipes, streams, tasks, MERGE (the original hand-rolled build) |
| `dbt/aether_trade/` | dbt project: staging models, SCD2 snapshots, incremental fact merges, tests |
| `airflow/dags/` | Two DAGs — 15-minute STG→MART build, and a daily EOD position-snapshot batch |
| `data/` | ~25,000 execution rows + related masters (CSV) — also used to seed the local OLTP Postgres |
| `scripts/generate_sample_data.py` | Reproducible data generator |
| `docs/Aether_Trade_Data_Dictionary.xlsx` | Table and column catalog |
| `diagrams/er_oltp.md` and `er_mart.md` | Mermaid ER diagrams |
| `docker-compose.yml`, `docker/` | Full local stack: OLTP Postgres, Airflow, and an ad-hoc dbt runner |
| `.github/workflows/ci.yml` | dbt parse, Docker Compose config check, DAG syntax check |

## Suggested volumes (this sample)

- 120 customers, 25 advisors, 180 accounts
- 80 securities
- ~8,000 orders
- ~25,000 executions / fills
- Daily position snapshots for 10 business days

## Running locally

The OLTP side (Postgres + Airflow's own metadata DB) is fully self-contained
in Docker. The MART side needs a **real Snowflake account** — nothing here
mocks or substitutes one.

### 1. Prerequisites

- Docker + Docker Compose v2
- A Snowflake account with a role that can create databases/schemas/warehouses
  (or ask someone who has one to run `sql/snowflake/01_databases_schemas.sql`,
  `02_raw_stg.sql`, and `03_mart.sql` for you first)

### 2. Configure

```bash
cp .env.example .env                                  # fill in Snowflake + Postgres/Airflow values
cp dbt/aether_trade/profiles.yml.example dbt/aether_trade/profiles.yml
```

Both `.env` and `dbt/aether_trade/profiles.yml` are gitignored — real
credentials never get committed. `profiles.yml` itself has no secrets in it;
every value comes from the env vars in `.env`.

### 3. Bring up the OLTP side + Airflow

```bash
docker compose up -d oltp-postgres
docker compose up -d airflow-webserver airflow-scheduler   # runs airflow-init first automatically
```

- OLTP Postgres is seeded automatically on first start from `sql/oltp/01_oltp_ddl.sql` + `data/*.csv` (see `docker/oltp-init/02_seed.sql`).
- Airflow UI: http://localhost:8080 (credentials from `.env`, default `admin` / whatever you set `AIRFLOW_ADMIN_PASSWORD` to).
- Both DAGs (`aether_trade_stg_to_mart`, `aether_trade_position_snapshot_daily`) show up unpaused-and-ready; unpause them to let the schedule run, or trigger manually.

### 4. Run dbt directly (without Airflow)

```bash
docker compose run --rm dbt deps
docker compose run --rm dbt seed
docker compose run --rm dbt snapshot
docker compose run --rm dbt run
docker compose run --rm dbt test
```

Or without Docker at all, from `dbt/aether_trade/` with `DBT_PROFILES_DIR`
pointed at itself — see `dbt/README.md`.

### 5. Tear down

```bash
docker compose down          # keep volumes (OLTP + Airflow data persist)
docker compose down -v       # also wipe volumes
```

## Why dbt + Airflow here (not just Snowflake Tasks)

The original design (`sql/snowflake/04_pipes_streams_tasks.sql`) does the
whole STG→MART merge as native Snowflake Tasks — that works, and stays in
the repo. The reasons to move that layer to dbt+Airflow instead:

- **Testing**: `dbt test` catches a broken join or a duplicate key before it
  reaches a dashboard; a bare `MERGE` in a Task has no equivalent.
- **Docs & lineage**: `dbt docs generate` produces a browsable DAG of every
  model and its columns — new team members (or an interviewer) can see the
  whole transform layer without reading SQL top to bottom.
- **SCD2 without hand-written effective-dating logic**: dbt snapshots derive
  `effective_from` / `effective_to` / `is_current` automatically; the raw-SQL
  version has to maintain that by hand in every dimension load.
- **Portability**: Snowflake Tasks are Snowflake-only. The same dbt project
  runs on a different warehouse with a different adapter and a changed
  `profiles.yml` — worth knowing even while staying on Snowflake.
- **Orchestration visibility**: Airflow's UI shows retries, run history, and
  task-level failure in one place across DAGs that also do things outside
  Snowflake — a Task's own history view doesn't.

The trade-off, stated plainly: native Streams+Tasks are lower-latency (no
scheduler polling interval) and have zero infra to run yourself. That's why
RAW→STG stays native here — Airflow adds a scheduling layer that CDC
ingestion doesn't need and shouldn't wait on.
