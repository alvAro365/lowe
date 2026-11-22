# Lowes vedskog

Et iOS-spill for Lowe (6 år) der man hugger ved, stabler den og hjelper skogsdyr med å holde varmen.
Ingen tekst, ingen tap, ingen reklame, ingen kjøp og ingen internett.

Design: <https://claude.ai/artifact/XByWwLwZF7v1ssJwr5mtpD>

## Kjøre spillet

1. Åpne `Lowe.xcodeproj` i Xcode 16 eller nyere.
2. Velg målet **Lowe**, gå til *Signing & Capabilities* og velg teamet ditt.
   Bytt `com.alvaro365.lowe` hvis bundle-ID-en er tatt.
3. Velg en iPhone, en iPad eller en simulator, og trykk ▶︎.

Spillet kjører i liggende format på både iPhone og iPad. Lyden følger lydløsbryteren.

Foreldremenyen åpnes ved å holde pauseknappen oppe til venstre inne i 3 sekunder.

## Slik er koden bygd opp

| Fil | Hva den gjør |
| --- | --- |
| `Lowe/LoweApp.swift` | Starter appen og viser spillscenen i SwiftUI |
| `Lowe/GameScene.swift` | Selve spillet: hugging, vedstabel, overraskelser, feiring og levering |
| `Lowe/Characters.swift` | Lowe med øksa, og kubben som sprekker |
| `Lowe/Art.swift` | Farger, bakgrunn, hoggestabben, vedstykker, ekornet og kongla |
| `Lowe/Animals.swift` | De fem dyrene som kommer på besøk, og hyttene deres |
| `Lowe/Village.swift` | Landsbyen om natta, der en ny hytte lyser opp etter hver levering |
| `Lowe/HUD.swift` | Pauseknappen med foreldrelås, foreldremenyen og stjernekrukka |
| `Lowe/SavedGame.swift` | Husker stabelen, hyttene og stjernene mellom gangene |
| `Lowe/Feedback.swift` | Lyd og vibrasjon |
| `tools/make_assets.py` | Lager lydene og app-ikonet (`python3 tools/make_assets.py`) |

Figurene tegnes i de samme koordinatene som designtavlene (1180 × 820, y nedover),
så former kan kopieres rett fra designet.

## 3D-forsøket

`Lowe3D` er en egen liten app i samme prosjekt, for å kjenne på hvordan spillet blir i 3D.
Velg skjemaet **Lowe3D** øverst i Xcode og kjør. Den trenger iOS 18.

- Tommelen på venstre halvdel av skjermen er en spak: dra, så går Lowe den veien.
- Dra på høyre halvdel for å snu kameraet rundt Lowe.
- Den store turkise knappen (eller et kort trykk til høyre) hugger. Står han nær stabben, går han bort og hugger kubben. Tre hogg deler den.
- Den hvite knappen med pil hopper.
- Vedstykkene flyr til stabelen. Når den er full, blir det konfetti og den tømmes.

| Fil | Hva den gjør |
| --- | --- |
| `Lowe3D/Lowe3DApp.swift` | Starter appen og viser 3D-skogen |
| `Lowe3D/Forest.swift` | Skogen, kameraet, gåing, hopping, hugging og vedstabelen |
| `Lowe3D/Controls.swift` | Spaken, kameradraget og knappene for å hugge og hoppe |
| `Lowe3D/LoweFigure.swift` | Lowe bygd av enkle 3D-former, med gange og hogg |
| `Lowe3D/Models.swift` | Farger og byggeklosser: trær, stabbe, kubbe og vedstykker |
| `Lowe3D/Sound.swift` | Lyd og vibrasjon (samme lyder som 2D-spillet) |
