from flask import Flask, request, jsonify
import os, time, requests

app = Flask(__name__)

PRODUCER_URL = os.getenv("PRODUCER_URL", "http://producer:5000")
CONSUMER_URL = os.getenv("CONSUMER_URL", "http://consumer:5000")
CONNECT_TIMEOUT = float(os.getenv("CONNECT_TIMEOUT", "3"))
READ_TIMEOUT = float(os.getenv("READ_TIMEOUT", "3"))
POLL_TOTAL_SECS = float(os.getenv("POLL_TOTAL_SECS", "12"))
POLL_INTERVAL_SECS = float(os.getenv("POLL_INTERVAL_SECS", "0.5"))

@app.get("/healthz")
def healthz():
    return "ok", 200

@app.post("/process")
def process():
    payload = request.get_json(silent=True) or {}
    roman = (payload.get("data") or "").strip().upper()
    if not roman:
        return jsonify({"status":"error","message":"No data provided"}), 400

    # 1) enqueue to producer
    try:
        pr = requests.post(
            f"{PRODUCER_URL}/produce",
            json={"data": roman},
            timeout=(CONNECT_TIMEOUT, READ_TIMEOUT),
        )
        pr.raise_for_status()
    except Exception as e:
        return jsonify({"status":"error","message":f"producer error: {e}"}), 500

    # 2) poll consumer for matching roman
    deadline = time.time() + POLL_TOTAL_SECS
    last_err = None

    while time.time() < deadline:
        try:
            cr = requests.get(
                f"{CONSUMER_URL}/consume",
                params={"roman": roman},
                timeout=(CONNECT_TIMEOUT, READ_TIMEOUT),
            )
            cr.raise_for_status()
            data = cr.json()
            if data.get("status") == "ok" and (data.get("roman") == roman):
                return jsonify(data), 200
            # "empty" or not found yet → wait and poll again
            time.sleep(POLL_INTERVAL_SECS)
            continue
        except Exception as e:
            last_err = e
            time.sleep(POLL_INTERVAL_SECS)

    # If we’re here, it queued but not visible yet in DB
    return jsonify({"status":"pending","message":"Timed out waiting for consumer", "roman": roman, "error": str(last_err) if last_err else None}), 202

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
