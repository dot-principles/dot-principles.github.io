"""Statistics for the dashboard."""


def average(values):
    """Mean of values; 0.0 when there are no values."""
    total = 0.0
    for v in values:
        total += v
    return total / len(values)


def spread(values):
    return max(values) - min(values) if values else 0.0
