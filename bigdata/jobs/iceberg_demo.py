"""Iceberg on the Aether Trade lake: create, upsert, evolve schema, time travel.

Builds lake.aether_iceberg.execution from the raw execution CSV in HDFS, then
walks through the features that plain Hive/Parquet tables do not have.
Safe to re-run: it drops and rebuilds the table each time.
"""
from pyspark.sql import SparkSession, functions as F

RAW = "hdfs://namenode:8020/data/aether/raw"
T = "lake.aether_iceberg.execution"

spark = SparkSession.builder.appName("aether_trade_iceberg_demo").getOrCreate()
spark.sparkContext.setLogLevel("WARN")


def banner(text):
    print(f"\n=== {text} ===")


execution = spark.read.csv(f"{RAW}/execution.csv", header=True, inferSchema=True)

banner("1. Create the Iceberg table, partitioned by day of fill_ts (hidden partitioning)")
spark.sql("CREATE NAMESPACE IF NOT EXISTS lake.aether_iceberg")
spark.sql(f"DROP TABLE IF EXISTS {T} PURGE")
execution.writeTo(T).partitionedBy(F.days("fill_ts")).create()
first_snapshot = spark.sql(f"SELECT snapshot_id FROM {T}.snapshots ORDER BY committed_at").first()[0]
print(f"rows: {spark.table(T).count()}   first snapshot: {first_snapshot}")

banner("2. MERGE INTO: correct 100 existing fills and insert 5 new ones (row-level upsert)")
corrections = execution.filter("execution_id <= 100").withColumn("commission", F.col("commission") + 1.0)
new_fills = execution.filter("execution_id <= 5").withColumn("execution_id", F.col("execution_id") + 10_000_000)
corrections.unionByName(new_fills).createOrReplaceTempView("execution_changes")
spark.sql(f"""
    MERGE INTO {T} t
    USING execution_changes s
    ON t.execution_id = s.execution_id
    WHEN MATCHED THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
""")
print(f"rows after merge: {spark.table(T).count()}")

banner("3. Schema evolution: add a column without rewriting any data files")
spark.sql(f"ALTER TABLE {T} ADD COLUMN settlement_dt date")
spark.table(T).printSchema()

banner("4. Time travel: the table as it was before the merge vs now")
summary = "count(*) AS row_count, round(sum(commission), 2) AS total_commission"
spark.sql(f"SELECT 'first snapshot' AS version, {summary} FROM {T} VERSION AS OF {first_snapshot}").show(truncate=False)
spark.sql(f"SELECT 'current' AS version, {summary} FROM {T}").show(truncate=False)

banner("5. Snapshot history kept in the table's own metadata")
spark.sql(f"""
    SELECT committed_at, snapshot_id, operation,
           summary['added-records'] AS added, summary['deleted-records'] AS deleted
    FROM {T}.snapshots ORDER BY committed_at
""").show(truncate=False)

banner("6. Partitions Iceberg derived from fill_ts")
spark.sql(f"SELECT partition, record_count, file_count FROM {T}.partitions ORDER BY partition").show(30, truncate=False)

spark.stop()
