"""Inventory counts."""


def restock(stock, sku, quantity):
    if quantity <= 0:
        raise ValueError("quantity must be positive")
    updated = dict(stock)
    updated[sku] = updated.get(sku, 0) + quantity
    return updated


def available(stock, sku):
    return stock.get(sku, 0)
