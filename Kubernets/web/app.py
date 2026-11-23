import os
import secrets
import time

import psycopg
from flask import Flask, abort, redirect, render_template_string, request, session

app = Flask(__name__)
app.secret_key = os.environ["APP_SECRET_KEY"]
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024

def connect():
    return psycopg.connect(
        host=os.environ["DB_HOST"], port=os.environ["DB_PORT"],
        dbname=os.environ["DB_NAME"], user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"], connect_timeout=3,
    )


# PostgreSQL may start after the website pod, so retry the connection.
for attempt in range(60):
    try:
        with connect() as db:
            db.execute("""CREATE TABLE IF NOT EXISTS messages (
                id SERIAL PRIMARY KEY,
                name VARCHAR(80) NOT NULL,
                message VARCHAR(500) NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )""")
        break
    except psycopg.OperationalError:
        if attempt == 59:
            raise
        time.sleep(2)


PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Krishna · Database practice</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f5f6f1;color:#243c30;font:16px system-ui}
main{max-width:800px;margin:50px auto;padding:24px}small{letter-spacing:.1em;color:#55715e}
h1{font-size:clamp(32px,6vw,48px);margin:12px 0}p{line-height:1.6}.card{background:white;border:1px solid #dce4da;border-radius:16px;padding:24px;margin:20px 0}
label{display:block;font-weight:600;margin:14px 0 6px}input,textarea{font:inherit;width:100%;padding:12px;border:1px solid #bacaba;border-radius:8px}button{font:inherit;cursor:pointer;background:#28573e;color:white;border:0;border-radius:8px;padding:11px 18px;margin-top:12px}.delete{background:#f8e7e4;color:#8b3026;padding:7px 12px}.message{white-space:pre-wrap;overflow-wrap:anywhere}time{font-size:13px;color:#667568}.flow{font-size:14px;color:#55715e}
</style></head><body><main>
<small>LOCAL KUBERNETES LAB</small><h1>Your first database app.</h1>
<p>Add a message and refresh the page. Your message is stored in PostgreSQL, outside the website pod.</p>
<p class="flow">Browser → website Service → Flask pod → postgres Service → PostgreSQL</p>
<form class="card" method="post" action="/messages">
<input type="hidden" name="token" value="{{ token }}">
<label for="name">Your name</label><input id="name" name="name" maxlength="80" required>
<label for="message">Message</label><textarea id="message" name="message" rows="3" maxlength="500" required></textarea>
<button>Save to database</button></form>
<h2>Saved messages</h2>
{% for row in rows %}<article class="card"><strong>{{ row[1] }}</strong>
<p class="message">{{ row[2] }}</p><time>Row #{{ row[0] }} · {{ row[3].strftime('%d %b %Y %H:%M UTC') }}</time>
<form method="post" action="/messages/{{ row[0] }}/delete"><input type="hidden" name="token" value="{{ token }}"><button class="delete">Delete</button></form></article>
{% else %}<div class="card">No messages yet. Add the first one above.</div>{% endfor %}
<p class="flow">Local practice app · showing the latest 100 messages · no sign-in</p>
</main></body></html>"""


def check_token():
    token = session.get("token")
    if not token or not secrets.compare_digest(token, request.form.get("token", "")):
        abort(400, "Refresh the page and try again.")


@app.get("/")
def home():
    session.setdefault("token", secrets.token_hex(24))
    with connect() as db:
        rows = db.execute("SELECT id, name, message, created_at FROM messages ORDER BY id DESC LIMIT 100").fetchall()
    return render_template_string(PAGE, rows=rows, token=session["token"])


@app.post("/messages")
def create_message():
    check_token()
    name = request.form.get("name", "").strip()
    message = request.form.get("message", "").strip()
    if not (1 <= len(name) <= 80 and 1 <= len(message) <= 500):
        abort(400, "Enter a name (1–80 characters) and a message (1–500 characters).")
    with connect() as db:
        db.execute("INSERT INTO messages (name, message) VALUES (%s, %s)", (name, message))
    return redirect("/", code=303)


@app.post("/messages/<int:message_id>/delete")
def delete_message(message_id):
    check_token()
    with connect() as db:
        db.execute("DELETE FROM messages WHERE id = %s", (message_id,))
    return redirect("/", code=303)


@app.get("/health")
def health():
    with connect() as db:
        db.execute("SELECT 1")
    return {"status": "ok", "database": "connected"}
