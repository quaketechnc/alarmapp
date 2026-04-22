# Testing Plan — Alarm App

## Setup

- **Device / Simulator**: iPhone 17 Pro simulator (iOS 26.4) для базового UI/flow; **реальное устройство обязательно** для AlarmKit fire, системного alert, камеры, акселерометра и фонового будильника.
- **Reset state between runs**: удалить и переустановить приложение (сбрасывает UserDefaults и ключ `hasCompletedOnboarding`).
- **Shake в симуляторе**: в ShakeMission есть кнопка "Tap to shake" — имитация тряски.
- **Build check**:
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    xcodebuild -scheme Alarm -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
  ```

> ⚠️ Приложение спроектировано так, что **единственный способ остановить звонящий будильник — выполнить миссию** (или, если миссий нет, явно нажать "Dismiss alarm"). Отсутствие escape-выхода из миссии — это фича, а не баг.

---

## 1. Onboarding

### 1.1 Happy path
1. Первый запуск → экран Intro
2. "Get started" → SetAlarm — выбрать время и дни
3. Next → Ringtone — выбрать тон, проверить превью (звук играет)
4. Next → Mission — выбрать миссию
5. "Finish" → `AlarmListView`
6. **Ожидается:** в списке ровно **1** будильник (из онбординга), никаких мок-будильников; AlarmKit-alarm зашедулен (`alarmKitID` не nil у единственной записи).

### 1.2 Skip
- На любом шаге с кнопкой Skip → `AlarmListView` пустой (0 alarms); `hasCompletedOnboarding = true`.

### 1.3 Mission = "Off"
- Если на шаге Mission выбрана "Off" → создаётся будильник с `missionIDs = []`. При срабатывании RingingView показывает "Dismiss alarm" (см. §7.1).

### 1.4 Повторный запуск
- Закрыть и открыть приложение → онбординг не показывается, список сохранён.

### 1.5 Разрешения (реальное устройство)
- AlarmKit: попап → "Allow" → иконка зелёного checkmark.
- Отказ → SettingsView → Permissions row показывает "Denied" + "Open Settings" ведёт в системные настройки.

---

## 2. AlarmStore (Persistence)

| Тест | Действие | Ожидается |
|------|----------|-----------|
| Сохранение | Создать будильник → kill → relaunch | Сохранился |
| Toggle | Enable/disable → kill → relaunch | Состояние сохранилось |
| Удаление | Swipe-delete → kill → relaunch | Отсутствует |
| Редактирование | Изменить время → Save → kill → relaunch | Изменения сохранились |
| pendingMission | Kill во время звонка (см. §5.5) | `pendingMission` восстанавливается, backup alarm срабатывает |
| backupAlarmKitID | Убедиться, что поле чистится после `completeMission()` | nil после успеха |

---

## 3. Список будильников

### 3.1 Quick Alarm
1. FAB → "Quick alarm" → "10m" → "Start alarm"
2. **Ожидается:** sheet закрывается; в списке новый будильник; тон/громкость/вибрация — **из Settings defaults** (не из sheet). Поле `isQuick = true`.
3. После срабатывания и завершения миссии — quick-будильник **удаляется** из списка (см. `AlarmStore.completeMission`).

### 3.2 Custom Alarm
1. FAB → "Custom alarm"
2. Выбрать время 08:30; снять Daily, выбрать Mon+Wed
3. Mission: добавить "Shake", удалить "Math"
4. Sound: выбрать любой тон из нового списка (Apex / Beacon / Chimes / Cosmic / Hillside / Night Owl / Radar / Ripples / Sencha / Slow Rise / Uplift / Waves); volume 80%
5. Save → карточка с корректными данными, `isQuick = false`.

### 3.3 Редактирование (tap-to-edit)
1. Тап по карточке → `CustomAlarmView` в режиме "Edit Alarm" с предзаполненными полями.
2. Изменить время → Save.
3. **Ожидается:** старый `alarmKitID` отменён через `AlarmService.cancel(...)`, зашедулен новый; `id` записи сохраняется (не создаётся новая строка).

### 3.4 Swipe to delete
- Swipe-left → Delete → карточка исчезает; `AlarmService.cancel(alarmKitID:)` вызван; запись удалена из UserDefaults.

### 3.5 Toggle enable/disable
- Тумблер: disabled → карточка затемняется. Enable → возврат.
- **Регрессия:** disabled будильник **не должен** звонить.

### 3.6 "Next rings in …"
- Один enabled будильник на +1 ч → "next in 1h 0m" (±1 мин).
- Все disabled / список пуст → "no alarms set".

---

## 4. Settings

> Snooze удалён. В SettingsView сейчас: **Defaults / Permissions / Legal / DEBUG**.

### 4.1 Открытие
- ⚙️ в header → `SettingsView`.

### 4.2 Default tone
- Settings → Default ringtone → выбрать, например, "Radar" → Back.
- FAB → Quick alarm → секция SOUND показывает "Radar".
- Start → созданный alarm имеет `toneID = "radar"` (по умолчанию — `"radar"`).

### 4.3 Default volume / vibration
- Settings → Volume 100 %, Vibration off.
- Quick alarm sheet: слайдер стартует с 100, toggle вибрации off.

### 4.4 Permissions row
- Authorized → зелёный индикатор.
- Denied / notDetermined → соответствующие состояния; "Open Settings" открывает системные настройки.
- Изменение в системных настройках → row реагирует (реактивно через `alarmService.authState`).

### 4.5 Legal
- "Terms of Use" и "Privacy Policy" → открывают Safari.

### 4.6 DEBUG section
- Проверить, что debug-действия работают и не крэшат прод-флоу.

### 4.7 Persistence
- Kill/relaunch → все настройки сохранились (`@AppStorage` keys: `defaultToneID`, `defaultVolume`, `defaultVibration`, `hasCompletedOnboarding`).

---

## 5. Ringing Flow (реальное устройство)

### 5.1 Основной триггер — приложение открыто
1. Создать Quick alarm на +1 мин, оставить приложение на переднем плане.
2. В момент срабатывания `AlarmManager.alarmUpdates` выдаёт `.alerting` → `AlarmApp.watchAlarms` ставит `firingAlarmID`/`pendingMission`, **гасит системный alert** через `AlarmService.stop(alarmKitID:)` и показывает `RingingView`.
3. В RingingView играет тон через `AudioService` (в петле). **Не должно быть двойного звука** (система + приложение).

### 5.2 Триггер — приложение в фоне / экран заблокирован
1. Создать Quick alarm на +1 мин → нажать Home / заблокировать.
2. Срабатывает AlarmKit alert на системном уровне.
3. Тап по стоп/secondary-кнопке (`SolveMissionIntent`, `openAppWhenRun = true`) → приложение поднимается → `watchAlarms` подхватывает `.alerting` → `RingingView` → `MissionExecutionView`.
4. Перехода звука быть не должно (воспринимается непрерывно).

### 5.3 Mission = starting
- Нажатие CTA "Solve mission to dismiss" → `MissionExecutionView` через fullScreenCover.
- После завершения миссии → `onComplete` → `AlarmStore.completeMission()` → `RingingView` закрывается.

### 5.4 Аудио
- Старт сразу при appear `RingingView`.
- Играет в silent mode (mute switch) — штатно для alarm-приложения.
- Останавливается при dismiss / завершении миссии (`AudioService.stop()` в `onDisappear`).

### 5.5 Reliability / backup alarm (критично)
1. **Watchdog:** во время `.alerting` `AlarmApp.watchdog` каждые 10 с пересоздаёт duplicate alarm на `backupDelaySeconds = 20` с. Проверка: `store.backupAlarmKitID` меняется/обновляется во время звонка.
2. **Kill во время миссии:** на звонящем будильнике начать миссию → kill app (swipe из recents).
   - В течение ~20 с backup alarm срабатывает на системном уровне → тап по кнопке → приложение запускается → восстанавливается `pendingMission` из UserDefaults → сразу открывается `RingingView` → `MissionExecutionView`.
   - Выполнить миссию → `completeMission()` → backup отменяется, состояние очищается.
3. **Завершение миссии → backup отменён:** после успеха `backupAlarmKitID = nil`, duplicate alarm не должен фирить позже.
4. **Recurring alarms:** после завершения миссии на recurring будильнике он перешедулен на следующее вхождение (новый `alarmKitID`). One-time — `isEnabled = false`. Quick — удалён из `items`.

---

## 6. Миссии

### 6.1 Math
- Задача "A × B"; правильный ввод → ✓ → advance. Неправильный → шейк и сброс.

### 6.2 Typing
- Фраза "The early bird catches the worm" (hardcoded).
- Посимвольный ввод: правильные зелёные, ошибочные оранжевые; дойти до конца → advance.

### 6.3 Tiles
- Запомнить последовательность 5 плашек → нажать в том же порядке. Неверный tap — игнор. Все 5 → advance.

### 6.4 Shake (реальное устройство)
- Тряска → прогресс → 100 % → advance. Симулятор: кнопка "Tap to shake".

### 6.5 Photo (реальное устройство)
- Требует `NSCameraUsageDescription`.
- Задача из `TaskService` (14 штук). Capture → ResNet50 → совпадение keywords → success → "Next Task" → advance.
- Несовпадение → "Saw '…'. Try again!". Shuffle меняет задачу.

### 6.6 Multi-mission
- Будильник с 3 миссиями → прогресс "1/3 → 2/3 → 3/3" → RingingView закрывается после последней.

### 6.7 Нет escape
- В `MissionExecutionView` нет кнопки Cancel/Back: будильник нельзя заглушить без завершения миссии. Проверить отсутствие свайпа вниз для fullScreenCover.

---

## 7. Edge Cases

| Сценарий | Ожидаемое поведение |
|----------|---------------------|
| Будильник без миссий (`missionIDs = []`, или mission "Off") | RingingView показывает CTA **"Dismiss alarm"** с иконкой checkmark. Тап → `onDismiss()` → `completeMission()`. `MissionExecutionView` **не открывается**. Камера **не запрашивается**. |
| `MissionExecutionView` со строкой миссии "off" или "" | Внутренний switch → `Color.clear.onAppear { advance() }` — немедленный advance, не дефолт в PhotoMission. |
| Kill app во время миссии | Backup alarm срабатывает через ≤20 с → приложение поднимается → миссия возобновляется (см. §5.5.2). |
| AlarmKit permission отозван после создания будильников | Primary не зафайрится; SettingsView показывает Denied. Backup также не зафайрится. |
| Смена часового пояса | Relative-schedule (Quick) не зависит от TZ; fixed schedule (Custom) зависит — задокументированный компромисс. |
| Больше `maximumLimitReached` alarm-слотов | `AlarmService.schedule` кинет ошибку — UI сейчас её молча проглатывает (гэп, см. CLAUDE.md). |
| Quick alarm на +1 мин, завершить миссию | Запись удаляется из списка, потому что `isQuick = true`. |
| Recurring alarm на сегодня уже прошедшее время | Зашедулен на следующее вхождение (`AlarmService.nextFireDate`). |
| Двойной звук (система + app) при поднятии из фона | Не должно быть: `watchAlarms` зовёт `AlarmService.stop(alarmKitID:)` перед показом RingingView. |

---

## 8. Regression Checklist (перед каждым релизом)

- [ ] BUILD SUCCEEDED: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Alarm -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- [ ] Онбординг от начала до конца → создан **ровно один** будильник, мок-данных нет
- [ ] Skip в онбординге → пустой список
- [ ] Quick alarm +1 мин → файрится и звонит; после миссии — удаляется
- [ ] Custom alarm на конкретное время → файрится; recurring — перешедулен на следующее вхождение
- [ ] Tap-to-edit → изменения применены, старый AlarmKit-alarm отменён, `id` сохранён
- [ ] Swipe-delete → будильник не файрится
- [ ] Toggle disable → будильник не файрится
- [ ] Все миссии (math / type / tiles / shake / photo) завершаются успешно
- [ ] Mission "Off" / пустой массив → RingingView показывает "Dismiss alarm", **камера не открывается**
- [ ] Mission cancel невозможен — проверить отсутствие escape
- [ ] Settings default tone / volume / vibration → подхватываются в Quick alarm
- [ ] Permissions row реагирует на изменение разрешений вживую
- [ ] Legal links открывают Safari
- [ ] Kill во время миссии → backup alarm возвращает в миссию (≤20 с)
- [ ] `pendingMission` и `backupAlarmKitID` очищаются после `completeMission()`
- [ ] Нет двойного звука (AlarmKit system alert + in-app AudioService)
- [ ] Перезапуск приложения → все настройки и будильники сохранены
