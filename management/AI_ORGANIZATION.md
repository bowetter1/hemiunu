# AI Organization Guide

> **Denna fil har ersatts av ny dokumentationsstruktur.**

---

## Ny Struktur

| Läs detta | För att |
|-----------|---------|
| **[ONBOARDING.md](ONBOARDING.md)** | Komma igång snabbt (5 min) |
| **[CHEFS_HANDBOOK.md](CHEFS_HANDBOOK.md)** | Komplett referens |
| **[specs/TEMPLATE.md](specs/TEMPLATE.md)** | Skriva specs till workers |
| **[workers/WORKER_MATRIX.md](workers/WORKER_MATRIX.md)** | Välja rätt worker |

---

## Quick Start

```bash
# 1. Läs onboarding
cat management/ONBOARDING.md

# 2. Skapa spec för din feature
cp management/specs/TEMPLATE.md management/specs/min_feature.md
# Redigera filen...

# 3. Kör worker
codex exec "$(cat management/specs/min_feature.md)"
# eller
gemini -y "$(cat management/specs/min_feature.md)"
```

---

*Omdirigerad 2026-01-17 - Se [ONBOARDING.md](ONBOARDING.md)*
