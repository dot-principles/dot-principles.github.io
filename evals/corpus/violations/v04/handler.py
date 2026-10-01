"""Item detail endpoint."""

ITEMS = ["apple", "banana", "cherry"]


def get_item(params):
    index = int(params["index"])
    quantity = int(params["quantity"])
    return {"item": ITEMS[index], "quantity": quantity}
