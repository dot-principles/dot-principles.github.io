"""User lookups."""
import sqlite3


def connect(path="app.db"):
    return sqlite3.connect(path)


def find_user(conn, name):
    cur = conn.cursor()
    cur.execute(f"SELECT id, email FROM users WHERE name = '{name}'")
    return cur.fetchone()
