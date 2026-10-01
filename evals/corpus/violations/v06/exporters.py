"""Exporters for the three report formats."""


def export_users(rows):
    lines = []
    for row in rows:
        name = row["name"].strip().title()
        email = row["email"].strip().lower()
        lines.append(f"{name} <{email}>")
    return "\n".join(lines)


def export_customers(rows):
    lines = []
    for row in rows:
        name = row["name"].strip().title()
        email = row["email"].strip().lower()
        lines.append(f"{name} <{email}>")
    return "\n".join(lines)


def export_suppliers(rows):
    lines = []
    for row in rows:
        name = row["name"].strip().title()
        email = row["email"].strip().lower()
        lines.append(f"{name} <{email}>")
    return "\n".join(lines)
