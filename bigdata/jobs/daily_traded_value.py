"""First PySpark job on the Aether Trade lake.

Reads the raw execution + security CSVs from HDFS, writes a partitioned Parquet
Hive table (aether_lake.execution) and a daily summary (aether_lake.daily_traded_value).
"""
from pyspark.sql import SparkSession, functions as F

RAW = "hdfs://namenode:8020/data/aether/raw"

spark = (
    SparkSession.builder.appName("aether_trade_daily_traded_value")
    .enableHiveSupport()
    .getOrCreate()
)

execution = spark.read.csv(f"{RAW}/execution.csv", header=True, inferSchema=True)
security = spark.read.csv(f"{RAW}/security.csv", header=True, inferSchema=True)

spark.sql("CREATE DATABASE IF NOT EXISTS aether_lake")

execution = execution.withColumn("trade_dt", F.to_date("fill_ts"))
(
    execution.repartition("trade_dt")
    .write.mode("overwrite")
    .partitionBy("trade_dt")
    .format("parquet")
    .saveAsTable("aether_lake.execution")
)

daily = (
    spark.table("aether_lake.execution")
    .join(F.broadcast(security), "security_id")
    .groupBy("trade_dt", "ticker", "asset_class")
    .agg(
        F.count("*").alias("fills"),
        F.sum("fill_qty").alias("total_qty"),
        F.round(F.sum(F.col("fill_qty") * F.col("fill_px")), 2).alias("traded_value"),
        F.round(F.sum("commission"), 2).alias("commission"),
    )
)
daily.write.mode("overwrite").format("parquet").saveAsTable("aether_lake.daily_traded_value")

print(f"execution rows: {spark.table('aether_lake.execution').count()}")
spark.table("aether_lake.daily_traded_value").orderBy(F.desc("traded_value")).show(10, truncate=False)

spark.stop()
