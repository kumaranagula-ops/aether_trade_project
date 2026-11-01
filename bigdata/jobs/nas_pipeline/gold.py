"""Gold: reporting aggregates over silver, rebuilt each run as Iceberg tables."""
from common import GOLD, SILVER, spark_session

spark = spark_session("nas_pipeline_gold")
spark.sql(f"CREATE NAMESPACE IF NOT EXISTS {GOLD}")

TABLES = {
    "daily_sales": ("Revenue by day and category", f"""
        SELECT o.order_date,
               p.category,
               COUNT(DISTINCT o.order_id)                            AS orders,
               SUM(o.quantity)                                       AS units,
               CAST(SUM(o.quantity * p.unit_price) AS DECIMAL(12,2)) AS revenue
        FROM {SILVER}.orders o
        JOIN {SILVER}.products p ON o.product_id = p.product_id
        GROUP BY o.order_date, p.category
    """),
    "customer_value": ("Lifetime value per customer", f"""
        SELECT c.customer_id, c.name, c.country,
               COUNT(o.order_id)                                                  AS orders,
               CAST(COALESCE(SUM(o.quantity * p.unit_price), 0) AS DECIMAL(12,2)) AS lifetime_value,
               MAX(o.order_date)                                                  AS last_order_date
        FROM {SILVER}.customers c
        LEFT JOIN {SILVER}.orders o   ON c.customer_id = o.customer_id
        LEFT JOIN {SILVER}.products p ON o.product_id = p.product_id
        GROUP BY c.customer_id, c.name, c.country
    """),
}

for name, (comment, query) in TABLES.items():
    table = f"{GOLD}.{name}"
    spark.sql(query).writeTo(table).tableProperty("comment", comment).createOrReplace()
    print(f"[gold] {table}: {spark.table(table).count()} rows")

spark.sql(f"SELECT * FROM {GOLD}.daily_sales ORDER BY order_date, category").show(30, truncate=False)

spark.stop()
