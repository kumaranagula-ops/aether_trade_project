"""Shared settings for the NAS pipeline jobs.

Shipped to YARN next to each job with --py-files, so bronze/silver/gold can import it.
The Hive Metastore and Iceberg catalogs come from spark-defaults.conf.
"""
from pyspark.sql import SparkSession

# The Airflow DAG mirrors the NAS landing folder here, one sub-folder per source.
LANDING = "hdfs://namenode:8020/data/nas/landing"

BRONZE = "nas_bronze"        # Hive/Parquet tables in the default catalog
SILVER = "lake.nas_silver"   # Iceberg tables
GOLD = "lake.nas_gold"       # Iceberg tables

SOURCES = {
    "customers": {"format": "json", "options": {}},
    "products": {"format": "csv", "options": {"header": "true", "inferSchema": "true"}},
    "orders": {"format": "csv", "options": {"header": "true", "inferSchema": "true"}},
}


def spark_session(name: str) -> SparkSession:
    spark = SparkSession.builder.appName(name).enableHiveSupport().getOrCreate()
    spark.sparkContext.setLogLevel("WARN")
    return spark
