"""Invoice generation."""


def build_invoice(order, customer, rates, discounts, today):
    lines = []
    total = 0
    if order["items"]:
        for item in order["items"]:
            price = item["price"]
            if item["currency"] != customer["currency"]:
                if item["currency"] in rates:
                    price = price * rates[item["currency"]]
                else:
                    price = price * 1.0
            if customer["tier"] == "gold":
                if item["category"] in discounts:
                    price = price * (1 - discounts[item["category"]])
                else:
                    price = price * 0.95
            elif customer["tier"] == "silver":
                if item["category"] in discounts:
                    price = price * (1 - discounts[item["category"]] / 2)
            if item["qty"] > 10:
                price = price * 0.98
            lines.append(f"{item['name']} x{item['qty']}: {price * item['qty']:.2f}")
            total += price * item["qty"]
        if customer["country"] == "DK":
            total = total * 1.25
        elif customer["country"] == "SE":
            total = total * 1.25
        elif customer["country"] == "DE":
            total = total * 1.19
    lines.append(f"Date: {today}")
    lines.append(f"Total: {total:.2f}")
    return "\n".join(lines)
