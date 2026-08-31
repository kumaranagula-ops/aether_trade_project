#!/usr/bin/env python3
"""Generate Aether Trade sample CSVs (~25k executions)."""
from __future__ import annotations

import csv
import random
from datetime import date, datetime, timedelta
from pathlib import Path

OUT = Path("/home/workdir/artifacts/aether-trade/data")
OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(42)

REGIONS = ["Northeast", "Southeast", "Midwest", "West", "Southwest"]
FIRST = ["James", "Maria", "Wei", "Priya", "Noah", "Ava", "Omar", "Elena", "Raj", "Sofia", "Liam", "Anika"]
LAST = ["Patel", "Chen", "Garcia", "Johnson", "Khan", "Williams", "Singh", "Kim", "Brown", "Lopez", "Iyer", "Nguyen"]
TICKERS = [
    ("AAPL", "Apple Inc", "EQUITY"), ("MSFT", "Microsoft Corp", "EQUITY"),
    ("GOOGL", "Alphabet Inc", "EQUITY"), ("AMZN", "Amazon.com Inc", "EQUITY"),
    ("NVDA", "NVIDIA Corp", "EQUITY"), ("META", "Meta Platforms", "EQUITY"),
    ("JPM", "JPMorgan Chase", "EQUITY"), ("GS", "Goldman Sachs", "EQUITY"),
    ("MS", "Morgan Stanley", "EQUITY"), ("V", "Visa Inc", "EQUITY"),
    ("JNJ", "Johnson & Johnson", "EQUITY"), ("UNH", "UnitedHealth", "EQUITY"),
    ("XOM", "Exxon Mobil", "EQUITY"), ("CVX", "Chevron", "EQUITY"),
    ("SPY", "SPDR S&P 500 ETF", "ETF"), ("QQQ", "Invesco QQQ", "ETF"),
    ("IWM", "iShares Russell 2000", "ETF"), ("GLD", "SPDR Gold Shares", "ETF"),
    ("TLT", "iShares 20+ Year Treasury", "ETF"), ("HYG", "iShares High Yield Corp", "ETF"),
]
BASE_PX = {
    "AAPL": 190, "MSFT": 420, "GOOGL": 165, "AMZN": 185, "NVDA": 880,
    "META": 510, "JPM": 198, "GS": 450, "MS": 97, "V": 275,
    "JNJ": 155, "UNH": 520, "XOM": 112, "CVX": 155,
    "SPY": 530, "QQQ": 450, "IWM": 205, "GLD": 215, "TLT": 92, "HYG": 77,
}
VENUES = ["NYSE", "NASDAQ", "ARCA", "BATS", "DARK"]


def write_csv(name: str, rows: list[dict], fieldnames: list[str]) -> None:
    path = OUT / name
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {path.name}: {len(rows)} rows")


def main() -> None:
    branches = []
    for i, region in enumerate(REGIONS, start=1):
        branches.append({
            "branch_id": i,
            "branch_code": f"BR{i:02d}",
            "branch_name": f"{region} Wealth Hub",
            "region": region,
        })

    advisors = []
    for i in range(1, 26):
        br = branches[(i - 1) % len(branches)]
        advisors.append({
            "advisor_id": i,
            "branch_id": br["branch_id"],
            "advisor_code": f"FA{i:03d}",
            "full_name": f"{RNG.choice(FIRST)} {RNG.choice(LAST)}",
            "email": f"fa{i:03d}@aether.example",
            "is_active": True,
        })

    customers = []
    for i in range(1, 121):
        customers.append({
            "customer_id": i,
            "advisor_id": ((i - 1) % 25) + 1,
            "customer_code": f"C{i:05d}",
            "full_name": f"{RNG.choice(FIRST)} {RNG.choice(LAST)}",
            "kyc_status": "APPROVED" if i % 17 else "PENDING",
            "risk_profile": RNG.choice(["CONSERVATIVE", "MODERATE", "AGGRESSIVE"]),
            "tax_residency": RNG.choice(["US", "US", "US", "IN", "GB"]),
        })

    accounts = []
    aid = 1
    for c in customers:
        n = 1 if c["customer_id"] % 3 else 2
        for k in range(n):
            accounts.append({
                "account_id": aid,
                "customer_id": c["customer_id"],
                "account_no": f"ACC{aid:07d}",
                "account_type": RNG.choice(["CASH", "MARGIN", "IRA", "401K"]),
                "base_ccy": "USD",
                "status": "OPEN",
                "opened_dt": date(2018, 1, 1) + timedelta(days=RNG.randint(0, 2500)),
            })
            aid += 1

    exchanges = [
        {"exchange_id": 1, "exchange_code": "NYSE", "exchange_name": "New York Stock Exchange", "timezone": "America/New_York"},
        {"exchange_id": 2, "exchange_code": "NASDAQ", "exchange_name": "Nasdaq", "timezone": "America/New_York"},
        {"exchange_id": 3, "exchange_code": "ARCA", "exchange_name": "NYSE Arca", "timezone": "America/New_York"},
    ]
    securities = []
    for i, (tkr, name, cls) in enumerate(TICKERS, start=1):
        securities.append({
            "security_id": i,
            "exchange_id": 2 if tkr in {"AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "QQQ"} else 1,
            "ticker": tkr,
            "isin": f"US{1000000000 + i}",
            "security_name": name,
            "asset_class": cls,
        })

    users = []
    for a in advisors:
        users.append({
            "user_id": a["advisor_id"],
            "user_name": a["advisor_code"].lower(),
            "role_code": "ADVISOR",
            "advisor_id": a["advisor_id"],
        })

    # 10 business days ending 2026-08-28
    trade_days = []
    d = date(2026, 8, 17)
    while len(trade_days) < 10:
        if d.weekday() < 5:
            trade_days.append(d)
        d += timedelta(days=1)

    orders = []
    executions = []
    cash = []
    oid = 1
    eid = 1
    lid = 1

    for _ in range(15500):
        acct = RNG.choice(accounts)
        sec = RNG.choice(securities)
        day = RNG.choice(trade_days)
        ts = datetime(day.year, day.month, day.day, RNG.randint(9, 15), RNG.randint(0, 59), RNG.randint(0, 59))
        side = RNG.choice(["B", "B", "B", "S"])
        qty = RNG.choice([10, 25, 50, 75, 100, 150, 200, 500])
        px = round(BASE_PX[sec["ticker"]] * RNG.uniform(0.97, 1.03), 2)
        n_fills = RNG.choices([1, 2, 3, 4], weights=[55, 25, 15, 5])[0]
        remaining = qty
        fills = []
        for f in range(n_fills):
            fq = remaining if f == n_fills - 1 else max(1, remaining // (n_fills - f))
            remaining -= fq
            fills.append(fq)
        filled = sum(fills)
        status = "FILLED" if filled == qty else "PARTIAL"
        if RNG.random() < 0.04:
            status = "CXL"
            fills = fills[:1]
            filled = fills[0] if fills else 0
        if RNG.random() < 0.02:
            status = "REJ"
            fills = []
            filled = 0

        orders.append({
            "order_id": oid,
            "account_id": acct["account_id"],
            "security_id": sec["security_id"],
            "entered_by": acct["customer_id"] % 25 + 1,
            "side": side,
            "order_type": RNG.choice(["LMT", "LMT", "MKT"]),
            "ordered_qty": qty,
            "limit_px": px if status != "REJ" else px,
            "tif": "DAY",
            "status": status,
            "reject_reason": "RISK_LIMIT" if status == "REJ" else "",
            "order_ts": ts.isoformat(sep=" "),
            "last_update_ts": (ts + timedelta(seconds=RNG.randint(1, 90))).isoformat(sep=" "),
        })

        tfill = ts
        for fq in fills:
            tfill = tfill + timedelta(milliseconds=RNG.randint(20, 800))
            fpx = round(px * RNG.uniform(0.999, 1.001), 2)
            comm = round(max(0.99, fq * 0.005), 2)
            executions.append({
                "execution_id": eid,
                "order_id": oid,
                "account_id": acct["account_id"],
                "security_id": sec["security_id"],
                "fill_qty": fq,
                "fill_px": fpx,
                "commission": comm,
                "venue": RNG.choice(VENUES),
                "fill_ts": tfill.isoformat(sep=" "),
            })
            signed = -fq * fpx if side == "B" else fq * fpx
            cash.append({
                "ledger_id": lid,
                "account_id": acct["account_id"],
                "execution_id": eid,
                "amount": round(signed - comm, 2),
                "ccy": "USD",
                "reason_code": "TRADE",
                "value_dt": day.isoformat(),
                "created_at": tfill.isoformat(sep=" "),
            })
            eid += 1
            lid += 1
        oid += 1

    # Positions from net executions
    order_side = {o["order_id"]: o["side"] for o in orders}
    pos_map = {}
    for e in executions:
        key = (e["account_id"], e["security_id"])
        rec = pos_map.setdefault(key, {"qty": 0.0, "cost": 0.0})
        q = float(e["fill_qty"])
        p = float(e["fill_px"])
        if order_side[e["order_id"]] == "B":
            rec["cost"] += q * p
            rec["qty"] += q
        else:
            rec["qty"] -= q
            rec["cost"] -= q * p

    positions = []
    pid = 1
    ticker_by_id = {s["security_id"]: s["ticker"] for s in securities}
    for (acct_id, sec_id), rec in pos_map.items():
        if abs(rec["qty"]) < 0.0001:
            continue
        avg = rec["cost"] / rec["qty"] if rec["qty"] else 0
        last = BASE_PX[ticker_by_id[sec_id]]
        positions.append({
            "position_id": pid,
            "account_id": acct_id,
            "security_id": sec_id,
            "qty": round(rec["qty"], 4),
            "avg_cost": round(avg, 6),
            "last_px": last,
            "updated_at": "2026-08-28 16:00:00",
        })
        pid += 1

    write_csv("branch.csv", branches, list(branches[0].keys()))
    write_csv("advisor.csv", advisors, list(advisors[0].keys()))
    write_csv("customer.csv", customers, list(customers[0].keys()))
    write_csv("account.csv", accounts, list(accounts[0].keys()))
    write_csv("exchange.csv", exchanges, list(exchanges[0].keys()))
    write_csv("security.csv", securities, list(securities[0].keys()))
    write_csv("app_user.csv", users, list(users[0].keys()))
    write_csv("orders.csv", orders, list(orders[0].keys()))
    write_csv("execution.csv", executions, list(executions[0].keys()))
    write_csv("cash_ledger.csv", cash, list(cash[0].keys()))
    write_csv("position.csv", positions, list(positions[0].keys()) if positions else [
        "position_id", "account_id", "security_id", "qty", "avg_cost", "last_px", "updated_at"
    ])
    print("done")


if __name__ == "__main__":
    main()
