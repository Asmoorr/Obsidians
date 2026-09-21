---
title: "CMU Intro to Database Systems (Fall 2025)"
tags:
  - cmu-15445
  - databases
  - course
aliases:
  - CMU 15-445/645 Fall 2025
---

# CMU Intro to Database Systems (Fall 2025)

Курс Carnegie Mellon University **15-445/645 Intro to Database Systems** под руководством Andy Pavlo посвящён внутреннему устройству систем управления базами данных. В нём последовательно рассматриваются реляционная модель и SQL, физическое хранение, управление памятью, индексы и фильтры, выполнение и оптимизация запросов, управление конкурентностью, журналирование и восстановление, а также распределённые базы данных.

## Основные темы

- модели данных, реляционная алгебра и современный SQL;
- страницы, кортежи, buffer pool, модели хранения и сжатие;
- хеш-таблицы, B+‑деревья, векторные и инвертированные индексы, Bloom filters;
- сортировка, агрегации, соединения и выполнение запросов;
- планирование и cost-based оптимизация;
- сериализуемость, 2PL, timestamp ordering и MVCC;
- WAL, логирование, ARIES и восстановление после сбоев;
- партиционирование, репликация и распределённое выполнение запросов.

## Официальные ссылки

- [Страница курса](<https://15445.courses.cs.cmu.edu/fall2025/>)
- [Расписание, Slides и Notes](<https://15445.courses.cs.cmu.edu/fall2025/schedule.html>)
- [YouTube-плейлист Fall 2025](<https://www.youtube.com/playlist?list=PLSE8ODhjZXjYMAgsGH-GtY5rJYZ6zjsd5>)

## Лекции

- [[01/lec01|Lecture 01 — Relational Model & Algebra]]
- [[02/lec02|Lecture 02 — Modern SQL]]
- [[03/lec03|Lecture 03 — Database Storage I]]
- [[04/lec04|Lecture 04 — Memory Management]]
- [[05/lec05|Lecture 05 — Database Storage II]]
- [[06/lec06|Lecture 06 — Storage Models & Compression]]
- [[07/lec07|Lecture 07 — Hash Tables]]
- [[08/lec08|Lecture 08 — Indexes & Filters I]]
- [[09/lec09|Lecture 09 — Indexes & Filters II]]
- [[10/lec10|Lecture 10 — Index Concurrency Control]]
- [[11/lec11|Lecture 11 — Sorting & Aggregations Algorithms]]
- [[12/lec12|Lecture 12 — Joins Algorithms]]
- [[13/lec13|Lecture 13 — Query Execution I]]
- [[14/lec14|Lecture 14 — Query Execution II]]
- [[15/lec15|Lecture 15 — Query Planning & Optimization I]]
- [[16/lec16|Lecture 16 — Query Planning & Optimization II]]
- [[17/lec17|Lecture 17 — Concurrency Control Theory]]
- [[18/lec18|Lecture 18 — Two-Phase Locking Concurrency Control]]
- [[19/lec19|Lecture 19 — Timestamp Ordering Concurrency Control]]
- [[20/lec20|Lecture 20 — Multi-Version Concurrency Control]]
- [[21/lec21|Lecture 21 — Database Logging]]
- [[22/lec22|Lecture 22 — Database Recovery]]
- [[23/lec23|Lecture 23 — Distributed Database Systems I]]
- [[24/lec24|Lecture 24 — Distributed Database Systems II]]
- [[25/lec25|Lecture 25 — Final Review + Systems Potpourri]]

> [!info] Примечание
> Для лекций 01–24 скачаны Slides и Notes. Для лекции 25 на официальной странице опубликованы Slides, но отдельного файла Notes нет.