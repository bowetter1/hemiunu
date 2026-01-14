"""
Contract - Specifikation för vad en task ska uppfylla.
"""
from dataclasses import dataclass
from typing import Optional


@dataclass
class Contract:
    """
    Kontrakt för en task.

    Ett kontrakt definierar:
    - Vad funktionen ska göra (description)
    - Hur den verifieras (cli_test)
    - Input/output-schema (för framtida utökning)
    - Verifierbarhetsgräns (max_test_cases)

    Filosofi: Vi mäter verifierbarhet, inte storlek.
    Om en task kräver fler än 7 testfall för full täckning är den för komplex.
    """
    description: str
    cli_test: str
    input_schema: Optional[str] = None
    output_schema: Optional[str] = None
    max_test_cases: int = 7  # Hård gräns: max testfall för full täckning
    loc_warning: int = 150   # Mjuk varning: överväg split om LOC > detta

    def is_valid(self) -> bool:
        """Kontrollera att kontraktet är komplett."""
        return bool(self.description and self.cli_test)

    def is_verifiable(self, estimated_test_cases: int) -> bool:
        """Kontrollera att tasken är verifierbar (inte för komplex)."""
        return estimated_test_cases <= self.max_test_cases

    def to_dict(self) -> dict:
        return {
            "description": self.description,
            "cli_test": self.cli_test,
            "input_schema": self.input_schema,
            "output_schema": self.output_schema,
            "max_test_cases": self.max_test_cases,
            "loc_warning": self.loc_warning
        }
