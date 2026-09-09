---
date: 2026-05-31
tags:
  - sql
  - dml
  - insert
topic: Вставка строки с указанием всех столбцов (полный формат)
tables: employee
schema: motor_depot
---
## Условие
Добавить в базу данных информацию о новом водителе: Peter Fedorov принимается на работу на должность refueler (без квалификации). Идентификатор сотрудника — 29. Использовать полный формат ввода.

## Схема
В запросе задействована только таблица `employee`.

```mermaid
erDiagram
    employee {
        int id_employee PK
        varchar first_name
        varchar last_name
        varchar position
        varchar qualification
    }
```

## Решение

```sql
INSERT INTO employee (id_employee, first_name, last_name, position, qualification)
VALUES (29, 'Peter', 'Fedorov', 'refueler', NULL);
```

## Объяснение
- «Полный формат ввода» означает явное перечисление всех столбцов таблицы в списке после имени таблицы.
- Для сотрудника указаны: `id_employee = 29`, `first_name = 'Peter'`, `last_name = 'Fedorov'`, `position = 'refueler'`.
- Поскольку квалификация отсутствует, передаётся `NULL` (допустимо, если столбец допускает NULL).
- Значения перечислены в том же порядке, что и столбцы в списке.