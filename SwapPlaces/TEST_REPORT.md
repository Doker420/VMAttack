# SwapPlaces — TEST_REPORT

Дата release gate: **2026-11-05**. Проверялся standalone source в `SwapPlaces/`; AeroRush и BlockSiege не использовались как тестовая замена.

## Пройденные проверки

### Luau static gate

```text
SWAP_COMPILE_COUNT=9 FAIL=0
SWAP_ANALYZE_COUNT=9 FAIL=0
```

Проверены 2 shared modules, 5 server services, server Main и клиентский LocalScript. Компилятор: Luau 0.745. Analyzer запускался с Roblox global declarations header.

### Реальные Data / Trade / Swap modules в controlled Roblox mocks

```text
SWAP_NATIVE=PASS
tradeAtomic=PASS
dualConfirm=PASS
selectionReset=PASS
eitherPayer=PASS
characterSwap=PASS
healthPreserved=PASS
invalidTargets=PASS
revertDeathTimeout=PASS
receiptIdempotency=PASS
anchoredRejected=PASS
paymentDisconnect=PASS
zeroIDRejected=PASS
saveReload=PASS
```

Suite встраивает текущие production Config, SkinCatalog, DataService, TradeService и SwapService. Проверены:

- одностороннее подтверждение не выполняет trade;
- второй confirmation меняет владение одной выбранной парой без копии в server profiles;
- изменение selection сбрасывает подтверждение;
- инициатор не может принять offer за адресата;
- оба участника могут быть payer;
- реальные assignments `a.Character = charB`, `b.Character = charA`;
- здоровье исходных Humanoid не сбрасывается при обмене;
- revert, death, timeout и disconnect очищают session;
- anchored body отклоняется;
- неправильный Product ID и нулевой live Product ID не выполняют покупку;
- повторный receipt не выполняет второй swap;
- отмена purchase prompt снимает PaymentPending;
- save/reload сохраняет владение, counters и receipt dedup в controlled store.

### AppearanceService + SkinCatalog

```text
SWAP_APPEARANCE_NATIVE=PASS
skins=7
welds=PASS
safeParts=PASS
palettes=PASS
defaultCleanup=PASS
ownership=PASS
swappedBodyGuard=PASS
```

Проверены все семь торгуемых procedural-аксессуаров, welded parts, non-collidable/non-touch/non-query настройки, palette descriptions, очистка Default и guard против применения своего скина к управляемому телу партнёра.

### WorldBuilder

```text
SWAP_WORLD_NATIVE=PASS
rebuild=PASS
skins8=PASS
prompts8=PASS
safetyWalls4=PASS
palms12=PASS
swapPads2=PASS
spawn=PASS
anchored=PASS
```

Это composition/mock suite, а не визуальная проверка Studio.

### UI arithmetic и source contracts

```text
SWAP_UI_GEOMETRY=PASS sizes=6 compactLandscape=PASS docks=PASS toast=PASS swapControls=PASS modal=PASS
SWAP_SOURCE_CONTRACT=PASS scripts=9 remotes=8 usedRemotes=8 consent=PASS serverReceipt=PASS bodyAssignment=PASS appearanceGuard=PASS roleKeys=PASS
```

Geometry sizes: 1280×720, 1024×640, 800×500, 700×500, 360×640, 320×568. Проверяются формулы прямоугольников и отсутствие пересечений у основных dock/toast/player/swap controls. Text rendering и touch этим не доказываются.

Source contract проверяет remote coverage, server-only receipt/purchase, target consent, character assignments, appearance guard и согласованные роли `A/B` в trade selection.

### Packaging

Release tool генерирует place заново из production `.lua`, затем парсит сохранённый XML и сравнивает каждый Source по structural path:

```text
XML_PARITY=PASS scripts=9 structuralPaths=PASS
ZIP_PARITY=PASS integrity=PASS
```

ZIP дополнительно проверяется CRC, списком entries и byte-for-byte чтением каждого файла после записи.

## Что эти проверки не доказывают

Mocks и static checks **не являются** live multiplayer, character-control, rendering или purchase acceptance. Не выполнялись:

- открытие/запуск place в Roblox Studio;
- два реальных клиента с replication `Player.Character`, камерой, анимациями и network ownership;
- настоящий Robux Developer Product и Roblox receipt retry behavior;
- реальные DataStore, задержки/сбои сохранения двух профилей и crash recovery;
- touch, локализация текстовых размеров, сетевые задержки, physics и FPS;
- визуальная оценка моделей, галереи, accessories и plaza.

## Обязательный live checklist

1. Вставить настоящий `SwapProductId`; до этого live Robux отключён.
2. Опубликовать в своём experience и проверить два клиента: offer → consent → оплата каждым участником по очереди → чужое тело → камера → возврат.
3. Проверить decline/cancel, повторные клики, spoofed UserId/skin, одновременные trade/swap, death, reset, timeout и disconnect на каждой стадии.
4. Проверить receipt idempotency и отмену/закрытие purchase prompt на настоящем продукте.
5. Проверить trade ownership после rejoin и отдельно отказ DataStore одного из двух saves. Текущий commit атомарен в server memory, но две DataStore keys не образуют распределённую транзакцию.
6. Проверить R15/R6 аватары, разные official Roblox accessories, камеру и animations на управляемом теле.
7. Проверить мобильные размеры и визуальное качество в Studio/на устройстве.

`EnableStudioTestPurchases` выполняет только явно подписанный Studio TEST без Robux. Его PASS нельзя считать проверкой Production purchase.
