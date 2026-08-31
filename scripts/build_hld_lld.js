const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
        Header, Footer, AlignmentType, HeadingLevel, BorderStyle, WidthType,
        ShadingType, PageNumber, LevelFormat } = require("docx");
const fs = require("fs");

const PAGE = { width: 12240, height: 15840, margin: { top: 1080, right: 1080, bottom: 1080, left: 1080 } };
const TW = 10080;
const border = { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" };
const borders = { top: border, bottom: border, left: border, right: border };
const navy = "1B365D";

function p(text, opts = {}) {
  return new Paragraph({ spacing: { after: 160 }, ...opts, children: [new TextRun({ font: "Arial", size: 22, ...opts.run, text })] });
}
function h1(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 280, after: 140 },
    children: [new TextRun({ text, font: "Arial", size: 28, bold: true, color: navy })] });
}
function h2(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_2, spacing: { before: 220, after: 120 },
    children: [new TextRun({ text, font: "Arial", size: 24, bold: true, color: "2B6CB0" })] });
}
function bullet(text, ref = "bullets") {
  return new Paragraph({ numbering: { reference: ref, level: 0 }, spacing: { after: 80 },
    children: [new TextRun({ text, font: "Arial", size: 22 })] });
}
function cell(text, width, header = false) {
  return new TableCell({
    borders, width: { size: width, type: WidthType.DXA },
    shading: { fill: header ? navy : "FFFFFF", type: ShadingType.CLEAR },
    margins: { top: 60, bottom: 60, left: 80, right: 80 },
    children: [new Paragraph({ children: [new TextRun({ text, font: "Arial", size: 18, bold: header, color: header ? "FFFFFF" : "000000" })] })]
  });
}
function table(headers, rows, widths) {
  const head = new TableRow({ children: headers.map((h, i) => cell(h, widths[i], true)) });
  const body = rows.map(r => new TableRow({ children: r.map((v, i) => cell(String(v), widths[i], false)) }));
  return new Table({ width: { size: TW, type: WidthType.DXA }, columnWidths: widths, rows: [head, ...body] });
}
function footer() {
  return new Footer({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [
    new TextRun({ text: "Aether Trade  |  Confidential  |  Page ", font: "Arial", size: 16, color: "666666" }),
    new TextRun({ children: [PageNumber.CURRENT], font: "Arial", size: 16, color: "666666" }),
  ] })] });
}
const numbering = { config: [
  { reference: "bullets", levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT,
    style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
  { reference: "numbers", levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT,
    style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
]};
const styles = {
  default: { document: { run: { font: "Arial", size: 22 } } },
  paragraphStyles: [
    { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
      run: { size: 28, bold: true, font: "Arial", color: navy },
      paragraph: { spacing: { before: 280, after: 140 }, outlineLevel: 0 } },
    { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
      run: { size: 24, bold: true, font: "Arial", color: "2B6CB0" },
      paragraph: { spacing: { before: 220, after: 120 }, outlineLevel: 1 } },
  ]
};

async function writeHld() {
  const doc = new Document({
    styles, numbering,
    sections: [{
      properties: { page: { size: { width: PAGE.width, height: PAGE.height }, margin: PAGE.margin } },
      headers: { default: new Header({ children: [new Paragraph({ children: [new TextRun({ text: "Aether Trade  |  High-Level Design", font: "Arial", size: 16, color: navy, bold: true })] })] }) },
      footers: { default: footer() },
      children: [
        new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 80 }, children: [new TextRun({ text: "AETHER TRADE", font: "Arial", size: 40, bold: true, color: navy })] }),
        new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 }, children: [new TextRun({ text: "High-Level Design — Trading OMS to Snowflake Data Mart", font: "Arial", size: 24 })] }),
        p("Version 1.0  |  31 August 2026  |  Audience: architecture, data engineering, wealth operations"),
        h1("1. Purpose"),
        p("This document describes the reference architecture for a retail / wealth trading platform. A client or advisor enters an order in a web application. An OLTP order-management system (OMS) validates, risks, and matches the order in real time. Changes are published as CDC events. Snowflake lands those events, runs ELT, and serves a dimensional data mart for advisor books, risk, operations, and compliance reporting."),
        h1("2. Non-negotiable design decision"),
        p("Snowflake is not the matching engine. Order acknowledgement, buying-power checks, and fill application to positions must complete in tens to hundreds of milliseconds. Those paths stay in the OMS. Snowflake is the system of analysis: near-real-time facts (minutes), EOD snapshots, and historical analytics."),
        h1("3. Scope"),
        h2("In scope"),
        bullet("Equities and ETFs, cash and margin accounts, market and limit day orders."),
        bullet("Partial fills, cancels, rejects, cash ledger, current positions."),
        bullet("CDC from OMS to object storage, Snowpipe auto-ingest, Streams and Tasks into STG and MART."),
        bullet("Star-schema mart: order fact, execution fact, EOD position snapshot, daily volume aggregate."),
        h2("Out of scope (phase 2)"),
        bullet("Options complex orders, short locate, prime-brokerage stock loan."),
        bullet("Sub-second advisor blotter served directly from Snowflake."),
        bullet("Full corporate-action lifecycle and tax lot relief algorithms."),
        h1("4. Logical architecture"),
        p("Layer 1 — Front office web app. Order ticket, working orders, positions view. Talks only to OMS APIs."),
        p("Layer 2 — OMS OLTP (PostgreSQL). Thirteen operational tables. This is the system of record for orders, fills, positions, and cash."),
        p("Layer 3 — Integration. OMS writes to cdc_outbox. A publisher (Debezium, custom worker, or Informatica IDMC CDC) writes JSON files to S3 folders orders/ and execution/."),
        p("Layer 4 — Snowflake RAW. Snowpipe AUTO_INGEST copies JSON into VARIANT CDC tables."),
        p("Layer 5 — Snowflake STG. Tasks flatten VARIANT, cast types, keep latest image per business key using MERGE and QUALIFY."),
        p("Layer 6 — Snowflake MART. SCD Type 2 dimensions and incremental facts. Clustering on date + account."),
        p("Layer 7 — Consumption. Tableau / Power BI on MART. Secure views for PII. Separate warehouse for ETL vs reporting."),
        h1("5. Data model"),
        p("OLTP is 3NF around ACCOUNT. MART is a star (Kimball) with conformed dimensions Customer, Account, Advisor, Security, Date."),
        table(["Layer", "Tables", "Grain example", "Keys"], [
          ["OLTP", "13 tables", "execution = one fill", "Natural BIGSERIAL PKs"],
          ["RAW", "8 CDC tables", "one change event", "event_id + VARIANT payload"],
          ["STG", "6 typed tables", "current row per natural key", "order_id / execution_id"],
          ["MART dims", "6 dimensions", "SCD2 version row", "Surrogate _sk"],
          ["MART facts", "3 facts + 1 agg", "fill / order / account-sec-day", "Surrogate + dim FKs"],
        ], [1800, 2200, 3200, 2880]),
        p(""),
        p("Sample volume generated with this pack: 120 customers, 160 accounts, 25 advisors, 20 securities, 15,500 orders, 25,324 executions, 3,144 current positions."),
        h1("6. Latency and SLAs"),
        table(["Path", "Target", "Mechanism"], [
          ["UI submit to OMS ACK", "50–200 ms", "OMS API + local DB commit"],
          ["Fill to OMS position", "< 1 second", "Same transaction or immediate follow-up"],
          ["Fill file on S3 to RAW", "1–5 min", "Snowpipe auto-ingest"],
          ["RAW to MART fact", "5–15 min", "Stream + 5-minute Task"],
          ["EOD position snapshot", "T+0 18:30 ET", "Scheduled Task after market close"],
        ], [3400, 2200, 4480]),
        p(""),
        h1("7. Security and control"),
        bullet("OMS holds live PII. Snowflake MART uses masked secure views for email and account numbers."),
        bullet("Separate virtual warehouses: ETL_WH (auto-suspend 60s) and BI_WH (multi-cluster, Standard policy in market hours)."),
        bullet("CTRL.JOB_AUDIT and CTRL.WATERMARK for restartability. Quarantine bad CDC rows instead of failing the pipe."),
        bullet("Time Travel 30 days on MART facts for finance incident recovery."),
        h1("8. Risks"),
        bullet("Treating Snowflake as OLTP will miss SLA and lock the wrong workload."),
        bullet("Duplicate CDC events if publisher retries — STG MERGE on natural key is mandatory."),
        bullet("Deletes of fills are rare; if they happen, MART MERGE must apply op = D."),
        bullet("Clock skew between OMS fill_ts and file arrival — use event_ts for watermarks, fill_ts for business date."),
      ]
    }]
  });
  const buf = await Packer.toBuffer(doc);
  fs.writeFileSync("/home/workdir/artifacts/aether-trade/docs/Aether_Trade_HLD.docx", buf);
}

async function writeLld() {
  const doc = new Document({
    styles, numbering,
    sections: [{
      properties: { page: { size: { width: PAGE.width, height: PAGE.height }, margin: PAGE.margin } },
      headers: { default: new Header({ children: [new Paragraph({ children: [new TextRun({ text: "Aether Trade  |  Low-Level Design", font: "Arial", size: 16, color: navy, bold: true })] })] }) },
      footers: { default: footer() },
      children: [
        new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 80 }, children: [new TextRun({ text: "AETHER TRADE", font: "Arial", size: 40, bold: true, color: navy })] }),
        new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 }, children: [new TextRun({ text: "Low-Level Design — Tables, mappings, jobs, sample load", font: "Arial", size: 24 })] }),
        h1("1. Order lifecycle"),
        p("NEW: ticket accepted after buying-power and restricted-list checks. PARTIAL: at least one fill, remaining qty > 0. FILLED: remaining qty = 0. CXL: working qty cancelled. REJ: never booked a fill (example reason RISK_LIMIT). Each status change writes oms.order_audit and oms.cdc_outbox."),
        h1("2. OLTP table list"),
        table(["Table", "PK", "Main FKs", "Notes"], [
          ["branch", "branch_id", "—", "Region hub"],
          ["advisor", "advisor_id", "branch_id", "FA book"],
          ["customer", "customer_id", "advisor_id", "KYC + risk_profile"],
          ["account", "account_id", "customer_id", "CASH/MARGIN/IRA/401K"],
          ["exchange", "exchange_id", "—", "NYSE/NASDAQ/ARCA"],
          ["security", "security_id", "exchange_id", "Ticker + asset class"],
          ["app_user", "user_id", "advisor_id", "Order entry identity"],
          ["orders", "order_id", "account, security, user", "Ticket + status"],
          ["execution", "execution_id", "order, account, security", "One fill"],
          ["position", "position_id", "account + security UK", "Current qty / avg_cost"],
          ["cash_ledger", "ledger_id", "account, execution", "Signed cash"],
          ["order_audit", "audit_id", "order_id", "Status history"],
          ["cdc_outbox", "event_id", "—", "Publish queue"],
        ], [2200, 2200, 2800, 2880]),
        p(""),
        h1("3. CDC contract"),
        p("Publisher reads unpublished rows from cdc_outbox, writes one JSON object per line (or a JSON array file) to s3://aether-cdc/{table}/dt=YYYY-MM-DD/{event_id}.json.gz. Payload is the full row image. op is I, U, or D. Snowflake Snowpipe uses STRIP_OUTER_ARRAY = TRUE."),
        p("Example execution payload fields: execution_id, order_id, account_id, security_id, fill_qty, fill_px, commission, venue, fill_ts."),
        h1("4. Snowflake job sequence"),
        bullet("PIPE_ORDERS and PIPE_EXECUTION auto-ingest into RAW.*_CDC."),
        bullet("TASK_LOAD_EXECUTION every 5 minutes when stream has data. MERGE into STG.EXECUTION on execution_id. QUALIFY keeps latest event_ts."),
        bullet("TASK_FACT_EXECUTION runs AFTER the staging task. Joins current SCD2 dimension keys. MERGE on execution_id."),
        bullet("Nightly TASK_POSITION_SNAPSHOT builds FACT_POSITION_SNAPSHOT from STG positions or reconstructed fills."),
        bullet("Nightly TASK_AGG_VOLUME rebuilds AGG_DAILY_VOLUME for the last 7 days."),
        h1("5. SCD Type 2 rule"),
        p("Customer, Account, Advisor, Security are Type 2. Compare hash of tracked attributes. On change: close current row (effective_to = event_ts, is_current = FALSE) and insert a new current row. Facts always join is_current = TRUE for near-real-time blotters. Point-in-time reconstruction uses effective_from / effective_to against fill_ts when required for historical books."),
        h1("6. Reconciliation"),
        bullet("OMS execution count vs STG.EXECUTION count vs MART.FACT_EXECUTION count by trade date."),
        bullet("Sum of fill_qty by order_id in MART must be <= ordered_qty on FACT_ORDER."),
        bullet("Cash: sum(cash_ledger.amount) for reason TRADE+FEE vs -1 * signed notional - commission."),
        bullet("Breaks land in CTRL.RECON_BREAK with severity. SLA: same-day close for HIGH."),
        h1("7. Sample data delivered"),
        table(["File", "Rows", "Use"], [
          ["orders.csv", "15500", "OMS + RAW seed"],
          ["execution.csv", "25324", "Primary fact seed"],
          ["cash_ledger.csv", "25324", "Cash movements"],
          ["position.csv", "3144", "Current holdings"],
          ["customer.csv / account.csv", "120 / 160", "Masters"],
          ["advisor.csv / security.csv", "25 / 20", "Masters"],
        ], [3000, 1800, 5280]),
        p(""),
        p("Load path for the sample (no live CDC): PUT or stage the CSVs, COPY into STG structured tables, then run the MART MERGE statements using those STG tables. Production path uses VARIANT RAW first."),
        h1("8. IDMC mapping sketch (if used instead of native Tasks)"),
        p("Mapping M_OMS_EXEC_TO_STG: Source = S3 JSON or Snowflake RAW. Expression: cast payload fields. Router: op D to delete path, else upsert path. Target = STG.EXECUTION. Mapping task parameterized by $Env and $LookbackMinutes. Taskflow: ingest masters first (security, account, customer), then orders, then executions, then facts."),
        h1("9. Open items"),
        bullet("Confirm whether cancelled fills should remain in FACT_EXECUTION (recommended: yes, with order status CXL)."),
        bullet("Confirm commission schedule vs flat 0.5 cents used in the sample generator."),
        bullet("Decide multi-currency accounts before adding FX rates dim."),
      ]
    }]
  });
  const buf = await Packer.toBuffer(doc);
  fs.writeFileSync("/home/workdir/artifacts/aether-trade/docs/Aether_Trade_LLD.docx", buf);
}

writeHld().then(writeLld).then(() => console.log("docs ok"));
