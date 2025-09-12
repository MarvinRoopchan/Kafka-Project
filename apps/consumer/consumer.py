from flask import Flask, jsonify, request
from kafka import KafkaConsumer
import psycopg2, json, os, time, threading

app = Flask(__name__)

# --- ENV ---
BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "roman-input")
SECURITY_PROTOCOL = os.getenv("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT")  # SSL/SASL_SSL supported
SASL_MECHANISM = os.getenv("KAFKA_SASL_MECHANISM", "")
SASL_USERNAME = os.getenv("KAFKA_SASL_USERNAME", "")
SASL_PASSWORD = os.getenv("KAFKA_SASL_PASSWORD", "")
SSL_CAFILE    = os.getenv("KAFKA_SSL_CAFILE", "")

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_NAME = os.getenv("DB_NAME", "postgres")
DB_USER = os.getenv("DB_USER", "marvin_user")
DB_PASS = os.getenv("DB_PASS", "postgres")

def roman_to_int(s: str) -> int:
    if not s or not isinstance(s, str):
        return 0
    s = s.upper().strip()
    vals = {"I":1,"V":5,"X":10,"L":50,"C":100,"D":500,"M":1000}
    total = 0
    i = 0
    while i < len(s):
        if s[i] not in vals:
            return 0
        if i+1 < len(s) and s[i+1] in vals and vals[s[i]] < vals[s[i+1]]:
            total += vals[s[i+1]] - vals[s[i]]
            i += 2
        else:
            total += vals[s[i]]
            i += 1
    return total

# --- DB connect with retries ---
conn = None
for i in range(20):
    try:
        conn = psycopg2.connect(host=DB_HOST, dbname=DB_NAME, user=DB_USER, password=DB_PASS)
        conn.autocommit = False
        print("✅ Consumer connected to Postgres")
        break
    except Exception as e:
        print(f"⚠️ Postgres not ready ({i+1}/20): {e}")
        time.sleep(5)
if not conn:
    raise Exception("❌ Consumer cannot connect to Postgres")

# --- Ensure schema ---
def ensure_schema(c):
    with c.cursor() as cur:
        cur.execute("""
        CREATE TABLE IF NOT EXISTS public.inputs(
            id SERIAL PRIMARY KEY,
            roman TEXT,
            arabic INT,
            created_at TIMESTAMP DEFAULT NOW()
        );
        """)
        # If old column exists, rename it
        cur.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'inputs';
        """)
        cols = {r[0] for r in cur.fetchall()}
        if 'value' in cols and 'roman' not in cols:
            cur.execute("ALTER TABLE public.inputs RENAME COLUMN value TO roman;")
        if 'arabic' not in cols:
            cur.execute("ALTER TABLE public.inputs ADD COLUMN arabic INT;")
    c.commit()

ensure_schema(conn)

# --- Kafka consumer with retries ---
def build_consumer():
    kwargs = {
        "bootstrap_servers": BOOTSTRAP.split(","),
        "value_deserializer": lambda m: json.loads(m.decode("utf-8")),
        "auto_offset_reset": "latest",
        "enable_auto_commit": True,
        "group_id": "roman-consumer-group",
        "security_protocol": SECURITY_PROTOCOL
    }
    if SECURITY_PROTOCOL in ("SSL","SASL_SSL"):
        if SSL_CAFILE:
            kwargs["ssl_cafile"] = SSL_CAFILE
    if SECURITY_PROTOCOL == "SASL_SSL":
        kwargs["sasl_mechanism"] = SASL_MECHANISM
        kwargs["sasl_plain_username"] = SASL_USERNAME
        kwargs["sasl_plain_password"] = SASL_PASSWORD
    return KafkaConsumer(TOPIC, **kwargs)

kconsumer = None
for i in range(12):
    try:
        kconsumer = build_consumer()
        print("✅ Consumer connected to Kafka")
        break
    except Exception as e:
        print(f"⚠️ Kafka not ready ({i+1}/12): {e}")
        time.sleep(5)
if not kconsumer:
    raise Exception("❌ Consumer failed to connect to Kafka")

def consume_loop():
    while True:
        for msg in kconsumer:
            roman = (msg.value or {}).get("value")
            arabic = roman_to_int(roman)
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "INSERT INTO public.inputs (roman, arabic) VALUES (%s, %s);",
                        (roman, arabic)
                    )
                conn.commit()
                print(f"📥 {roman} -> {arabic} stored")
            except Exception as e:
                conn.rollback()
                print(f"❌ DB insert failed: {e}")

threading.Thread(target=consume_loop, daemon=True).start()

@app.get("/healthz")
def health():
    # rudimentary check
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1;")
        return "ok", 200
    except Exception as e:
        return f"db error: {e}", 500

@app.get("/consume")
def get_latest():
    """
    Optional ?roman=V to fetch latest row for that roman specifically.
    """
    try:
        qroman = request.args.get("roman")
        with conn.cursor() as cur:
            if qroman:
                cur.execute(
                    "SELECT id, roman, arabic, created_at FROM public.inputs WHERE roman=%s ORDER BY id DESC LIMIT 1;",
                    (qroman,)
                )
            else:
                cur.execute("SELECT id, roman, arabic, created_at FROM public.inputs ORDER BY id DESC LIMIT 1;")
            row = cur.fetchone()
        if row:
            return jsonify({"status":"ok","id":row[0],"roman":row[1],"arabic":row[2],"created_at":str(row[3])})
        else:
            return jsonify({"status":"empty","message":"No records yet"})
    except Exception as e:
        return jsonify({"status":"error","message":str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
