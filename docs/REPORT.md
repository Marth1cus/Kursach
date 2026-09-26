# Материалы для пояснительной записки

Тема: **«Разработка веб-приложения "Каталог спортивной обуви"»**.
Разделы идут в порядке, указанном в требованиях к оформлению. Титульный лист и задание оформляются по бланкам преподавателя.

---

## Введение

Рынок спортивной обуви насчитывает тысячи моделей десятков брендов, которые различаются назначением (бег, баскетбол, футбол, трейл и т. д.), размерной сеткой, материалами и ценой. Покупателю сложно быстро сравнить модели и узнать о наличии нужного размера, а магазину — оперативно обрабатывать запросы клиентов.

**Цель работы** — разработать веб-приложение «Каталог спортивной обуви» (Sport Step), позволяющее клиентам просматривать, искать и фильтровать модели, сохранять их в избранное, оставлять отзывы и бронировать пару для примерки, а администратору — управлять каталогом, обрабатывать заявки и пользователей.

**Задачи:**

1. спроектировать клиент-серверную архитектуру приложения;
2. разработать серверную часть на языке Go (REST API, СУБД SQLite);
3. разработать клиентскую часть на Flutter (Dart) для платформы Web;
4. реализовать две роли (клиент, администратор) с автоматическим определением роли при входе;
5. реализовать избранное, корзину удалённых моделей, заявки и систему уведомлений;
6. обеспечить обработку ошибок и валидацию данных.

---

## 1. Структура системы

Система состоит из двух независимых компонентов: Flutter-клиента и Go-сервера, которые обмениваются данными по протоколу HTTP в формате JSON.

### 1.1. Диаграмма классов

* Клиентская часть: `docs/diagrams/class_client.png`
* Серверная часть: `docs/diagrams/class_server.png`

Таблица 1 — Пользовательские классы клиентской части

| Класс | Тип | Основные атрибуты | Основные методы | Назначение |
|---|---|---|---|---|
| `Shoe` | Модель | id, name, brand, category, gender, price, oldPrice, sizes, imageUrl, inStock, rating, isFavorite | `fromJson()`, `toJson()`, `copyWith()`, `onSale`, `discountPercent` | Данные модели обуви |
| `ShoeFilter` | Модель | query, category, gender, brands, minPrice, maxPrice, size, inStockOnly, saleOnly, sort | `toQuery()`, `copyWith()`, `cleared()`, `activeCount` | Параметры поиска, фильтрации и сортировки |
| `User` | Модель | id, login, name, role, blocked | `fromJson()`, `isAdmin`, `initials` | Пользователь (роль приходит с сервера) |
| `Order` | Модель | id, shoeId, size, phone, comment, status, adminComment, isNew | `fromJson()`, `statusLabel`, `statusColor` | Заявка на бронирование |
| `Review` | Модель | id, userName, rating, text, createdAt | `fromJson()` | Отзыв о модели |
| `ApiService` | Сервис (singleton) | `_token`, `onSessionExpired` | `login()`, `getShoes()`, `saveShoe()`, `setFavorite()`, `createOrder()`, `decideOrder()`, `getUnreadCount()`, `_send()` | Все HTTP-запросы к REST API, обработка ошибок |
| `ApiException` | Исключение | message, statusCode | `isUnauthorized`, `isBlocked` | Понятное сообщение об ошибке сервера/сети |
| `StorageService` | Сервис | ключи SharedPreferences | `saveToken()`, `getTheme()`, `addSearchQuery()` | Локальное хранилище |
| `AuthProvider` | ChangeNotifier | user | `tryRestoreSession()`, `login()`, `register()`, `logout()` | Состояние авторизации |
| `NotificationProvider` | ChangeNotifier | unread, hasFresh | `start()`, `refresh()`, `markAllRead()` | Опрос сервера и счётчик уведомлений |
| `ThemeProvider` | ChangeNotifier | mode | `load()`, `setMode()` | Светлая/тёмная тема |
| `AppColors`, `AppStyles`, `ShoeCategories` | Стили | цвета, отступы, радиусы, темы | `lightTheme`, `darkTheme`, `input()` | Вынесенные стили приложения |
| `PagedShoeList` | Виджет | loader, items, total | `reload()`, `_loadMore()` | ListView.builder с подгрузкой по 5 элементов |
| `ShoeCard` | Виджет | shoe | — | Карточка модели в списке |
| `NotificationBell` | Виджет | AnimationController | — | Колокольчик с бейджем и миганием |
| `SneakerLoader`, `Shimmer` | Виджет | AnimationController | — | Анимации загрузки |
| `AppDrawer` | Виджет | — | — | Боковое меню (набор пунктов зависит от роли) |
| `SplashScreen` | Экран | — | `_start()` | Приветственный экран с анимацией |
| `LoginScreen`, `RegisterScreen` | Экран | — | `_submit()` | Вход и регистрация |
| `HomeScreen` | Экран | filter, meta | `_applyFilter()`, `_openFilters()`, `_toggleFavorite()` | Каталог: поиск, категории, сортировка |
| `FilterSheet` | Экран | — | `_apply()`, `_reset()` | Фильтры (Radio, Checkbox, RangeSlider, Switch …) |
| `ShoeDetailScreen` | Экран | shoe, reviews | `_book()`, `_addReview()`, `_edit()`, `_delete()` | Подробная информация |
| `ShoeFormScreen` | Экран | поля формы | `_save()` | Добавление/редактирование модели |
| `FavoritesScreen`, `TrashScreen` | Экран | — | `_remove()`, `_restore()`, `_purge()` | Избранное и корзина |
| `OrdersScreen` | Экран | orders, status | `_decide()`, `_cancel()` | Заявки клиента / администратора |
| `UsersScreen`, `ProfileScreen` | Экран | — | `_toggle()`, `_loadStats()` | Пользователи, профиль и настройки |

Таблица 2 — Основные типы и функции серверной части

| Элемент | Назначение |
|---|---|
| `App` | Хранит подключение к БД, содержит обработчики всех эндпоинтов |
| `App.auth`, `App.admin` | Middleware проверки токена и роли администратора |
| `User`, `Shoe`, `Review`, `Order` | Структуры данных, сериализуемые в JSON |
| `shoeInput.validate()` | Серверная валидация данных модели |
| `OpenDB()`, `seed()` | Создание схемы и начальное заполнение (40 моделей) |
| `writeJSON()`, `writeError()`, `serverError()` | Единый формат ответов и ошибок |

### 1.2. Диаграмма развёртывания

`docs/diagrams/deployment.png`

Таблица 3 — Компоненты

| Узел | Компонент | Технология |
|---|---|---|
| Клиент (браузер) | Flutter Web приложение | Dart 3, Flutter 3, Provider |
| Клиент (браузер) | Локальное хранилище | SharedPreferences (localStorage) |
| Сервер | REST API и раздача статики | Go 1.22+, net/http, bcrypt |
| Сервер | База данных | SQLite (modernc.org/sqlite) |

---

## 2. Структура БД

Используется СУБД SQLite; схема создаётся при первом запуске сервера (`backend/db.go`). ER-диаграмма: `docs/diagrams/database.png`.

Таблица 4 — Сущности базы данных

| Таблица | Назначение | Основные поля |
|---|---|---|
| `users` | Пользователи | id (PK), login (UNIQUE), password_hash (bcrypt), name, role ('client'/'admin'), blocked, created_at |
| `sessions` | Активные сеансы | token (PK), user_id (FK → users) |
| `shoes` | Модели обуви | id (PK), name, brand, category, gender, price, old_price, color, sizes, material, surface, weight, description, image_url, in_stock, deleted, deleted_at |
| `favorites` | Избранное | user_id + shoe_id (составной PK, FK) |
| `reviews` | Отзывы | id (PK), shoe_id (FK), user_id (FK), rating (1–5), text |
| `orders` | Заявки на бронирование | id (PK), user_id (FK), shoe_id (FK), size, phone, comment, status ('pending'/'approved'/'rejected'), admin_comment, seen_by_admin, seen_by_client |

Поле `shoes.deleted` реализует «мягкое» удаление — модель попадает в корзину и может быть восстановлена. Поля `seen_by_admin` / `seen_by_client` используются для счётчика уведомлений. Рейтинг модели вычисляется как среднее по таблице `reviews`.

### 2.1. Хранение данных на клиенте (SharedPreferences)

| Ключ | Тип | Описание |
|---|---|---|
| `auth_token` | String | Токен сеанса (сеанс восстанавливается после перезагрузки страницы) |
| `theme_mode` | String | Тема: light / dark / system |
| `last_login` | String | Последний введённый логин |
| `search_history_<userId>` | List\<String\> | История поиска отдельно для каждого пользователя |

---

## 3. Используемое API

Собственный REST API сервера. Базовый URL: `http://localhost:8080/api`. Все эндпоинты, кроме регистрации и входа, требуют заголовок `Authorization: Bearer <token>`.

Таблица 5 — Эндпоинты REST API

| Метод | URL | Описание | Доступ |
|---|---|---|---|
| POST | /auth/register | Регистрация клиента | все |
| POST | /auth/login | Вход, возвращает токен и пользователя с ролью | все |
| GET | /auth/me | Текущий пользователь (восстановление сеанса) | токен |
| POST | /auth/logout | Завершение сеанса | токен |
| GET | /shoes | Список: `limit`, `offset`, `q`, `category`, `gender`, `brands`, `min_price`, `max_price`, `size`, `in_stock`, `sale`, `favorites`, `deleted`, `sort` | токен |
| GET | /shoes/{id} | Модель по id | токен |
| POST | /shoes | Добавить модель | admin |
| PUT | /shoes/{id} | Изменить модель | admin |
| DELETE | /shoes/{id} | Переместить в корзину | admin |
| PUT | /shoes/{id}/restore | Восстановить из корзины | admin |
| DELETE | /shoes/{id}/purge | Удалить окончательно | admin |
| GET | /meta | Бренды, размеры, диапазон цен для фильтров | токен |
| POST / DELETE | /favorites/{id} | Добавить / убрать из избранного | токен |
| GET / POST | /shoes/{id}/reviews | Отзывы модели / добавить отзыв | токен |
| DELETE | /reviews/{id} | Удалить отзыв (автор или admin) | токен |
| GET | /orders | Заявки (admin — все, клиент — свои) | токен |
| POST | /orders | Забронировать модель | клиент |
| DELETE | /orders/{id} | Отменить свою заявку | клиент |
| PUT | /orders/{id}/approve, /reject | Решение по заявке | admin |
| GET | /notifications | Количество непрочитанных уведомлений | токен |
| POST | /notifications/read | Отметить уведомления прочитанными | токен |
| GET | /users | Список пользователей | admin |
| PUT | /users/{id}/block, /unblock | Блокировка клиента | admin |
| GET | /stats | Статистика каталога | admin |

Пример ответа `GET /api/shoes?limit=5&offset=0`:

```json
{
  "items": [
    {"id": 1, "name": "Pegasus 41", "brand": "Nike", "category": "running", "gender": "men",
     "price": 13990, "old_price": 15990, "sizes": ["40","41","42"], "image_url": "/images/shoe_01.png",
     "in_stock": true, "rating": 4.5, "reviews_count": 2, "is_favorite": false}
  ],
  "total": 40, "limit": 5, "offset": 0
}
```

### 3.1. Листинг подключения к API

Фрагмент класса `ApiService` (`frontend/lib/services/api_service.dart`):

```dart
Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
  final request = http.Request(method, _uri(path, query))..headers.addAll(_headers);
  if (body != null) request.body = jsonEncode(body);

  http.Response response;
  try {
    final streamed = await _client.send(request).timeout(AppConfig.requestTimeout);
    response = await http.Response.fromStream(streamed);
  } on TimeoutException {
    throw const ApiException('Сервер не отвечает. Проверьте подключение и попробуйте снова.');
  } on http.ClientException {
    throw const ApiException('Нет соединения с сервером. Убедитесь, что сервер запущен.');
  }
  ...
}

Future<ShoePage> getShoes({ShoeFilter filter = const ShoeFilter(), int offset = 0,
    int limit = AppConfig.pageSize, bool favorites = false, bool deleted = false}) async {
  final query = {...filter.toQuery(), 'limit': '$limit', 'offset': '$offset',
      if (favorites) 'favorites': '1', if (deleted) 'deleted': '1'};
  final data = await _send('GET', '/shoes', query: query) as Map<String, dynamic>;
  final items = (data['items'] as List).map((e) => Shoe.fromJson(e)).toList();
  return ShoePage(items, data['total'] as int);
}
```

---

## 4. Примеры экранных форм и диалогов

Скриншоты — в `docs/screenshots/`.

| Рисунок | Файл | Описание |
|---|---|---|
| Приветственный экран | `01_splash.png` | Анимированный логотип, «беговые дорожки» на фоне, индикатор загрузки. В это время восстанавливается сохранённый сеанс |
| Экран входа | `02_login.png` | Логин, пароль (с кнопкой показа), без выбора роли. Подсказка с тестовыми аккаунтами |
| Анимация загрузки | `03_loading.png` | Мерцающие скелетоны карточек до появления данных |
| Каталог (клиент) | `04_catalog_client.png` | Поиск, категории (ChoiceChip), сортировка (DropdownButton), кнопка фильтров, колокольчик |
| Избранное | `05_favorite_added.png`, `24_favorites.png` | Добавление в избранное сердечком и список избранного |
| Подгрузка по 5 | `06_pagination.png` | Следующие 5 моделей подгружаются при прокрутке или кнопкой «Показать ещё» |
| Фильтры | `07_filters.png` | SegmentedButton, RadioListTile, CheckboxListTile, RangeSlider, ChoiceChip, SwitchListTile |
| Меню клиента | `08_drawer_client.png` | Drawer: каталог, избранное, мои заявки, профиль, выход |
| Карточка модели | `09_detail.png`, `12_detail_reviews.png` | Фото, цена, скидка, выбор размера, описание, характеристики, отзывы |
| Диалог бронирования | `10_booking_dialog.png`, `11_booking_sent.png` | Телефон и комментарий, сообщение об успешной отправке |
| Уведомление администратора | `13_admin_catalog_bell.png` | На колокольчике появилась цифра, значок подсвечивается и покачивается |
| Заявки клиентов | `14_admin_orders.png`, `15_approve_dialog.png` | Новые заявки выделены, кнопки «Одобрить»/«Отклонить», диалог комментария |
| Меню администратора | `16_drawer_admin.png` | Заявки (со счётчиком), корзина, пользователи |
| Корзина | `17_trash.png` | Удалённые модели, восстановление и окончательное удаление |
| Пользователи | `18_users.png` | Блокировка клиентов переключателем |
| Редактирование / добавление | `19_edit_form.png`, `20_add_form.png` | Форма модели: DropdownButton, RadioListTile, FilterChip, Switch |
| Профиль администратора | `21_profile_admin.png` | Статистика, выбор темы |
| Ответ клиенту | `22_client_bell.png`, `23_client_orders.png` | Клиент получил уведомление: заявка одобрена |
| Тёмная тема | `26_profile_dark.png`, `27_catalog_dark.png`, `28_detail_dark.png` | Тема сохраняется в SharedPreferences |

---

## 5. Примеры результатов работы программы (сценарии)

1. **Вход.** Пользователь вводит логин и пароль → `POST /api/auth/login` → сервер возвращает токен и роль → токен сохраняется в SharedPreferences, открывается интерфейс клиента или администратора.
2. **Просмотр каталога.** Загружаются первые 5 моделей (`limit=5&offset=0`), во время загрузки показываются скелетоны. При прокрутке вниз или по кнопке «Показать ещё» подгружаются следующие 5.
3. **Поиск и фильтрация.** Ввод текста (с задержкой 450 мс) или выбор фильтров перезагружает список с новыми параметрами запроса. Количество активных фильтров показывается на кнопке.
4. **Избранное.** Нажатие на сердечко → `POST /api/favorites/{id}`. Избранное хранится в БД и доступно после повторного входа.
5. **Бронирование и уведомление.** Клиент выбирает размер → «Забронировать» → заполняет телефон → `POST /api/orders`. У администратора в течение 8 секунд на колокольчике появляется счётчик, значок мигает. Администратор открывает заявки и одобряет/отклоняет → клиент получает уведомление об ответе. Диаграмма последовательности: `docs/diagrams/notification_sequence.png`.
6. **Добавление и редактирование модели (администратор).** Кнопка «Добавить модель» / значок карандаша → форма → «Сохранить» → `POST`/`PUT /api/shoes`.
7. **Удаление и восстановление.** Администратор удаляет модель → она попадает в корзину (`deleted = 1`) → в корзине её можно восстановить или удалить навсегда.
8. **Блокировка пользователя.** Администратор выключает переключатель у клиента → все сеансы клиента завершаются, при попытке входа выводится «Ваш аккаунт заблокирован администратором». Список заблокированных сохраняется в БД.

---

## 6. Примеры защиты программы (обработка ошибок и исключений)

### 6.1. Валидация форм на клиенте

| Форма | Проверка | Сообщение |
|---|---|---|
| Вход | пустые поля | «Введите логин» / «Введите пароль» |
| Регистрация | логин < 3 символов, недопустимые символы | «Логин должен содержать минимум 3 символа», «Допустимы латинские буквы, цифры…» |
| Регистрация | пароль < 6 символов, пароли не совпадают | «Пароль должен содержать минимум 6 символов», «Пароли не совпадают» |
| Модель | цена ≤ 0, старая цена ≤ цены, нет размеров | «Укажите цену больше 0», «Должна быть больше цены», «Выберите хотя бы один размер» |
| Бронирование | размер не выбран, телефон < 10 цифр | «Сначала выберите размер», «Введите корректный номер телефона» |

Поля цены и веса принимают только цифры (`FilteringTextInputFormatter.digitsOnly`). При выходе из формы с несохранёнными изменениями показывается диалог подтверждения.

### 6.2. Обработка ошибок сети и HTTP

`ApiService._send()` перехватывает `TimeoutException` (сервер не ответил за 10 с), `ClientException` (сервер недоступен) и коды 4xx/5xx, превращая их в `ApiException` с понятным текстом. Экраны показывают ошибку через SnackBar или экран `ErrorState` с кнопкой «Повторить». При коде 401 или блокировке пользователь автоматически разлогинивается (`onSessionExpired`).

```dart
try {
  await context.read<AuthProvider>().login(_login.text, _password.text);
} on ApiException catch (e) {
  setState(() => _error = e.message); // «Неверный логин или пароль»
}
```

### 6.3. Обработка ошибок на сервере

| Ситуация | Код | Сообщение |
|---|---|---|
| Неверный логин/пароль | 401 | Неверный логин или пароль |
| Нет токена / истёк | 401 | Требуется авторизация / Сессия истекла, войдите снова |
| Пользователь заблокирован | 403 | Ваш аккаунт заблокирован администратором |
| Клиент вызывает метод администратора | 403 | Действие доступно только администратору |
| Логин уже занят | 409 | Пользователь с таким логином уже существует |
| Повторная заявка на тот же размер | 409 | Вы уже забронировали эту модель в таком размере… |
| Модели нет в наличии | 409 | Модели нет в наличии |
| Некорректные данные модели | 400 | Текст конкретной ошибки валидации |
| Некорректный JSON / id | 400 | Некорректный JSON в теле запроса / Некорректный идентификатор |
| Внутренняя ошибка | 500 | Внутренняя ошибка сервера (детали пишутся в лог) |

```go
if blocked == 1 {
    writeError(w, http.StatusForbidden, "Ваш аккаунт заблокирован администратором")
    return
}
```

Пароли хранятся в виде хэша bcrypt, SQL-запросы параметризованы (защита от SQL-инъекций), размер тела запроса ограничен 1 МБ, при быстрой смене фильтров устаревшие ответы отбрасываются (счётчик `_generation` в `PagedShoeList`). Корректность API проверяется автотестами `backend/api_test.go`.

---

## 7. Программная документация

### 7.1. Файлы проекта

См. раздел «Структура проекта» в `README.md`.

### 7.2. Библиотеки

| Библиотека | Назначение |
|---|---|
| `flutter`, `flutter_localizations` | UI-фреймворк, русская локализация стандартных виджетов |
| `http` | HTTP-запросы к REST API |
| `shared_preferences` | Локальное хранилище (токен, тема, история поиска) |
| `provider` | Управление состоянием (ChangeNotifier) |
| Go `net/http`, `database/sql`, `encoding/json` | HTTP-сервер, работа с БД, JSON (стандартная библиотека) |
| `modernc.org/sqlite` | Драйвер SQLite на чистом Go (не требует компилятора C) |
| `golang.org/x/crypto/bcrypt` | Хэширование паролей |

### 7.3. Инструкция пользователя

1. Запустить сервер и открыть приложение (см. `README.md`, «Быстрый запуск»).
2. После приветственного экрана войти как `client / client123` (клиент) или `admin / admin123` (администратор), либо зарегистрироваться.
3. Клиент: искать и фильтровать модели, открывать карточку, добавлять в избранное, оставлять отзывы, выбирать размер и бронировать. Ответ магазина приходит на колокольчик и в «Мои заявки».
4. Администратор: добавлять и редактировать модели, удалять их в корзину и восстанавливать, обрабатывать заявки (колокольчик), блокировать клиентов, смотреть статистику в профиле.
5. Тема оформления меняется в «Профиль и настройки».

---

## Список используемой литературы

1. Документация Flutter [Электронный ресурс]. — URL: https://docs.flutter.dev
2. Документация языка Dart [Электронный ресурс]. — URL: https://dart.dev/guides
3. Пакет provider [Электронный ресурс]. — URL: https://pub.dev/packages/provider
4. Пакет shared_preferences [Электронный ресурс]. — URL: https://pub.dev/packages/shared_preferences
5. Пакет http [Электронный ресурс]. — URL: https://pub.dev/packages/http
6. Документация языка Go [Электронный ресурс]. — URL: https://go.dev/doc
7. Пакет net/http [Электронный ресурс]. — URL: https://pkg.go.dev/net/http
8. Документация SQLite [Электронный ресурс]. — URL: https://www.sqlite.org/docs.html
9. Material Design 3 [Электронный ресурс]. — URL: https://m3.material.io
10. Донован А., Керниган Б. Язык программирования Go. — М.: Вильямс, 2018. — 432 с.
11. Napoli M. Beginning Flutter: A Hands On Guide to App Development. — Wiley, 2019. — 528 p.

---

## Листинг программы

Весь исходный код находится в каталогах `backend/*.go` (~1800 строк) и `frontend/lib/**/*.dart` (~5100 строк). Так как общий объём превышает 3000 строк, в отчёт рекомендуется включить основные файлы: `api_service.dart`, `paged_shoe_list.dart`, `home_screen.dart`, `notification_bell.dart`, `auth_provider.dart`, `app_styles.dart`, `auth.go`, `shoes.go`, `orders.go`, `db.go`.
