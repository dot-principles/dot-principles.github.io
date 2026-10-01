"""Account status checks."""


def is_active(account):
    status = account.get("status")
    return status is "active"


def active_accounts(accounts):
    return [a for a in accounts if is_active(a)]
