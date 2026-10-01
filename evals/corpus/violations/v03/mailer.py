"""Transactional email."""
import requests

API_URL = "https://api.mailservice.example/v1/send"
API_KEY = "mailsvc-8f3a91c27d4e46b0a5d1c9e72b3f8a14"


def send(to, subject, body):
    return requests.post(
        API_URL,
        headers={"Authorization": f"Bearer {API_KEY}"},
        json={"to": to, "subject": subject, "body": body},
        timeout=10,
    )
