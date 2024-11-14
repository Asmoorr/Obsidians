## Вставка данных в таблицу

```sql
INSERT INTO таблица(поле1, поле2) VALUES (значение1, значение2);
```

```sql
INSERT INTO genre (name_genre) 
VALUES ('Роман');
```

```sql
INSERT INTO book(title, author, price, amount) VALUES ("Белая гвардия", "Булгаков М.А.", 540.5, 5);
```

## Выборка всех данных из таблицы

```sql
SELECT * FROM book;
```

## Выборка отдельных столбцов

```sql
SELECT author, title, price FROM book;
```

## Присвоение новых имен столбцам при формировании выборки

```sql
SELECT title as Название, author as Автор FROM book;
```

## Выборка данных с созданием вычисляемого столбца

```sql
SELECT title, author, price, amount, price * amount AS total FROM book;
```

## Математические функции
``
```css
CEILING(x)
ROUND(x, k)
FLOOR(x)
DEGREES(x)
PI()
POWER(x, y)
RADIANS(x)
ABS(x)
SQRT(x)
```
## Логическая функция

```sql
IF(логическое_выражение, выражение_1, выражение_2)
```

```sql
SELECT title, amount, price, IF(amount<4, price*0.5, price*0.7) AS sale FROM book;
```
### Вложенные условия

```sql
SELECT title, amount, price,
ROUND(IF(amount < 4, price * 0.5, IF(amount < 11, price * 0.7, price * 0.9)), 2) AS sale,
FROM book;
```
## Выборка данных по условию where

```sql
SELECT title, price FROM book WHERE price < 600;
```

```sql
SELECT title, author, price * amount AS total
FROM book
WHERE price * amount > 4000;
```
## Выборка данных, операторы BETWEEN, IN

```sql
SELECT title, amount 
FROM book
WHERE amount BETWEEN 5 AND 14;
```
## Выборка данных с сортировкой

```sql
SELECT author, title, amount AS Количество
FROM book
WHERE price < 750
ORDER BY author ASC, amount DESC;
```
## Выборка данных, оператор LIKE

```sql
SELECT title 
FROM book
WHERE title LIKE 'Б%';
```

```sql
SELECT title FROM book 
WHERE title LIKE "_____"
```

```sql
SELECT title FROM book 
WHERE title LIKE "______%";
```

```sql
SELECT title FROM book 
WHERE title LIKE "_% и _%" /*отбирает слово И внутри названия */
    OR title LIKE "и _%" /*отбирает слово И в начале названия */
    OR title LIKE "_% и" /*отбирает слово И в конце названия */
    OR title LIKE "и" /* отбирает название, состоящее из одного слова И */
```
## Выбор уникальных элементов столбца

```sql
SELECT DISTINCT author FROM book;
```

## Выборка данных, групповые функции SUM и COUNT

```sql
SELECT author, sum(amount), count(amount)
FROM book
GROUP BY author;
```
## Выборка данных, групповые функции MIN, MAX и AVG

```sql
SELECT author, MIN(price) AS min_price
FROM book
GROUP BY author;
```

## Выборка данных, групповые функции MIN, MAX и AVG

```sql
SELECT
    author,
    MIN(price) as Минимальная_цена,
    MAX(price) as Максимальная_цена,
    AVG(price) as  Средняя_цена
FROM book
GROUP BY author
```
## Выборка данных c вычислением, групповые функции

```sql
SELECT author, SUM(price * amount) AS Стоимость FROM book GROUP BY author;
```

```sql
SELECT
    author,
    ROUND(SUM(price * amount), 2) as Стоимость,
    ROUND(( (SUM(price * amount) * 0.18) / 1.18 ), 2) as НДС,
    ROUND(( SUM(price * amount) / 1.18 ), 2) as Стоимость_без_НДС
FROM book
GROUP BY author
```
## Вычисления по таблице целиком
``
```sql
SELECT
    ROUND(MIN(price), 2) as Минимальная_цена,
    ROUND(MAX(price), 2) as Максимальная_цена,
    ROUND(AVG(price), 2) as Средняя_цена
FROM book
```

## Порядок выполнения запроса

[Полная статья](https://www.dev-notes.ru/articles/devops/understand-the-sql-execution-order/)

```sql
SELECT
customers.name, 
COUNT(order_id) as Total_orders,
SUM(order_amount) as total_spent
FROM customers
JOIN orders ON customers.id = orders.customer_id
WHERE order_date >= '2023-01-01'
GROUP BY customers.name
HAVING total_spent >= 1000
ORDER BY customers.nameLIMIT 100;
```

![[Pasted image 20240918160552.png]]
