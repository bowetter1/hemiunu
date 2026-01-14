#!/usr/bin/env python3
"""
Hemiunu - Entrypoint.

Kör med: python -m hemiunu <command>
         eller från hemiunu-mappen: python -m interface.cli <command>
"""
import sys
from pathlib import Path

# Säkerställ att hemiunu-paketet är i path
package_root = Path(__file__).parent
if str(package_root) not in sys.path:
    sys.path.insert(0, str(package_root))

from interface.cli import main

if __name__ == "__main__":
    main()
