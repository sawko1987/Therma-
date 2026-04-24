# Промт для разработки: Подбор систем отопления (Шаг 2)

## Контекст проекта

Ты работаешь над Flutter-приложением `smartcalc_mobile` — Android-first инструментом для теплотехнических расчётов ограждающих конструкций частных домов. Стек: Flutter + Riverpod + Drift. Архитектура модульная, все фичи в `lib/src/features/`. Правила разработки: один файл — одна ответственность, тесты для сервисов и виджетов, все строки на русском.

Текущее состояние шага 2 (`building_step`): помещения, ограждающие конструкции, проёмы, базовые отопительные приборы (только добавление радиаторов с ручной мощностью без подбора). Нужно расширить функционал до полноценного подбора систем отопления.

---

## Задача: Полноценный подбор систем отопления

### 1. Расширение справочника отопительных приборов

#### 1.1 Модель данных `HeatingDeviceCatalogEntry` (расширить существующую)

```dart
// Добавить поля в существующую модель каталога
class HeatingDeviceCatalogEntry {
  // существующие поля...
  final String kind; // radiator | convector | underfloorLoop | heatPump | boiler | electricRadiator
  final String title;
  final double ratedPowerWatts;
  
  // НОВЫЕ поля:
  final String? manufacturer;        // Производитель (Oasis, НРЗ, Kermi, ...)
  final String? model;               // Модель (например, "22/500/800")
  final int? sections;               // Количество секций (для секционных радиаторов)
  final double? powerPerSection;     // Мощность одной секции, Вт
  final double? heightMm;            // Высота, мм
  final double? widthMm;             // Ширина (длина) одной секции, мм
  final double? depthMm;             // Глубина, мм
  final double? connectionDiameterMm; // Диаметр подключения, мм
  final double? waterVolumeLiters;   // Объём воды, л (для одной секции)
  final String? panelType;           // Тип панели: "11", "22", "33" (для панельных)
  final String? connectionType;      // Тип подключения: "side" | "bottom" | "diagonal"
  final double? maxWorkingPressureBar; // Макс. рабочее давление, бар
  final double? designFlowTempC;     // Расчётная температура подачи, °C (70, 80, 90)
  final double? designReturnTempC;   // Расчётная температура обратки, °C
  final String? sourceUrl;           // Ссылка на паспорт/прайс
  final String? sourceCheckedAt;     // Дата проверки данных
  final bool isCustom;               // Пользовательская запись
}
```

#### 1.2 Seed-данные для каталога

Заполни `assets/data/heating_devices.seed.json` реальными данными из паспортов. Структура по группам:

**Стальные панельные радиаторы (НРЗ — Нижнетагильский радиаторный завод):**
- Тип 11 (одна панель, одно оребрение): высоты 300, 400, 500, 600 мм; длины 400–3000 мм с шагом 100 мм
- Тип 22 (две панели, два оребрения): те же типоразмеры
- Тип 33 (три панели): высоты 500, 600 мм
- Мощность по паспорту НРЗ при ΔT=70°C (Tп=90°C, Tо=70°C, Tп=20°C):
  - Тип 22/500/800: 1036 Вт
  - Тип 22/500/1000: 1295 Вт  
  - Тип 22/500/1200: 1554 Вт
  - Тип 22/500/1600: 2072 Вт
  - Тип 22/600/800: 1204 Вт
  - Тип 22/600/1000: 1505 Вт
  - (и т.д., по паспорту НРЗ)

**Алюминиевые секционные радиаторы (Оазис):**
- Модель AL 500 (высота 500 мм): мощность 1 секции 175 Вт при ΔT=70°C, ширина секции 80 мм
- Модель AL 350 (высота 350 мм): мощность 1 секции 132 Вт
- Объём 1 секции: 0.27 л
- Диаметр подключения: 1/2"

**Конвекторы напольные:**
- Указать несколько типовых позиций с мощностью

**Минимальный набор seed-данных:** не менее 30 позиций реальных приборов с источниками паспортных данных.

---

### 2. Расчёт мощности радиатора с поправкой на температурный режим

Вынести в отдельный сервис `lib/src/core/services/heating_device_selection_service.dart`:

```dart
/// Поправочный коэффициент мощности радиатора при отличном от паспортного ΔT
/// По формуле EN 442: Q = Q_nom * (ΔT / ΔT_nom)^n
/// где n ≈ 1.3 для панельных стальных, n ≈ 1.25 для алюминиевых секционных
double correctedPower({
  required double nominalPowerWatts,     // паспортная мощность при ΔT_nom
  required double nominalDeltaT,         // паспортный ΔT (обычно 70°C)
  required double supplyTempC,           // температура подачи системы
  required double returnTempC,           // температура обратки системы
  required double roomTempC,             // температура помещения
  required double exponent,              // n (1.3 для стальных панельных)
});

/// Рекомендуемое количество секций / длина радиатора
/// для покрытия требуемой мощности помещения
HeatingDeviceSelectionResult selectDevice({
  required double requiredPowerWatts,
  required HeatingDeviceCatalogEntry deviceTemplate,
  required double systemSupplyTempC,
  required double systemReturnTempC,
  required double roomTempC,
});
```

---

### 3. Подбор тёплого пола (UFH — Underfloor Heating)

#### 3.1 Модель `UnderfloorHeatingCalculation`

Создать `lib/src/core/models/underfloor_heating.dart`:

```dart
class UnderfloorHeatingCalculation {
  final String id;
  final String roomId;
  final String constructionId;      // ID конструкции пола для этого контура
  
  // Геометрия
  final double activeAreaM2;        // Активная площадь укладки, м²
  final double pipePitchMm;         // Шаг укладки трубы, мм (100, 150, 200, 250, 300)
  final double pipeDiameterMm;      // Диаметр трубы: 16, 20 мм (PEX, PERT)
  
  // Подводящие трубопроводы
  final double supplyPipeLengthM;   // Длина подводящего трубопровода от коллектора, м
  final double supplyPipeDiameterMm; // Диаметр подводящего трубопровода, мм
  
  // Температурный режим
  final double supplyTempC;         // Температура подачи, °C (35, 40, 45, 50)
  final double returnTempC;         // Температура обратки, °C
  final double roomTargetTempC;     // Расчётная температура помещения, °C
  
  // Результаты (вычисляются)
  final double? loopLengthM;        // Расчётная длина контура, м
  final double? specificHeatFluxWm2; // Удельный тепловой поток, Вт/м²
  final double? actualPowerW;        // Фактическая тепловая мощность контура, Вт
  final double? flowRateLMin;        // Расход теплоносителя, л/мин
  final double? pressureDropKpa;     // Гидравлическое сопротивление контура, кПа
  
  // Уведомления
  final List<UfhWarning> warnings;
}

enum UfhWarning {
  loopTooLong,      // Контур длиннее 120 м — рекомендуется разбить
  loopTooShort,     // Контур короче 20 м — неэффективно
  highPressureDrop, // ΔP > 20 кПа — снизить длину или увеличить диаметр
  insufficientPower, // Мощность не покрывает теплопотери помещения
  floorTempExceeded, // Температура поверхности пола > 29°C (жилая) или > 35°C (ванная)
}
```

#### 3.2 Сервис расчёта тёплого пола `UnderfloorHeatingCalculationService`

```dart
class NormativeUnderfloorHeatingCalculationService {
  
  /// Расчёт удельного теплового потока через конструкцию пола (СП 60.13330)
  /// q = (T_supply_avg - T_room) / R_total_floor
  double calculateSpecificHeatFlux({...});
  
  /// Длина контура: L = (A * 1000) / pitch + 2 * supply_length
  double calculateLoopLength({...});
  
  /// Расход теплоносителя: G = Q / (c * rho * dT) [л/мин]
  /// c = 4.187 кДж/(кг·°C), rho = 1000 кг/м³ (вода)
  double calculateFlowRate({...});
  
  /// Гидравлическое сопротивление (упрощённая методика):
  /// ΔP = lambda/d * L * rho*v²/2 [Па]
  /// lambda по формуле Блазиуса для ламинарного потока
  double calculatePressureDrop({...});
  
  /// Температура поверхности пола (проверка по СП 60):
  /// T_floor = T_room + q * R_floor_cover
  double calculateFloorSurfaceTemp({...});
  
  /// Рекомендация расходомера коллектора:
  /// Настройка = flowRate [л/мин], округлить до 0.5
  double recommendedFlowmeterSetting({required double flowRateLMin});
  
  /// Генерация предупреждений
  List<UfhWarning> checkWarnings(UnderfloorHeatingCalculation result);
}
```

**Формулы и нормы (обязательно реализовать):**
- Максимальная длина контура: 80 м для Ø16 мм, 100 м для Ø20 мм (практическое ограничение)
- Максимальная температура поверхности пола: 29°C для жилых помещений, 35°C для ванных и санузлов, 31°C для краевых зон (СП 60.13330.2020 п. 6.5.5)
- Рекомендуемый шаг трубы: 150–200 мм для жилых помещений
- Расход одного контура: 2–5 л/мин (оптимально 3 л/мин)
- Допустимое гидравлическое сопротивление контура: до 20–25 кПа

---

### 4. Расчёт котла / теплового насоса для всего дома

Создать `lib/src/core/models/heating_system.dart`:

```dart
class HeatingSystemParameters {
  // Источник тепла
  final HeatingSourceType sourceType; // gasBoiler | heatPump | electricBoiler
  final double? boilerPowerKw;        // Мощность котла, кВт
  final double? heatPumpCopAtDesign;  // COP при расчётной температуре
  
  // Параметры системы
  final HeatingSystemType systemType; // radiators | underfloor | mixed | fanCoils
  final double supplyTempC;           // Температура подачи
  final double returnTempC;           // Температура обратки
  
  // Результаты подбора
  final double totalHeatLossW;        // Суммарные теплопотери здания
  final double recommendedBoilerPowerKw; // Рекомендуемая мощность котла
  final double reserveCoefficient;    // Коэффициент запаса (обычно 1.2)
}

enum HeatingSourceType { gasBoiler, heatPump, electricBoiler, solidFuelBoiler }
enum HeatingSystemType { radiatorsOnly, underfloorOnly, mixed }
```

---

### 5. UI — Экран подбора систем отопления

#### 5.1 Карточка подбора в шаге 2

Добавить в `RoomEditorStepScreen` новую секцию **"Система отопления"** после секции ограждений. Карточка содержит:

**Раздел A: Водяные радиаторы**
- Кнопка "Подобрать радиатор" → открывает `HeatingDevicePickerSheet`
- Список добавленных радиаторов с расчётной и фактической мощностью
- Индикатор баланса комнаты (теплопотери vs установленная мощность)

**`HeatingDevicePickerSheet`:**
- Фильтры: тип (панельный/секционный/конвектор), производитель, высота
- Поле "Требуемая мощность" (автозаполняется из теплопотерь помещения)
- Поля "Температура подачи / обратки" системы
- Список подходящих приборов с расчётной (скорректированной) мощностью
- При выборе: автоподбор количества секций / длины для покрытия теплопотерь
- Возможность вручную задать количество секций и пересчитать

**Раздел Б: Тёплый пол**
- Кнопка "Добавить контур тёплого пола"
- При добавлении: выбор конструкции пола из помещения (если несколько — список)
- Форма параметров контура:
  - Активная площадь, м²
  - Шаг трубы (выпадающий: 100/150/200/250/300 мм)
  - Диаметр трубы (16 или 20 мм)
  - Длина подводящих труб от коллектора, м
  - Диаметр подводящих труб, мм
  - Температура подачи / обратки
- Результаты расчёта (обновляются live):
  - Длина контура: X м
  - Удельный тепловой поток: X Вт/м²
  - Мощность контура: X Вт
  - **Настройка расходомера коллектора: X л/мин** (выделить жирным)
  - Гидравлическое сопротивление: X кПа
  - Температура поверхности пола: X °C
- Блок предупреждений (если есть `UfhWarning`):
  - Красный баннер: "⚠️ Контур длиннее рекомендуемого (X м > 80 м). Разбейте на 2 контура или увеличьте диаметр до 20 мм."
  - Жёлтый баннер: "⚠️ Высокое гидравлическое сопротивление (X кПа). Рекомендуется сократить длину или увеличить диаметр трубы."
  - Жёлтый баннер: "⚠️ Температура поверхности пола X °C превышает норму 29°C. Снизьте температуру подачи."

**Раздел В: Источник тепла (на весь дом)**
В сводке теплопотерь здания добавить секцию:
- Выбор типа источника тепла (котёл газовый / тепловой насос / электрокотёл)
- Суммарные теплопотери дома: X кВт
- Рекомендуемая мощность котла: X кВт (с коэф. запаса 1.2)
- Для теплового насоса: мощность при COP X = Y кВт электрическая

---

### 6. Справочник отопительных приборов (Settings)

Добавить в `SettingsScreen` новый пункт **"Справочник приборов отопления"** → `HeatingDeviceDirectoryScreen`:

- Фильтры: тип прибора, производитель, высота (для радиаторов)
- Для каждой записи: название, мощность, типоразмер, источник данных
- Кнопка "Добавить свой прибор" → `HeatingDeviceEditorSheet`:
  - Поля: тип, производитель, модель, высота, мощность (при ΔT=70°C), количество секций / длина, диаметр подключения, ссылка на паспорт
  - Сохраняется в БД как `isCustom = true`

---

### 7. Хранение данных

Расширить `AppDatabase` / `DriftProjectRepository`:

- Таблица `stored_heating_device_catalog_entries` — аналогично `stored_opening_catalog_entries`
- Расчёты тёплого пола хранить внутри `Project.houseModel` как `underfloorCalculations: List<UnderfloorHeatingCalculation>`
- Параметры системы отопления хранить как `heatingSystemParameters: HeatingSystemParameters?` в `Project`

---

### 8. Миграция и версионирование

- Увеличить `currentProjectFormatVersion` до 21
- В `ProjectMigrationService.migrate()` добавить ветку `< 21`: инициализировать `underfloorCalculations = []`, `heatingSystemParameters = null`

---

### 9. Тесты

Написать тесты:

```
test/underfloor_heating_calculation_service_test.dart
  - контур 150 м² / шаг 200 мм / Ø16 мм / подача 40°C → длина ~90 м → warning loopTooLong
  - контур 12 м² / шаг 150 мм / Ø16 мм / подача 45°C → настройка расходомера 2.0 л/мин
  - температура поверхности пола > 29°C → warning floorTempExceeded

test/heating_device_selection_service_test.dart
  - поправка мощности радиатора НРЗ 22/500/1000 (1295 Вт при ΔT=70) при системе 70/50: ~780 Вт
  - подбор секций алюминиевого радиатора для помещения с теплопотерями 750 Вт

test/heating_device_directory_screen_test.dart
  - каталог содержит seed-записи производителей НРЗ и Оазис
  - добавление своего прибора сохраняется как isCustom = true
```

---

### 10. Порядок реализации (рекомендуемый)

1. Расширить модели данных (`UnderfloorHeatingCalculation`, `HeatingSystemParameters`, расширить `HeatingDeviceCatalogEntry`)
2. Заполнить seed JSON реальными паспортными данными (НРЗ, Оазис — минимум 30 позиций)
3. Написать `UnderfloorHeatingCalculationService` с тестами
4. Написать `HeatingDeviceSelectionService` с поправочным коэффициентом и тестами
5. Расширить `DriftProjectRepository` — хранение кастомных приборов
6. UI: `HeatingDeviceDirectoryScreen` + `HeatingDeviceEditorSheet`
7. UI: `HeatingDevicePickerSheet` с автоподбором
8. UI: секция тёплого пола в `RoomEditorStepScreen`
9. UI: секция источника тепла в сводке теплопотерь
10. Миграция БД, тесты виджетов

---

### 11. Ключевые ограничения и требования

- **Все числовые расчёты** должны иметь unit-тесты с проверкой по эталонным данным из паспортов
- **Предупреждения тёплого пола** должны обновляться live при изменении любого параметра
- **Настройка расходомера** в л/мин — округлять до 0.5 л/мин, отображать жирным как главный итог расчёта контура
- **Источник паспортных данных** всегда указывать (URL + дата проверки) для каждой seed-записи каталога
- **Пользовательские приборы** (isCustom = true) помечаются визуально как в каталоге материалов
- **Не ломать существующие тесты** — все существующие тесты теплопотерь и термокалька должны проходить после изменений
- Использовать существующий стиль кода: `final` везде где возможно, `const` конструкторы, Riverpod providers, русские строки в UI