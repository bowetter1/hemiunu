# Apex

> Världens första fungerande AI-team

---

## Vad är Apex?

Ett ramverk för att få AI-agenter att samarbeta och leverera mjukvaruprojekt. En AI tar rollen som chef och bygger sitt team - med garanti att leverera 100%.

---

## Kärnteamet (7 roller)

| Roll | Ansvar | Output | Kritisk för |
|------|--------|--------|-------------|
| [Chef](chef/ONBOARDING.md) | Koordinerar, beslutar, levererar | `playbook.md` | Allt |
| [AD](ad/ONBOARDING.md) | Surfar inspiration, design, visuell riktning | `design_system.md` | Alla ser design |
| [Architect](architect/ONBOARDING.md) | Systemdesign, tekniska beslut, struktur | `architecture.md` | Rätt grund |
| [Coder](coder/ONBOARDING.md) | Implementation (1-4 parallella) | Kod | Bygga |
| [Tester](tester/ONBOARDING.md) | Verifierar 100%, hittar buggar | `tests.md` | Kvalitet |
| [Reviewer](reviewer/ONBOARDING.md) | Kodgranskning, säkerhet | `review.md` | Kodkvalitet |
| [DevOps](devops/ONBOARDING.md) | Deploy, infra, verifiera live | `infra.md` | Sista milen |

---

## Flödet

```
1. AD        → Surfar, inspiration, sätter visuell riktning
2. Architect → Struktur baserat på design
3. Coder     → Bygger (1-4 parallellt)
4. Tester    → "Funkar det 100%?"
   ↓ NEJ → tillbaka till Coder
   ↓ JA  → fortsätt
5. Reviewer  → "Är koden OK?"
   ↓ NEJ → tillbaka till Coder
   ↓ JA  → fortsätt
6. DevOps    → Deploy + verifiera LIVE
7. Chef      → Leverera
```

**Feedback-loopen är nyckeln.** Ingen genväg förbi Tester och Reviewer.

---

## Varför dessa roller?

| Roll | Varför kritisk |
|------|----------------|
| **AD** | Alla kan se design - få kan läsa kod |
| **Tester** | Vanlig AI lämnar över för tidigt. Chef levererar 100%. |
| **DevOps** | Kod som funkar lokalt ≠ kod som funkar live |

---

## Specs

- [specs/TEMPLATE.md](specs/TEMPLATE.md) - Mall för uppgifter

## Referens

- [reference/vision.md](reference/vision.md) - Varför vi bygger detta
- [reference/api_contract.md](reference/api_contract.md) - MCP-verktyg
