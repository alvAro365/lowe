# Lowes vedskog

Et 3D-spill for iOS, laget for Lowe (6 år). Lowe går rundt i en snødekt skog, hugger ved og stabler den.
Ingen tekst, ingen tap, ingen reklame, ingen kjøp og ingen internett.

## Kjøre spillet

1. Åpne `Lowe.xcodeproj` i Xcode 16 eller nyere.
2. Velg målet **Lowe**, gå til *Signing & Capabilities* og velg teamet ditt.
   Bytt `com.alvaro365.lowe` hvis bundle-ID-en er tatt.
3. Velg en iPhone eller iPad med iOS 18 eller nyere, og trykk ▶︎.

Spillet kjører i liggende format på både iPhone og iPad. Lyden følger lydløsbryteren.

## Slik styrer man

- Tommelen på venstre halvdel av skjermen er en spak: dra, så går Lowe den veien.
- Dra på høyre halvdel for å snu kameraet rundt Lowe.
- Den store turkise knappen (eller et kort trykk til høyre) hugger. Står han nær stabben, går han bort og hugger kubben. Tre hogg deler den.
- Den hvite knappen med pil hopper.
- Vedstykkene flyr til stabelen. Ved stabelen venter et dyr fra skogen.
- Når stabelen er full, blir det konfetti, veden flyr til dyret, og det går hjem med den.
  Så kommer neste dyr: pinnsvinet, reven, elgen, bjørnen og ugla, og så forfra. Spillet husker hvem som står for tur.

## Slik er koden bygd opp

Spillet bruker RealityKit. Alt er bygd av enkle former (bokser, kuler, sylindre og kjegler), så det trengs ingen 3D-modeller.

| Fil | Hva den gjør |
| --- | --- |
| `Lowe/LoweApp.swift` | Starter appen og viser 3D-skogen |
| `Lowe/Forest.swift` | Skogen, kameraet, gåing, hopping, hugging og vedstabelen |
| `Lowe/Controls.swift` | Spaken, kameradraget og knappene for å hugge og hoppe |
| `Lowe/LoweFigure.swift` | Lowe bygd av enkle 3D-former, med gange og hogg |
| `Lowe/Animals.swift` | De fem dyrene, bygd av enkle former i fargene fra 2D-designet |
| `Lowe/Models.swift` | Farger og byggeklosser: trær, stabbe, kubbe og vedstykker |
| `Lowe/Sound.swift` | Lyd og vibrasjon |
| `tools/make_assets.py` | Lager lydene og app-ikonet (`python3 tools/make_assets.py`) |

Det første 2D-spillet (dyrene, landsbyen om natta og stjernekrukka) ligger i git-historikken,
senest i commit `aa9fc8d`.
