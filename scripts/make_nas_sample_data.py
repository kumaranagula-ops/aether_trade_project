"""Write sample NAS files (customers JSON, products CSV, orders CSV) for the
aether_trade_nas_pipeline DAG. Default target is ./nas/landing.

    python3 scripts/make_nas_sample_data.py [landing_dir]
"""
import csv
import json
import random
import sys
from datetime import datetime, timedelta
from pathlib import Path

landing = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "nas" / "landing"
random.seed(7)

customers_dir = landing / "customers"
products_dir = landing / "products"
orders_dir = landing / "orders"
for d in (customers_dir, products_dir, orders_dir):
    d.mkdir(parents=True, exist_ok=True)

countries = ["IN", "US", "GB", "DE", "SG"]
customers = [
    {"customer_id": i, "name": f"  customer {i} ", "email": f"Customer{i}@Example.com",
     "country": random.choice(countries).lower(), "signup_date": f"2026-0{random.randint(1, 9)}-1{random.randint(0, 9)}"}
    for i in range(1, 21)
]
customers.append({**customers[0], "email": "updated1@example.com"})  # duplicate -> silver keeps one
(customers_dir / "customers_2026-11-01.json").write_text("\n".join(json.dumps(c) for c in customers))

products = [
    (1, "Laptop", "Electronics", 899.00), (2, "Headphones", "Electronics", 129.50),
    (3, "Desk Chair", "Furniture", 249.99), (4, "Standing Desk", "Furniture", 549.00),
    (5, "Notebook", "Stationery", 4.25), (6, "Pen Set", "Stationery", 12.00),
]
with open(products_dir / "products.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["product_id", "product_name", "category", "unit_price"])
    w.writerows(products)

start = datetime(2026, 10, 25)
for day in range(7):
    rows = []
    for n in range(random.randint(8, 15)):
        ts = start + timedelta(days=day, minutes=random.randint(0, 1439))
        rows.append([day * 100 + n, random.randint(1, 20), random.randint(1, 6),
                     random.choice([1, 1, 2, 3]), ts.isoformat(sep=" ")])
    rows.append([day * 100 + 99, 1, 1, 0, start.isoformat(sep=" ")])  # bad row -> filtered in silver
    with open(orders_dir / f"orders_{(start + timedelta(days=day)).date()}.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["order_id", "customer_id", "product_id", "quantity", "order_ts"])
        w.writerows(rows)

print(f"Sample data written under {landing}")
