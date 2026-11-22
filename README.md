# Loves vedskog

Et iOS-spill for Love (6 år) der man hugger ved, stabler den og hjelper skogsdyr med å holde varmen.
Ingen tekst, ingen tap, ingen reklame, ingen kjøp og ingen internett.

Design: <https://claude.ai/artifact/XByWwLwZF7v1ssJwr5mtpD>

## Kjøre spillet

1. Åpne `Lowe.xcodeproj` i Xcode 16 eller nyere.
2. Velg målet **Lowe**, gå til *Signing & Capabilities* og velg teamet ditt.
   Bytt `com.alvaro365.lowe` hvis bundle-ID-en er tatt.
3. Velg en iPhone, en iPad eller en simulator, og trykk ▶︎.

Spillet kjører i liggende format på både iPhone og iPad. Lyden følger lydløsbryteren.

## Slik er koden bygd opp

| Fil | Hva den gjør |
| --- | --- |
| `Lowe/LoweApp.swift` | Starter appen og viser spillscenen i SwiftUI |
| `Lowe/GameScene.swift` | Selve spillet: hugging, vedstabel, feiring og levering |
| `Lowe/Characters.swift` | Love med øksa, og kubben som sprekker |
| `Lowe/Art.swift` | Farger, bakgrunn, hoggestabben, vedstykker og pinnsvinet |
| `Lowe/Feedback.swift` | Lyd og vibrasjon |
| `tools/make_assets.py` | Lager lydene og app-ikonet (`python3 tools/make_assets.py`) |

Figurene tegnes i de samme koordinatene som designtavlene (1180 × 820, y nedover),
så former kan kopieres rett fra designet.
