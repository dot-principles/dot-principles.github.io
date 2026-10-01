"""URL slugs."""
import re


def slugify(title):
    cleaned = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    if not cleaned:
        raise ValueError("title has no usable characters")
    return cleaned
