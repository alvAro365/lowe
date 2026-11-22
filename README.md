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

- Spaken står fast nede til venstre: dra den, så går Lowe den veien.
- Dra hvor som helst ellers på skjermen for å snu kameraet rundt Lowe.
- Den store turkise knappen hugger. Står han nær stabben, går han bort og hugger kubben. Tre hogg deler den.
- Den hvite knappen med pil hopper.
- Står Lowe ved et grantre, hugger øksa i treet. Fire hogg, så faller det, og stokken blir liggende i snøen.
  Stubben blir stående, og etter en stund vokser et nytt tre opp.
- **Trykk på tingen** for å bruke den, som i Minecraft. Lowe går bort til den hvis den er et stykke unna.
  Rundt hver ting ligger en stor, usynlig boks, og treffer man bare snøen, velges den nærmeste tingen innen en meter.
  Går Lowe rett over en stein, plukker han den opp av seg selv.
  - Trykk på en stokk, så løfter Lowe den opp på skuldrene. Han kan bære opptil tre stokker,
    og går litt saktere jo flere han bærer.
  - Trykk på stabben, så legges alle stokkene han bærer i køen der.
  - Trykk i snøen mens han bærer, så går han dit og legger den øverste stokken der.
  - Trykk på Lowe selv, så legger han fra seg den øverste stokken (eller går av akebrettet).
  - Trykk på stabben uten stokker, så hugger han kubben. Trykk på bålplassen, så tenner han bål.
  - Et trykk i snøen når han ikke bærer noe, hugger.
- Skogen er stor, med stier ut fra lysningen. Ti kongler ligger gjemt rundt omkring, og raden med små kongler
  oppe til venstre viser hvor mange Lowe har funnet: de brune er funnet, de lyse venter. Ekorn piler av gårde når han kommer nær, og det snør.
- Vedstykkene flyr til stabelen. Ved stabelen venter et dyr fra skogen.
- Når stabelen er full, blir det konfetti, veden flyr til dyret, og det går hjem med den.
  Så kommer neste dyr: pinnsvinet, reven, elgen, bjørnen og ugla, og så forfra. Spillet husker hvem som står for tur.
- **Bygge (som i Minecraft):** Den lille knappen over øksa slår byggingen på. Klossene står i et rutenett i alle retninger.
  - Trykk på skjermen der klossen skal stå: på bakken, eller på en side av en annen kloss (oppå, ved siden av eller under en kant).
  - Hold fingeren på en kloss, så tas den bort. Blir fingeren liggende, tas neste også.
  - Den store knappen setter en kloss der den turkise skyggen viser, rett foran Lowe. Står han på bakken,
    blir det et tårn; står han oppå klossene, blir det en bro ut.
  - Raden nederst velger kloss: lys planke, mørk stokk, stein, turkis og svart.
  - Klossene kan stå opp til tolv høyt. Lowe kan hoppe opp på dem, gå oppå dem og falle ned igjen.
    Han kan også sette en kloss under seg mens han hopper, og bygge seg et tårn å stå på.
  - Med byggingen av hugger øksa bort klossen foran ham.
- Hver kloss koster én ved. Telleren under konglene viser hvor mye ved Lowe har (12 fra start).
  En kløyvd kubbe gir 2, et felt tre gir 4 og en revet kloss gir 1 tilbake. Det som er bygd, huskes.
- **Ryggsekken:** Knappen med sekken oppe til høyre åpner ryggsekken. Den viser bare bilder og tall:
  - Øverst det Lowe har samlet: ved, kongler (hver kongle han finner) og steiner. Steiner ligger rundt i skogen;
    trykk på en stein, så plukker han den opp. En ny stein dukker opp på samme sted etter et minutt.
  - I midten det han kan lage. Kortene med turkis kant har han nok til; trykk på kortet, så lages tingen.
    - Akebrett: 4 ved og 1 stein
    - Lykt: 1 ved og 2 steiner
    - Fuglekasse: 3 ved og 2 kongler
  - Nederst tingene han har laget. Trykk på en, så setter han den ned foran seg i skogen.
- Lykta lyser varmt, mest om natta. På fuglekassa sitter en liten fugl som vipper og tar en runde nå og da.
  Trykk på lykta eller fuglekassa, så går den tilbake i sekken.
- Trykk på akebrettet, så stiller Lowe seg på det og glir nesten dobbelt så fort. Trykk på Lowe for å gå av,
  så går brettet tilbake i sekken. Det som er laget og satt ut, huskes.
- **Dag og natt:** En hel dag og natt tar seks minutter. Etter omtrent tre og et halvt minutt kommer skumringen,
  og natta er blå med stjerner, måne og nordlys. Ved bålplassen i lysningen trykker man på bålplassen, så tenner Lowe bål.
  Bålet brenner natta gjennom og slukner når det blir lyst.

## Slik er koden bygd opp

Spillet bruker RealityKit. Alt er bygd av enkle former (bokser, kuler, sylindre og kjegler), så det trengs ingen 3D-modeller.

| Fil | Hva den gjør |
| --- | --- |
| `Lowe/LoweApp.swift` | Starter appen og viser 3D-skogen |
| `Lowe/Forest.swift` | Skogen, kameraet, gåing, hopping, hugging og vedstabelen |
| `Lowe/Controls.swift` | Spaken, kameradraget og knappene for å hugge og hoppe |
| `Lowe/LoweFigure.swift` | Lowe bygd av enkle 3D-former, med gange og hogg |
| `Lowe/Woods.swift` | Den store skogen: stier, trær som kan felles, stokker som kan bæres, kongler, ekorn og snø |
| `Lowe/Building.swift` | Byggeklossene: 3D-rutenett, sikte fra kameraet, klosstyper, klatring og lagring |
| `Lowe/Crafting.swift` | Ryggsekken, oppskriftene, tingene Lowe lager (akebrett, lykt, fuglekasse) og bildene til dem |
| `Lowe/Sky.swift` | Dag og natt, stjerner, måne, nordlys og bålet |
| `Lowe/Animals.swift` | De fem dyrene, bygd av enkle former i fargene fra 2D-designet |
| `Lowe/Models.swift` | Farger og byggeklosser: trær, stabbe, kubbe og vedstykker |
| `Lowe/Sound.swift` | Lyd og vibrasjon |
| `tools/make_assets.py` | Lager lydene og app-ikonet (`python3 tools/make_assets.py`) |

Det første 2D-spillet (dyrene, landsbyen om natta og stjernekrukka) ligger i git-historikken,
senest i commit `aa9fc8d`.
