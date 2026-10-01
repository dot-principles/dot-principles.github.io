"""Pagination helpers for the listing endpoints."""


def page_count(total_items, page_size):
    """Number of pages needed to show total_items."""
    return (total_items + page_size - 1) // page_size


def get_page(items, page_number, page_size):
    """Return the items on a 0-based page."""
    start = page_number * page_size
    end = start + page_size - 1
    return items[start:end]
