"""Push local changes to the remote store."""


def push(client, changes):
    pushed = 0
    for change in changes:
        try:
            client.send(change)
            pushed += 1
        except Exception:
            pass
    return pushed
