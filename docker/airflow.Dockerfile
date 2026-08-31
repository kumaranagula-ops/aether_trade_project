# Extends the official Airflow image with dbt-snowflake so BashOperator can
# call `dbt` directly — no separate dbt container in the execution path.
FROM apache/airflow:2.9.3-python3.11

COPY airflow/requirements.txt /requirements.txt
RUN pip install --no-cache-dir --constraint \
    "https://raw.githubusercontent.com/apache/airflow/constraints-2.9.3/constraints-3.11.txt" \
    -r /requirements.txt
