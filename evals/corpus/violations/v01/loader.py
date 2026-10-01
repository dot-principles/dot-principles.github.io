"""Load the service configuration."""
import json


def load_config(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        return None


def start(path):
    config = load_config(path)
    port = config.get("port", 8080) if config else 8080
    print(f"starting on {port}")
    return port
