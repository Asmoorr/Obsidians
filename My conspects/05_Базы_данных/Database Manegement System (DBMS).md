
## Архитектура системы управления базами данных

Полезные ссылки:
> [!tip]
> - [подробно о PostgreSQL](https://www.interdb.jp/pg/)
> - [Про различные дейвайсы и задержку при обращении к ним]([https://www.interdb.jp/pg/](https://planetscale.com/blog/io-devices-and-latency))

![[Pasted image 20260305215810.png|450]]

### InnoDB 
is a storage engine for the database management system MySQL and MariaDB. It provides the standard ACID-compliant transaction features, along with foreign key support. It is included as standard in most binaries distributed by MySQL AB, the exception being some OEM versions. Один из "движков" MySQL

![[Pasted image 20260305221646.png]]

### структура записи переменной длины

![[Pasted image 20260305222432.png]]На этой картинке изображена **структура записи переменной длины** в базе данных. Это классическая иллюстрация из учебника «Database System Concepts» (Сильбершац, Корт, Сударшан).
#### Заголовок записи (Байты 0–11)
В начале записи находятся **указатели (смещение, длина)** для полей переменной длины. Каждая пара чисел отвечает за одно поле:
- **21, 5**: Смещение 21, длина 5. Это указывает на данные, которые начинаются с 21-го байта и занимают 5 байт (это значение 10101).
- **26, 10**: Смещение 26, длина 10. Указывает на имя Srinivasan.
- **36, 10**: Смещение 36, длина 10. Указывает на название отдела Comp. Sci..
#### Поля фиксированной длины (Байты 12–19)
Здесь хранится значение **65000**. Скорее всего, это числовой тип (например, зарплата или бюджет), который всегда занимает ровно 8 байт. Для таких полей не нужны указатели смещения, так как их позиция в структуре всегда известна заранее.
#### Битовая карта NULL (Null bitmap) (Байт 20)
Это очень важная деталь. В базах данных поля могут принимать значение NULL (пустота). Чтобы не тратить место на хранение слова "NULL", используется 1 байт, где каждый бит соответствует одному полю.
- На картинке мы видим 0000. Это значит, что все поля заполнены (ни одно не является NULL). Если бы, например, первое поле было пустым, соответствующий бит стал бы 1.
#### Область данных (Байты 21–45)
Здесь физически лежат сами данные:
- 10101 — ID сотрудника или студента.
- Srinivasan — Фамилия.
- Comp. Sci. — Факультет.

### # 1.3. Internal Layout of a Heap Table File
[исходник](https://www.interdb.jp/pg/pgsql01/03.html)

![[Pasted image 20260305223053.png]]Page layout of a heap table file.

A page within a table contains three kinds of data:

1. **heap tuple(s)** – A heap tuple is a record data itself. Heap tuples are stacked in order from the bottom of the page.  
    The internal structure of tuple is described in [Section 5.2](https://www.interdb.jp/pg/pgsql05/02.html) and [Chapter 9](https://www.interdb.jp/pg/pgsql09.html), as it requires knowledge of both concurrency control (CC) and write-ahead logging (WAL) in PostgreSQL.
    
2. **line pointer(s)** – A line pointer is 4 bytes long and holds a pointer to each heap tuple. It is also called an **item pointer**.  
    Line pointers form a simple array that plays the role of an index to the tuples. Each index is numbered sequentially from 1, and called **offset number**. When a new tuple is added to the page, a new line pointer is also pushed onto the array to point to the new tuple.
    
3. **header data** – A header data defined by the structure PageHeaderData is allocated in the beginning of the page. It is 24 byte long and contains general information about the page.  

### Buffer pool

![[Pasted image 20260305224215.png|500]]

#### Политики замещения страниц (Replacement Policies)

Когда буферный пул заполнен, а нам нужно считать новую страницу с диска, СУБД должна решить, какую старую страницу удалить из памяти.

- **LRU (Least Recently Used):** Вытесняется страница, к которой обращались дольше всего назад.

> [!important] «Последовательное наводнение» (Sequential Flooding). Если запустить полный скан огромной таблицы (SELECT *), она может вытеснить все полезные индексные страницы из кеша, хотя сами данные скана больше не понадобятся.
 
- **Clock (Алгоритм «Часы»):** Аппаратная оптимизация LRU. Каждой странице дается «бит ссылки». Когда стрелка часов проходит мимо страницы с битом 1, она сбрасывает его в 0. Если видит 0 — страница удаляется.

- **LRU-K:** Оценивает время K-го последнего обращения. Самый популярный вариант в СУБД (например, в Postgres или SQL Server). Он позволяет отличить страницы, к которым обратились один раз случайно, от тех, что реально востребованы.

- **MRU (Most Recently Used):** Удаляет самую свежую страницу. Звучит странно, но это идеально для последовательного сканирования больших таблиц: как только мы прочитали страницу в рамках скана, она нам больше не нужна.
#### Политики Steal и Force (Связь с транзакциями)
Эти политики определяют, как СУБД взаимодействует с диском в контексте надежности (ACID) и производительности.
#### **Steal Policy (Кража)**
- **Steal (Разрешено):** СУБД может вытеснить «грязную» (измененную) страницу незавершенной транзакции на диск, чтобы освободить место.       
- **No-Steal (Запрещено):** Изменения попадают на диск только после фиксации (COMMIT).
#### **Force Policy (Принуждение)**
- **Force (Обязательно):** При каждом коммите СУБД обязана записать все измененные страницы на диск.
- **No-Force (Необязательно):** СУБД не пишет страницы на диск сразу при коммите. Она делает это позже в фоновом режиме.

**Современный стандарт:** Большинство СУБД используют комбинацию **Steal + No-Force**. Это дает максимальную производительность при гарантии сохранности данных через логи (WAL).