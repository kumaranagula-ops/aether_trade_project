"""Bronze: load every NAS source folder from the HDFS landing zone as-is.

Writes nas_bronze.<source> (Hive/Parquet) with two lineage columns:
_source_file and _ingested_at.
"""
from pyspark.sql import functions as F

from common import BRONZE, LANDING, SOURCES, spark_session

spark = spark_session("nas_pipeline_bronze")
spark.sql(f"CREATE DATABASE IF NOT EXISTS {BRONZE} COMMENT 'Raw NAS files with ingest metadata'")

for name, src in SOURCES.items():
    df = (
        spark.read.format(src["format"])
        .options(**src["options"])
        .load(f"{LANDING}/{name}")
        .withColumn("_source_file", F.col("_metadata.file_path"))
        .withColumn("_ingested_at", F.current_timestamp())
    )
    table = f"{BRONZE}.{name}"
    df.write.mode("overwrite").format("parquet").saveAsTable(table)
    spark.sql(f"ALTER TABLE {table} SET TBLPROPERTIES ('comment' = 'Raw {src['format']} from {LANDING}/{name}')")
    print(f"[bronze] {table}: {spark.table(table).count()} rows")

spark.stop()
