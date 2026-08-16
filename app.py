from flask import Flask, render_template, request, jsonify, session, redirect, url_for
import mysql.connector
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "cecms-secret-key-2026")

def get_db():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASS", ""),
        database=os.getenv("DB_NAME", "cecms_db")
    )


def login_required_check():
    if "user_name" not in session:
        return jsonify(error="Unauthorized"), 401
    return None

@app.route("/")
def index():
    if "user_name" not in session:
        return redirect(url_for("login"))
    return render_template("index.html", user_name=session["user_name"])

@app.route("/login", methods=["GET", "POST"])
def login():
    if "user_name" in session:
        return redirect(url_for("index"))
    error = None
    email_value = ""
    if request.method == "POST":
        email = request.form.get("email", "").strip()
        password = request.form.get("password", "").strip()
        email_value = email
        try:
            db = get_db()
            cur = db.cursor(dictionary=True)
            # NOTE: PasswordHash stores plaintext for demo — production would use bcrypt/Argon2
            cur.execute(
                "SELECT Name, Email FROM User WHERE Email = %s AND PasswordHash = %s",
                (email, password)
            )
            user = cur.fetchone()
            db.close()
            if user:
                session["user_name"] = user["Name"]
                session["user_email"] = user["Email"]
                return redirect(url_for("index"))
            else:
                error = "Invalid email or password. Please try again."
        except Exception as e:
            error = "Database error: " + str(e)
    return render_template("login.html", error=error, email_value=email_value)

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))

@app.route("/api/stats")
def stats():
    guard = login_required_check()
    if guard: return guard
    db = get_db(); cur = db.cursor(dictionary=True)
    cur.execute("SELECT COALESCE(SUM(UnitsConsumed),0) AS total FROM EnergyReading")
    total_kwh = float(cur.fetchone()["total"])
    cur.execute("SELECT COUNT(*) AS cnt FROM EnergyMeter WHERE Status='Active'")
    active_meters = cur.fetchone()["cnt"]
    cur.execute("SELECT COUNT(*) AS cnt FROM EnergyMeter")
    total_meters = cur.fetchone()["cnt"]
    cur.execute("SELECT COUNT(*) AS cnt FROM Alert")
    open_alerts = cur.fetchone()["cnt"]
    cur.execute("SELECT COALESCE(MAX(PeakLoad),0) AS peak FROM EnergyReading")
    peak = float(cur.fetchone()["peak"])
    db.close()
    return jsonify(total_kwh=round(total_kwh,2), active_meters=active_meters,
                   total_meters=total_meters, open_alerts=open_alerts, peak_kw=round(peak,2))

@app.route("/api/consumption_by_building")
def consumption_by_building():
    db = get_db(); cur = db.cursor(dictionary=True)
    cur.execute("""
        SELECT b.BuildingName AS name, COALESCE(SUM(r.UnitsConsumed),0) AS total
        FROM Building b
        LEFT JOIN EnergyMeter m ON b.BuildingID = m.BuildingID
        LEFT JOIN EnergyReading r ON m.MeterID = r.MeterID
        GROUP BY b.BuildingID, b.BuildingName ORDER BY total DESC
    """)
    rows = cur.fetchall()
    for r in rows: r["total"] = float(r["total"])
    db.close()
    return jsonify(rows)

@app.route("/api/buildings")
def buildings():
    db = get_db(); cur = db.cursor(dictionary=True)
    cur.execute("""
        SELECT b.BuildingID, b.BuildingName, b.Location, b.FloorCount, b.TotalArea,
               COUNT(m.MeterID) AS meter_count,
               SUM(CASE WHEN m.Status='Active' THEN 1 ELSE 0 END) AS active_meters
        FROM Building b
        LEFT JOIN EnergyMeter m ON b.BuildingID = m.BuildingID
        GROUP BY b.BuildingID ORDER BY b.BuildingID
    """)
    rows = cur.fetchall()
    for r in rows: r["TotalArea"] = float(r["TotalArea"])
    db.close()
    return jsonify(rows)

@app.route("/api/logs")
def logs():
    db = get_db(); cur = db.cursor(dictionary=True)
    cur.execute("""
        SELECT r.ReadingID, b.BuildingName AS building, s.SourceType AS source,
               m.MeterType, r.ReadingDate, r.UnitsConsumed, r.PeakLoad
        FROM EnergyReading r
        JOIN EnergyMeter m ON r.MeterID = m.MeterID
        JOIN Building b ON m.BuildingID = b.BuildingID
        JOIN EnergySource s ON r.SourceID = s.SourceID
        ORDER BY r.ReadingDate DESC LIMIT 50
    """)
    rows = cur.fetchall()
    for r in rows:
        r["ReadingDate"] = str(r["ReadingDate"])
        r["UnitsConsumed"] = float(r["UnitsConsumed"])
        r["PeakLoad"] = float(r["PeakLoad"])
    db.close()
    return jsonify(rows)

@app.route("/api/alerts")
def alerts():
    db = get_db(); cur = db.cursor(dictionary=True)
    cur.execute("""
        SELECT a.AlertID, b.BuildingName AS building, m.MeterType,
               a.AlertDate, a.AlertType, a.Threshold, a.ActualValue
        FROM Alert a
        JOIN EnergyMeter m ON a.MeterID = m.MeterID
        JOIN Building b ON m.BuildingID = b.BuildingID
        ORDER BY a.AlertDate DESC
    """)
    rows = cur.fetchall()
    for r in rows:
        r["AlertDate"] = str(r["AlertDate"])
        r["Threshold"] = float(r["Threshold"])
        r["ActualValue"] = float(r["ActualValue"])
    db.close()
    return jsonify(rows)

@app.route("/api/logs", methods=["POST"])
def add_log():
    data = request.json
    db = get_db(); cur = db.cursor()
    cur.execute("""
        INSERT INTO EnergyReading (MeterID, SourceID, ReadingDate, UnitsConsumed, PeakLoad)
        VALUES (%s, %s, %s, %s, %s)
    """, (data["meter_id"], data["source_id"], data["reading_date"],
          data["units_consumed"], data.get("peak_load", 0)))
    db.commit(); new_id = cur.lastrowid; db.close()
    return jsonify(success=True, reading_id=new_id)

@app.route("/api/meters")
def meters():
    db = get_db(); cur = db.cursor(dictionary=True)
    cur.execute("""
        SELECT m.MeterID, m.MeterType, b.BuildingName
        FROM EnergyMeter m JOIN Building b ON m.BuildingID = b.BuildingID
        WHERE m.Status='Active' ORDER BY b.BuildingName
    """)
    rows = cur.fetchall(); db.close()
    return jsonify(rows)

@app.route("/api/sources")
def sources():
    db = get_db(); cur = db.cursor(dictionary=True)
    cur.execute("SELECT SourceID, SourceType, UnitCostPerKWh FROM EnergySource")
    rows = cur.fetchall()
    for r in rows: r["UnitCostPerKWh"] = float(r["UnitCostPerKWh"])
    db.close()
    return jsonify(rows)

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))