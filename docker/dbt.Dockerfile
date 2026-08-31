# Lightweight image for ad-hoc dbt CLI use:
#   docker compose run --rm dbt run
#   docker compose run --rm dbt test
# Airflow runs dbt too, but from its own image (docker/airflow.Dockerfile) —
# this one is for you, at the terminal, without spinning up Airflow.
FROM python:3.11-slim

RUN pip install --no-cache-dir dbt-snowflake~=1.8.0

WORKDIR /usr/app/dbt
ENTRYPOINT ["dbt"]
CMD ["--help"]
