"""Tagging for documents."""


def add_tag(tag, tags=[]):
    """Return the tag list with tag appended (once)."""
    if tag not in tags:
        tags.append(tag)
    return tags


def render(tags):
    return ", ".join(sorted(tags))
