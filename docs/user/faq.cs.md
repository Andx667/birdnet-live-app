# FAQ

Často kladené otázky.

## Generál

**Otázka: Vyžaduje BirdNET Live připojení k internetu?**
Odpověď: Ne. Veškeré odvození běží na zařízení pomocí modelu ONNX. Jedinými funkcemi sítě jsou vyhledávání obrázků/popisů druhů z API taxonomie, které jsou volitelné.

**Otázka: Kolik druhů dokáže identifikovat?**
Odpověď: Model BirdNET+ V3.0 identifikuje 5 250 druhů ptáků po celém světě (ořezaný průnik zvukového klasifikátoru a geomodelu).

**Otázka: Jaké platformy jsou podporovány?**
Odpověď: Android (8.0+), iOS (15.0+) a Windows (experimentální).

## Přesnost

**Otázka: Proč můj práh spolehlivosti ukazuje nízké skóre?**
Odpověď: Snižte práh spolehlivosti v Nastavení, abyste viděli více detekcí. Šum na pozadí, vítr a vzdálenost ovlivňují přesnost.

**Otázka: Co dělá druhový filtr?**
Odpověď: Geografický model předpovídá, které druhy se pravděpodobně vyskytují ve vaší poloze GPS a ročním období. Chcete-li skrýt nepravděpodobné druhy, povolte možnost „Vyloučit zeměpisné oblasti“ nebo povolte možnost „Sloučit zeměpisné oblasti“ pro váhu výsledků podle zeměpisné pravděpodobnosti.

**Otázka: Jak přesná je identifikace?**
Odpověď: Přesnost závisí na kvalitě záznamu, vzdálenosti, šumu v pozadí a druhu. Detekce s vysokou spolehlivostí (>70 %) jsou obecně spolehlivé. Vzácné druhy vždy ověřujte vizuálně.

## Nahrávání

**Otázka: Kde se ukládají nahrávky?**
Odpověď: V adresáři dokumentů aplikace pod `recordings/<session-id>/`. Úplné nahrávky se ukládají jako soubory WAV.

**Otázka: Mohu analyzovat existující nahrávky?**
A: Ano. Otevřete Analýzu souborů z domovské obrazovky, vyberte zvukový soubor, nastavte umístění a parametry a klepněte na Analyzovat. Mezi podporované formáty patří WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA a AMR.

## Počet bodů

**Otázka: Co je režim počítání bodů?**
A: Režim časovaného průzkumu pro formální pozorování počtu ptačích bodů. Nastavíte pevnou dobu trvání (3–20 minut) a umístění, poté aplikace běží nepřetržitě a automaticky se zastaví, když časovač dosáhne nuly.

**Otázka: Mohu pozastavit počítání bodů?**
Odpověď: Ne. Soulad s protokolem vyžaduje nepřerušované nahrávání. Předčasně můžete ukončit pomocí tlačítka stop.

**Otázka: Kam jdou výsledky počítání bodů?**
Odpověď: Zobrazují se v knihovně relací jako "Počet bodů #1", "#2" atd. Můžete je kontrolovat, upravovat a exportovat jako kteroukoli jinou relaci.

## Výkon

**Otázka: Proč je aplikace teplá / používá baterii?**
Odpověď: Odvozování modelu ONNX je výpočetně náročné. Obrazovka také zůstane zapnutá během živých relací. To je normální pro zpracování neuronové sítě v reálném čase.

**Otázka: Spektrogram vypadá zmrazený.**
Odpověď: Ujistěte se, že je uděleno oprávnění k mikrofonu a že je aktivní nahrávání zvuku. Zkontrolujte, zda mikrofon nepoužívá žádná jiná aplikace.