# BLOCKSIEGE: настройка косметических Game Passes

Документ описывает **только косметические** покупки. В текущем исходнике все ID намеренно равны `0`: это заглушки, а не работающие Game Passes. Не публикуйте игру как платную, пока не замените их и не проверите поток на приватной live-версии.

## Товары

| Ключ в `Catalog.Cosmetics` | Слот | Каталожная цена | Поле для ID |
|---|---|---:|---|
| `GoldenArsenal` | `WeaponSkin` | 99 R$ | `GamePassId` |
| `AuroraAura` | `Aura` | 79 R$ | `GamePassId` |
| `RoyalTrail` | `Trail` | 49 R$ | `GamePassId` |

Цена в каталоге — отображаемая цена/план, а не самостоятельная настройка цены Game Pass. Цену и владельца нужно задать в Roblox Creator Dashboard. Не меняйте боевые значения в `Catalog.Weapons` при добавлении косметики.

## Настройка владельцем опыта

1. Опубликуйте тестовую версию BLOCKSIEGE в своей вселенной Roblox.
2. В **Creator Dashboard → Monetization → Passes** создайте три Game Passes с понятными названиями и описаниями «cosmetic only».
3. Скопируйте числовые IDs в `src/ReplicatedStorage/Catalog.lua`:
   ```lua
   GoldenArsenal = { Name = "GOLDEN ARSENAL", GamePassId = 123456789, RobuxPrice = 99, Slot = "WeaponSkin", Description = "..." },
   AuroraAura = { Name = "AURORA CORE", GamePassId = 123456790, RobuxPrice = 79, Slot = "Aura", Description = "..." },
   RoyalTrail = { Name = "ROYAL TRAIL", GamePassId = 123456791, RobuxPrice = 49, Slot = "Trail", Description = "..." },
   ```
   Используйте собственные IDs; числа выше только пример формата, не рабочие товары.
4. Проверьте, что Game Passes принадлежат тому же владельцу/группе, который публикует опыт, и задайте цены в Dashboard.
5. Пересоберите `BlockSiege.rbxlx` через Rojo и опубликуйте отдельную приватную тестовую версию.
6. Проверьте покупку на тестовом аккаунте с разрешёнными покупками: окно Game Pass, отмена, успешная покупка, повторный вход, экипировка и отображение у второго клиента.
7. Только после этого включайте Public. Сохраните список реальных IDs и цен в приватной документации владельца.

## Как работает сервер

- `ShopService.Buy` сначала проверяет профиль и существующее владение.
- При нулевом ID в live сервер отклоняет покупку; бесплатного обхода через клиент нет.
- При ненулевом ID сервер вызывает `UserOwnsGamePassAsync`, затем `PromptGamePassPurchase`.
- `PromptGamePassPurchaseFinished` выдаёт предмет только для соответствующего ненулевого ID и только после `purchased == true`.
- Владение и выбранный слот записываются через `DataService`; косметика не добавляет Coins, CaseTokens, XP или боевые характеристики.
- Все RemoteEvents обрабатываются сервером. Клиентские текст, цена и кнопка не являются доказательством покупки.

## Studio TEST

В `src/ReplicatedStorage/Config.lua`:

```lua
EnableStudioTestPurchases = true
```

В Studio кнопка неоплаченного предмета помечается `TEST`; сервер выдаёт косметику без Robux через `GrantForTesting`. Это нужно для проверки ауры, Trail, золотого оружия и сохранения в памяти. В live `RunService:IsStudio()` равно false, поэтому этот путь не работает.

Для проверки отказов установите флаг `false` в отдельной тестовой копии. Не используйте Studio TEST как доказательство успешной live-транзакции.

## Границы монетизации

- Лутбоксы открываются только за заработанные монеты или жетоны. За Robux нельзя купить случайную награду, оружие, монеты, жетоны, XP или уровень.
- Game Passes не повышают урон, HP, Armor, WalkSpeed, BuildCapacity и не влияют на level-aware draft.
- Проверьте возрастные/региональные настройки, Maturity & Compliance Questionnaire и правила Roblox для платного контента перед публикацией.
- В этом пакете не выполнялись реальные Robux-транзакции, проверка Dashboard, live DataStore или живой мультиплеер. Эти пункты остаются обязательным ручным тестом владельца.
