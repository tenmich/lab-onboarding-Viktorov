# Анализ потоков данных (DFA) функции `process_transaction`

## Исходный код (с нумерацией строк)

```python
 1  def process_transaction(user_id, amount, db_connection):
 2      log_entry = "Start processing"
 3
 4      if amount > 0:
 5          status = "approved"
 6          balance = get_balance(user_id)
 7          new_balance = balance - amount
 8          update_balance(user_id, new_balance)
 9
10      log_entry = "Transaction finished with status: " + status
11
12      file = open("audit_log.txt", "w")
13      file.write(log_entry)
14
15      return status
```

## Цепочки Def-Use

Переменная: `user_id`
Def: строка 1 (параметр функции)
Use: строка 6 (`get_balance(user_id)`), строка 8 (`update_balance(user_id, ...)`)

Переменная: `amount`
Def: строка 1 (параметр функции)
Use: строка 4 (условие `amount > 0`), строка 7 (`balance - amount`)

Переменная: `db_connection`
Def: строка 1 (параметр функции)
Use: нет — параметр нигде не используется

Переменная: `log_entry`
Def: строка 2 (`log_entry = "Start processing"`)
Use: нет — значение перезаписывается на строке 10, не будучи прочитанным
Def: строка 10 (`log_entry = "Transaction finished ..." + status`)
Use: строка 13 (`file.write(log_entry)`)

Переменная: `status`
Def: строка 5 (`status = "approved"`) — только при `amount > 0`
Use: строка 10 (использование в конкатенации строки), строка 15 (`return status`)

Переменная: `balance`
Def: строка 6 (`balance = get_balance(user_id)`)
Use: строка 7 (`balance - amount`)

Переменная: `new_balance`
Def: строка 7 (`new_balance = balance - amount`)
Use: строка 8 (`update_balance(user_id, new_balance)`)

Переменная: `file`
Def: строка 12 (`file = open("audit_log.txt", "w")`)
Use: строка 13 (`file.write(log_entry)`)
Освобождение (`file.close()`): отсутствует

## Сводная таблица

| Переменная    | Def (строка)    | Use (строка) | Замечание                                   |
|---------------|-----------------|--------------|---------------------------------------------|
| `user_id`     | 1               | 6, 8         | —                                           |
| `amount`      | 1               | 4, 7         | —                                           |
| `db_connection` | 1             | —            | неиспользуемый параметр                     |
| `log_entry`   | 2               | —            | **Dead Store**: перезаписан на строке 10    |
| `log_entry`   | 10              | 13           | —                                           |
| `status`      | 5 (только если `amount > 0`) | 10, 15 | **не определена** на пути `amount <= 0` |
| `balance`     | 6               | 7            | —                                           |
| `new_balance` | 7               | 8            | —                                           |
| `file`        | 12              | 13           | **Resource Leak**: нет `close()`            |

## Выявленные дефекты

### Дефект 1. Использование неинициализированной переменной
Переменная `status` определяется только внутри ветки `if amount > 0` (строка 5).
Если `amount <= 0` (например, 0 или отрицательная сумма), путь выполнения
обходит строку 5 и сразу попадает на строку 10, где `status` читается.
Результат — исключение `UnboundLocalError: local variable 'status' referenced
before assignment`. На этом пути до строки 10 не существует ни одной
точки def для `status` — это и выявляет анализ достигающих определений
(reaching definitions).

### Дефект 2. Мертвое присваивание (Dead Store)
На строке 2 переменной `log_entry` присваивается `"Start processing"`, но на
любом пути выполнения это значение перезаписывается на строке 10 до
первого чтения. Анализ живых переменных (live variables) показывает, что
после строки 2 `log_entry` «мертва». Значит, сообщение о начале обработки
никогда не попадает в журнал аудита.

### Дефект 3. Утечка ресурса (Resource Leak)
На строке 12 открывается файловый дескриптор `file`, но нигде не вызывается
`file.close()` и не используется `with`. Если `file.write` выбросит исключение,
или функция вызывается часто, дескрипторы накапливаются, а данные могут
не сброситься на диск. Кроме того, режим `"w"` при каждом вызове
перезаписывает журнал аудита — предыдущие записи теряются (для журнала нужен
режим `"a"`).
