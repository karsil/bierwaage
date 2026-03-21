from datetime import datetime, timezone
from typing import Any, Optional

import duckdb
from fastapi import FastAPI, Request

DB_PATH = "/data/bierwaage.duckdb"

app = FastAPI()

con = duckdb.connect(DB_PATH)
con.execute("""
    CREATE TABLE IF NOT EXISTS measurements (
        ts                  TIMESTAMPTZ NOT NULL,
        ts_ingest           TIMESTAMPTZ NOT NULL,
        gewicht_kg          DOUBLE,
        temp_ds18b20        DOUBLE,
        temp_bme280         DOUBLE,
        pressure_hpa        DOUBLE,
        humidity_pct        DOUBLE,
        encoder_value       INTEGER,
        button_pressed      BOOLEAN,
        button_long_pressed BOOLEAN
    )
""")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/ingest")
async def ingest(request: Request):
    body = await request.json()
    payload = body.get("metrics", []) if isinstance(body, dict) else body
    rows = []
    for item in payload:
        fields = item.get("fields", {})
        timestamp_ns = item.get("timestamp")

        if timestamp_ns:
            ts_ingest = datetime.fromtimestamp(timestamp_ns / 1e9, tz=timezone.utc)
        else:
            ts_ingest = datetime.now(tz=timezone.utc)

        date_str = fields.get("datetime_date", "")
        time_str = fields.get("datetime_time", "")
        if date_str and time_str:
            try:
                ts = datetime.strptime(
                    f"{date_str} {time_str}", "%d.%m.%Y %H:%M:%S"
                ).replace(tzinfo=timezone.utc)
            except ValueError:
                ts = ts_ingest
        else:
            ts = ts_ingest

        rows.append((
            ts,
            ts_ingest,
            fields.get("waage_gewicht_kg"),
            fields.get("ds18b20_sensor_0"),
            fields.get("bme280_temperature"),
            fields.get("bme280_pressure"),
            fields.get("bme280_humidity"),
            fields.get("encoder_value"),
            fields.get("encoder_button_pressed"),
            fields.get("encoder_button_long_pressed"),
        ))

    if rows:
        con.executemany(
            "INSERT INTO measurements VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            rows,
        )

    return {"inserted": len(rows)}


@app.get("/api/measurements")
def get_measurements(
    from_ts: Optional[str] = None,
    to_ts: Optional[str] = None,
    limit: int = 1000,
):
    conditions = []
    if from_ts:
        conditions.append(f"ts >= '{from_ts}'")
    if to_ts:
        conditions.append(f"ts <= '{to_ts}'")
    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    # Open a separate read-only connection per request — the global write connection
    # is not safe to share concurrently with reads (causes NULL dereference in DuckDB).
    with duckdb.connect(DB_PATH) as rcon:
        rows = rcon.execute(
            f"SELECT ts, gewicht_kg, temp_ds18b20, temp_bme280, pressure_hpa, "
            f"humidity_pct, encoder_value, button_pressed, button_long_pressed "
            f"FROM measurements {where} ORDER BY ts DESC LIMIT {limit}"
        ).fetchall()
    cols = ["ts", "gewicht_kg", "temp_ds18b20", "temp_bme280", "pressure_hpa",
            "humidity_pct", "encoder_value", "button_pressed", "button_long_pressed"]
    return [dict(zip(cols, (r[0].isoformat() if i == 0 else r[i] for i, _ in enumerate(r)))) for r in rows]
