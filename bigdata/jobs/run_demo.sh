#!/bin/bash
# Land the sample CSVs in HDFS, then run the PySpark job on YARN.
set -e
hdfs dfs -mkdir -p /data/aether/raw
hdfs dfs -put -f /opt/data/*.csv /data/aether/raw/
hdfs dfs -ls /data/aether/raw
spark-submit /opt/jobs/daily_traded_value.py
