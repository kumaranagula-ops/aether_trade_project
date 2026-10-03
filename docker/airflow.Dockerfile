FROM apache/airflow:2.9.3-python3.11

# dbt_utils is installed from git (packages.yml points at github.com, not the
# dbt Hub, since hub.getdbt.com is blocked on a lot of networks) -- so `dbt
# deps` needs a real git binary, which this base image doesn't ship with.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends git openjdk-17-jre-headless \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER airflow

# dbt-snowflake and snowflake-cli pin their own versions of click/jinja2/
# requests/pydantic that conflict with Airflow's own constraint-pinned
# versions. Installing them straight into Airflow's environment is what
# caused the ResolutionImpossible error - so they get their own isolated
# venv instead. BashOperator tasks call the tools by full path below.
COPY airflow/requirements.txt /requirements.txt
RUN python -m venv /home/airflow/.venvs/snowflake-tools \
    && /home/airflow/.venvs/snowflake-tools/bin/pip install --no-cache-dir --upgrade pip \
    && /home/airflow/.venvs/snowflake-tools/bin/pip install --no-cache-dir -r /requirements.txt

# spark-submit client for the big data stack (docker-compose.bigdata.yml).
# Java (installed above) + PySpark matching the cluster's Spark 3.5.3. Jobs are
# submitted to YARN in cluster mode, so the driver runs on the cluster and this
# image only needs the submit client, not a matching Python for the executors.
RUN python -m venv /home/airflow/.venvs/spark-tools \
    && /home/airflow/.venvs/spark-tools/bin/pip install --no-cache-dir --upgrade pip \
    && /home/airflow/.venvs/spark-tools/bin/pip install --no-cache-dir pyspark==3.5.3
