"""Report export."""


def export_report(rows, path):
    out = open(path, "w")
    out.write("id,total\n")
    for row in rows:
        if row["total"] < 0:
            return False
        out.write(f"{row['id']},{row['total']}\n")
    out.close()
    return True
