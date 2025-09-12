from flask import Flask, request, jsonify
from kafka import KafkaProducer
from kafka.errors import NoBrokersAvailable
import os, json, time

app = Flask(__name__)

BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "roman-input")
SECURITY_PROTOCOL = os.getenv("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT")  # "PLAINTEXT" or "SSL" or "SASL_SSL"
SASL_MECHANISM = os.getenv("KAFKA_SASL_MECHANISM", "")                 # e.g., "SCRAM-SHA-512"
SASL_USERNAME = os.getenv("KAFKA_SASL_USERNAME", "")
SASL_PASSWORD = os.getenv("KAFKA_SASL_PASSWORD", "")
SSL_CAFILE    = os.getenv("KAFKA_SSL_CAFILE", "")  # optional path if you need a custom CA

def build_producer():
    kwargs = {
        "bootstrap_servers": BOOTSTRAP.split(","),
        "value_serializer": lambda v: json.dumps(v).encode("utf-8"),
        "security_protocol": SECURITY_PROTOCOL
    }
    if SECURITY_PROTOCOL in ("SSL","SASL_SSL"):
        if SSL_CAFILE:
            kwargs["ssl_cafile"] = SSL_CAFILE
    if SECURITY_PROTOCOL == "SASL_SSL":
        kwargs["sasl_mechanism"] = SASL_MECHANISM
        kwargs["sasl_plain_username"] = SASL_USERNAME
        kwargs["sasl_plain_password"] = SASL_PASSWORD
    return KafkaProducer(**kwargs)

producer = None
for i in range(12):
    try:
        producer = build_producer()
        print("✅ Producer connected to Kafka")
        break
    except NoBrokersAvailable as e:
        print(f"⚠️ Kafka not ready ({i+1}/12): {e}")
        time.sleep(5)

if not producer:
    raise Exception("❌ Producer failed to connect to Kafka")

@app.get("/healthz")
def health():
    return "ok", 200

@app.post("/produce")
def produce():
    payload = request.get_json(silent=True) or {}
    roman = (payload.get("data") or "").strip().upper()
    if not roman:
        return jsonify({"status":"error","message":"No data provided"}), 400

    producer.send(TOPIC, {"value": roman})
    producer.flush()
    return jsonify({"status":"queued","message":roman}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
