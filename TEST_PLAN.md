# TEST_PLAN v2

## Scope and focus
- Fokus: WebSocket-events, UI-interaktioner, state-synkronisering.
- Klient: v2-UI i `src/frontend` (rendering, hover/ghost, debug clear, animationer).
- Server: FastAPI WebSocket + persistence i `src/backend`.

## Features to test + test cases

### F1: WebSocket connection, init, state_sync
- TC-WS-01 (Critical): Start klient -> status "Connecting..." -> "Connected"; klient skickar `init` med `user_id`; server svarar `state_sync`; HUD uppdateras (blocks, stone, players).
- TC-WS-02 (High): Stang ner socket och ateranslut -> ny `state_sync` override state utan dubbletter.
- TC-WS-03 (High): Mottag `state_sync` med pyramid + stats + user_resources -> gameState reset och ersatts korrekt.
- Edge cases:
  - Ogiltig JSON i server->client message -> klient ignorerar utan crash.
  - `state_sync` saknar `user_resources` (t.ex. debug clear) -> HUD visar 0 stone, inga JS-fel.
  - `init` saknar/har tom `user_id` -> server anvander "unknown" men svarar `state_sync`.

### F2: Broadcast events och multi-client synk
- TC-WS-04 (Critical): Klient A placerar block -> server broadcast `block_placed`; A och B ser nytt block och pyramid storlek +1.
- TC-WS-05 (High): Klient A placerar block -> A far `state_sync` med reducerad stone; B far inte A:s resources.
- TC-WS-06 (High): Klient B ansluter -> `online_players` i state_sync matchar antal aktiva kopplingar.
- Edge cases:
  - Två klienter placerar samtidigt -> inga dubbletter/korrupt state.
  - Online player count uppdateras bara vid state_sync; verifiera korrekthet efter events som triggar sync.

### F3: Mine stone (resource update)
- TC-RES-01 (High): Klick "Mine Stone" -> skickar `mine_stone`; server okar stone och skickar `state_sync`; UI stone +1.
- TC-RES-02 (High): Ny user utan sparad profil -> startar med 10 stone; mining ger 11.
- Edge cases:
  - Spam-klick -> flera `mine_stone`; inga negativa eller NaN; UI halles konsekvent.

### F4: Place block (validation, resources, events)
- TC-PLC-01 (Critical): Med stone > 0 -> `place_block` valideras; `block_placed` broadcast; placerarens stone -1.
- TC-PLC-02 (Critical): Ogiltig placering (saknar support eller utanfors bas) -> server skickar `error`; UI visar error-notice + red flash; inga state-forandringar.
- TC-PLC-03 (High): Stone = 0 -> place button disabled; server nekar placering; stone blir inte negativ.
- Edge cases:
  - Placering pa z>0 utan full support -> alltid nekas.
  - Placering med icke-integer koordinater -> server nekar.
  - Placering pa bas utanfors abs(x|y) > 100 -> server nekar.

### F5: Placement UX (hover/ghost + auto)
- TC-UI-01 (High): Hover over giltig cell -> ghost block gron; klick pa canvas -> placerar block med exakta coords.
- TC-UI-02 (High): Hover over ogiltig cell -> ghost block rod; klick gor ingenting.
- TC-UI-03 (Medium): Klick "Place Block" -> auto-placement (supported eller base) anvands; block placeras om giltigt.
- Edge cases:
  - Mus utanfors GRID_SIZE -> ghost rensas.
  - Full bas inom GRID_SIZE -> auto-placement hittar nasta lediga i spiral (max 100).

### F6: Milestone events + HUD
- TC-MLS-01 (High): Nar total blocks nar 100, 200, ... -> `milestone-event` broadcast; UI visar toast 2.5s; progress nollas.
- TC-MLS-02 (Medium): Reconnect -> milestone progress beraknas fran state_sync.
- Edge cases:
  - Milestone-event kommer utan state_sync -> UI anvander payload `total_blocks`.

### F7: Debug clear all
- TC-DBG-01 (Medium): Klick debug clear -> confirm; `debug_clear_all` skickas; server rensar DB + memory; alla klienter far `state_sync` med tom pyramid.
- TC-DBG-02 (Medium): Cancel confirm -> inget skickas.
- Edge cases:
  - Clear samtidigt som place -> ingen korrupt state, pyramid tom efter clear.

### F8: Persistence (DB)
- TC-DB-01 (High): Placera block -> restart server -> block ar kvar efter `state_sync`.
- TC-DB-02 (High): Mine stone -> restart server -> user stone kvar.
- Edge cases:
  - Tom DB -> server seedar initiala block (2 st) -> HUD visar korrekt total.

### F9: UI status + error handling
- TC-UI-04 (Medium): Socket error/close -> status "Connection error"/"Disconnected".
- TC-UI-05 (Medium): `error` event -> status "Error: ..." i 2.5s -> atergar till "Connected" om socket oppen.
- Edge cases:
  - Flera errors i rad -> timer reset, sista message visas.

### F10: Rendering och animationer
- TC-REN-01 (Low): Nytt block -> entry animation; egna block highlight langre.
- TC-REN-02 (Low): Error -> röd flash overlay i 300ms.
- Edge cases:
  - Snabbt flera block -> animation map rensas efter duration, ingen minnesleck.

## Non-functional checks (lightweight)
- Prestanda (Medium): 500+ block renderas utan tydlig lagg; input fortsatt responsiv.
- Resilience (Medium): WebSocket reconnect efter kort outage -> state resync utan dubbletter.
