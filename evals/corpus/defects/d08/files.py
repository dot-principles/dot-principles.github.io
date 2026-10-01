"""Serve uploaded files from the upload directory."""
import os

UPLOAD_DIR = "/srv/uploads"


def read_upload(filename):
    path = os.path.join(UPLOAD_DIR, filename)
    with open(path, "rb") as fh:
        return fh.read()
