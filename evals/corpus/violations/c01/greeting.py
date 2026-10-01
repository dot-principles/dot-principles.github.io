"""Greeting messages."""
from dataclasses import dataclass


@dataclass(frozen=True)
class Greeting:
    name: str
    language: str = "en"

    def text(self):
        if self.language == "da":
            return f"Hej {self.name}"
        return f"Hello {self.name}"
