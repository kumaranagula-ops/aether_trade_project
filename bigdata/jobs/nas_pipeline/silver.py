"""Silver: type, clean and de-duplicate bronze into Iceberg tables.

First run creates lake.nas_silver.*; later runs MERGE on the business key, so
changed rows are updated in place and new rows are inserted.
"""
from pyspark.sql import Window, functions as F

from common import BRONZE, SILVER, spark_session

spark = spark_session("nas_pipeline_silver")
spark.sql(f"CREATE NAMESPACE IF NOT EXISTS {SILVER}")


def latest(df, key):
    """Keep the most recently ingested row per key."""
    w = Window.partitionBy(key).orderBy(F.col("_ingested_at").desc(), F.col("_source_file").desc())
    return df.withColumn("_rn", F.row_number().over(w)).filter("_rn = 1").drop("_rn")


def upsert(df, name, key, comment, partition_col=None):
    table = f"{SILVER}.{name}"
    if not spark.catalog.tableExists(table):
        writer = df.writeTo(table).tableProperty("comment", comment)
        if partition_col:
            writer = writer.partitionedBy(F.col(partition_col))
        writer.create()
    else:
        df.createOrReplaceTempView(f"{name}_changes")
        spark.sql(f"""
            MERGE INTO {table} t
            USING {name}_changes s
            ON t.{key} = s.{key}
            WHEN MATCHED THEN UPDATE SET *
            WHEN NOT MATCHED THEN INSERT *
        """)
    print(f"[silver] {table}: {spark.table(table).count()} rows")


customers = latest(spark.table(f"{BRONZE}.customers"), "customer_id").select(
    F.col("customer_id").cast("int"),
    F.initcap(F.trim("name")).alias("name"),
    F.lower(F.trim("email")).alias("email"),
    F.upper(F.trim("country")).alias("country"),
    F.to_date("signup_date").alias("signup_date"),
)
upsert(customers, "customers", "customer_id", "One row per customer")

products = latest(spark.table(f"{BRONZE}.products"), "product_id").select(
    F.col("product_id").cast("int"),
    F.trim("product_name").alias("product_name"),
    F.trim("category").alias("category"),
    F.col("unit_price").cast("decimal(10,2)").alias("unit_price"),
)
upsert(products, "products", "product_id", "One row per product")

orders = (
    latest(spark.table(f"{BRONZE}.orders"), "order_id")
    .filter(F.col("quantity") > 0)
    .select(
        F.col("order_id").cast("int"),
        F.col("customer_id").cast("int"),
        F.col("product_id").cast("int"),
        F.col("quantity").cast("int"),
        F.to_timestamp("order_ts").alias("order_ts"),
        F.to_date("order_ts").alias("order_date"),
    )
)
upsert(orders, "orders", "order_id", "Valid orders, partitioned by order_date", partition_col="order_date")

spark.stop()
