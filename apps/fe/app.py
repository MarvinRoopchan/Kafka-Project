from flask import Flask, render_template, request
import requests, os

app = Flask(__name__, template_folder="templates")

API_URL = os.getenv("API_URL", "http://api:5000")
REQ_TIMEOUT = float(os.getenv("REQ_TIMEOUT", "10"))  # seconds

@app.get("/")
def index():
    return render_template("index.html")

@app.get("/healthz")
def health():
    return "ok", 200

@app.post("/submit")
def submit():
    user_input = request.form.get("user_input", "").strip()
    if not user_input:
        return render_template("result.html", result={"status":"error","message":"No input"}), 400

    try:
        resp = requests.post(
            f"{API_URL}/process",
            json={"data": user_input},
            timeout=REQ_TIMEOUT
        )
        data = resp.json()
        return render_template("result.html", result=data), resp.status_code
    except Exception as e:
        return render_template("result.html", result={"status":"error","message":f"Network error: {e}"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
