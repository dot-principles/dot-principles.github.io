"""Session expiry. Expiry timestamps are stored as UTC."""
from datetime import datetime, timedelta, timezone

SESSION_TTL = timedelta(hours=8)


def new_expiry():
    return datetime.now(timezone.utc) + SESSION_TTL


def is_expired(expires_at):
    return datetime.now() > expires_at.replace(tzinfo=None)
