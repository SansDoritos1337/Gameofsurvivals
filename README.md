# Gameofsurvivals — Godot 4

Polskojęzyczny prototyp top-down survival horroru inspirowany ogólnymi mechanikami gier skradankowych: potwory reagują na hałas, zbierasz zapasy i próbujesz dotrzeć do strefy ewakuacji. To autorski prototyp, nie kopia gry Roblox.

## Uruchomienie
Otwórz folder projektu w Godot 4.x i uruchom projekt lub scenę `scenes/Main.tscn`. Gra nie wymaga zewnętrznych assetów.

## Sterowanie
- **WASD** — ruch
- **Ctrl** — ciche skradanie
- **Shift** — bieg (głośny)
- **E** — zbieranie łupu / przytrzymaj w strefie wyjścia, by uciec
- **Lewy przycisk myszy** — strzał (bardzo głośny)
- **F1** — panel administratora
- **Esc** — zamknij panel administratora
- **R** — restart po zakończeniu gry

## Panel administratora
Panel F1 w tym lokalnym prototypie pozwala dodawać potwory i łup, otwierać wyjście, uzupełniać zdrowie i amunicję, włączać god mode oraz usuwać potwory. To narzędzia testowe — nie jest to system uprawnień do gry sieciowej.

## Rozgrywka
Potwory podążają za graczem, gdy usłyszą hałas albo podejdą wystarczająco blisko. Zwykły ruch i zbieranie rzeczy też hałasują; skradanie jest cichsze. Wyjście otwiera się po 35 sekundach. Zabezpiecz łup, przytrzymując E w zielonej strefie ewakuacji.
