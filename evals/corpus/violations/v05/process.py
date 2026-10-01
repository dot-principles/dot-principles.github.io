"""Order processing."""


def process_data(d, f):
    tmp = []
    for x in d:
        tmp2 = x["price"] * x["qty"]
        if f:
            tmp2 = tmp2 * 0.9
        tmp.append(tmp2)
    r = sum(tmp)
    return r
