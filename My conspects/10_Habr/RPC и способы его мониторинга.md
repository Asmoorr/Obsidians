---
title: "RPC и способы его мониторинга"
source: "https://habr.com/ru/companies/rvision/articles/716656/"
author:
published: 2023-02-16
created: 2026-09-09
description: "Всем привет! Мы — команда исследователей‑аналитиков киберугроз в компании R‑Vision. Одной из наших задач является исследование возможных альтернативных и дополнительных источников..."
tags:
  - "clippings"
---
![](https://habrastorage.org/r/w1560/getpro/habr/upload_files/e15/887/9f1/e158879f1ac385501e00dc55b8674e2b.png)

Всем привет!

Мы — команда исследователей‑аналитиков киберугроз в компании R‑Vision. Одной из наших задач является исследование возможных альтернативных и дополнительных источников событий для более точного детектирования атак.

И сегодня мы рассмотрим тему мониторинга **RPC** (Remote Procedure Call, удаленный вызов процедур)*,* а также разберем возможные варианты логирования **Microsoft Remote Procedure Call** ([MS‑RPC](https://learn.microsoft.com/en-us/windows/win32/com/microsoft-rpc)), связанного с актуальными и популярными на сегодняшний день атаками.

Но преждем чем приступить, предлагаем ознакомиться с базовой работой RPC и с тем, на каких механизмах она основывается. В дальнейшем это поможет нам понять, какую информацию необходимо собирать и отслеживать при детектировании атак с использованием удаленного вызова процедур.

## Что такое RPC?

**Remote Procedure Call или «удаленный вызов процедур»** представляет собой технологию межпроцессного взаимодействия [IPC](https://learn.microsoft.com/en-us/windows/win32/ipc/interprocess-communications#using-rpc-for-ipc). Она позволяет программам вызывать функции и процедуры удаленно таким образом, как‑будто они представлены локально. В среде Windows используется проприетарный протокол от Microsoft — [MS‑RPC](https://learn.microsoft.com/en-us/windows/win32/com/microsoft-rpc), который является производным от технологии **DCE/RPC** (Distributed Computing Environment/ Remote Procedure Calls). Для упрощения понимания мы будем называть **MS‑RPC** просто **RPC.**

Службы RPC используются во множестве процессов в операционных системах Windows. Например, с их помощью можно удалённо изменять значения в реестре, создавать новые задачи и сервисы. На вызовах RPC построена значимая часть работы Active Directory: функции аутентификации в домене, репликация данных и многие другие вещи — список грандиозно большой.

В виду того, что RPC используется в Windows практически во всех процессах, по понятным причинам она является предметом особого интереса для атакующих. В тоже время RPC фигурирует в большом количестве популярных и опасных атак. К ним относится [PetitPotam](https://support.microsoft.com/en-gb/topic/kb5005413-mitigating-ntlm-relay-attacks-on-active-directory-certificate-services-ad-cs-3612b773-4043-4aa9-b23d-b87910cd3429), с чьей помощью можно произвести атаку типа Relay на машинный аккаунт контроллера домена. Еще одна атака — DCSync, позволяющая скомпрометировать всех пользователей в домене при наличии учетной записи с высокими привилегиями. Кроме того, в арсенале атакующих есть еще и фреймворк [Impacket](https://github.com/SecureAuthCorp/impacket), который может задействовать RPC для отправки вредоносных команд на удаленный сервер.

Все это говорит нам о важности понимания механизмов работы RPC, а также о необходимости её мониторинга.

## Механизмы работы RPC

Изучение механизмов работы RPC мы начнем с краткого разбора сетевого трафика, поскольку протокол RPC в первую очередь является сетевым. На рисунке 1 мы видим подключение к удалённой машине: оно начинается с **Bind** запроса (выделен красным), после которого фигурирует второй **Bind** запрос (выделен синим). Первый используется для подключения к службе Endpoint Mapper (EPM), про него мы поговорим дальше. Второй инициирует подключение к самому RPC интерфейсу. После прохождения аутентификации устанавливается сессия, а уже дальше осуществляется вызов нужной функции и возвращение результата.

![Рисунок 1. Вызов функции на удалённой машине с помощью RPC](https://habrastorage.org/r/w1560/getpro/habr/upload_files/f73/1cf/dd7/f731cfdd7fd4498a26576ab06a3a61bc.png)

Рисунок 1. Вызов функции на удалённой машине с помощью RPC

Эволюция, конечно, могла бы остановиться здесь, если бы для RPC применялись только протоколы TCP и UDP, но в Microsoft пошли немного дальше и применяют так называемую [последовательность из протоколов](https://learn.microsoft.com/en-us/windows/win32/rpc/protocol-sequence-constants). К ней мы вернемся позднее, а сейчас рассмотрим, что такое **EPM**.

## Endpoint Mapper

Одним из важных механизмов взаимодействия с RPC сервисами является служба **Endpoint Mapper (EPM),** расположенная на стороне сервера. Её главная задача помочь определить параметры дальнейшего подключения к нужному сервису для клиента. Сам EPM, как это ни странно, является таким же RPC сервисом, использующим для транспорта порты TCP/135 или TCP/593 ([RPC over HTTP](https://learn.microsoft.com/en-us/windows/win32/rpc/remote-procedure-calls-using-rpc-over-http)).

![Рисунок 2. Служба *RPC Endpoint Mapper на устройстве](https://habrastorage.org/r/w1560/getpro/habr/upload_files/aff/148/994/aff148994e0318352d8c9536d03d9ac8.png)

Рисунок 2. Служба \*RPC Endpoint Mapper на устройстве

EPM‑cервис расположен на каждой Windows машине и содержит базу зарегистрированных RPC интерфейсов. За каждый из интерфейсов чаще всего отвечает свой исполняемый файл или динамически подгружаемая библиотека ([DLL](https://learn.microsoft.com/ru-ru/troubleshoot/windows-client/deployment/dynamic-link-library)). Посмотреть список всех доступных интерфейсов можно с помощью утилиты [*rcpdump.py*](http://rcpdump.py/) из упомянутого нами ранее фреймворка **Impacket.**

На рисунке 3 приведен пример вывода по одному из доступных интерфейсов.

![Рисунок 3. Пример интерфейса, выводимый командой rpcdump.py](https://habrastorage.org/r/w1560/getpro/habr/upload_files/a7d/45b/55d/a7d45b55d317cf8222d30b4faa415091.png)

Рисунок 3. Пример интерфейса, выводимый командой rpcdump.py

Здесь мы можем увидеть:

- Название интерфейса: *Netlogon Remote Protocol*;
- Библиотеку провайдера, отвечающего за нужные нам функции: *netlogon.dll*;
- Уникальный идентификатор интерфейса: *UUID*;
- Список точек подключения к данному интерфейсу, которые записываются в формате:
```powershell
"значение, отражающее последовательность протоколов":хост[порт]Объяснить с
```

Отметим в приведенном выше интерфейсе два протокола:

- *ncalrpc* — отражает [локальное использование](https://learn.microsoft.com/en-us/windows/win32/rpc/selecting-a-protocol-sequence) по протоколу *LRPC*;
- *ncacn\_np* — отражает подключение по именованному каналу [Named Pipes](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipes) (NPs). В связи с этим у него вместо порта указан путь.

Может возникнуть вполне резонный вопрос: всегда ли нужно обращаться к EPM? Нет, не всегда, так как существуют статические точки подключения, остающиеся неизменными. К ним, например, относится NPs `\pipe\lsass`.

Можно также посмотреть на RPC интерфейсы процессов не только снаружи, но и «изнутри». Они выглядят примерно [так](https://gist.github.com/enigma0x3/2e549345e7f0ac88fad130e2444bb702).

#### Что дальше?

После того как клиент определил куда он будет дальше подключаться, в процесс вступает сериализация данных. Если клиентом является Windows система, то эту работу будет выполнять компонент NDR ([Network Data Representation](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rpce/1644e4e6-1340-4d9a-9258-c62ff87e9e55#gt_9ebf9540-2c31-43bc-bc56-4a932faabf2d)). Он также отвечает за десериализацию данных со стороны RPC сервера. После чего данные попадают в качестве аргументов функции и другой информации для вызова этой самой функции в DLL библиотеку, ответственную за определённый RPC функционал. На финальном этапе функция выполняется, а её вывод передаётся обратно в RPC для отправки клиенту.

## Протоколы в RPC

Разобравшись как работает RPC, подробнее изучим протоколы, которые активно эксплуатируются в интерфейсах RPC и, следовательно, доступны атакующему. И первым мы рассмотрим протокол **Named Pipes (NPs).**

#### Named Pipes

Данный протокол следует принципам передачи данных через чтение и запись: используя NPs можно записывать, а также сразу читать наименование и аргументы функций. Более того, это даже можно делать одновременно. NPs проще всего представлять в виде файлов: в Windows взаимодействие с ними происходит с помощью функций [**CreateFile**](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilea), [**ReadFile**](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile), [**WriteFile**](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-writefile), что в некоторой степени намекает нам на схожесть этих технологий. NPs выполняет роль интеграционного слоя между RPC и другими служебными компонентами.

Со стороны клиента NPs можно представить как точки подключения для выполнения какого‑то конкретного функционала. Например, точка подключения `\pipe\svcctl` направлена на управление службами на конечном устройстве. Однако Microsoft не всегда следует такому разделению. Так, при подключении к `\pipe\lsass` можно вызвать функции EFS сервиса, если передать корректный UUID при выполнении `bind` [запроса](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-efsr/403c7ae0-1a3a-4e96-8efc-54e79a2cc451).  
На стороне сервера, на который происходит обращение, выполняется импорт библиотеки, отвечающий за EFS (`C:\Windows\System32\efslsaext.dll`) в процесс `lsass`. Стоит отметить, что у EFS существует свой собственный интерфейс `\pipe\efsr`.  
Также EFS функционал может быть вызван с помощью других точек, например через `samr` или `lsarpc`, за каждым из которых стоит процесс `lsass`. Это в свою очередь наталкивает на мысль о некоторой «универсальности» процессов — интерфейсов, так как каждый процесс может импортировать нужную библиотеку и существует возможность вызывать функции любых других сервисов.

Перейдем к следующему протоколу — SMB.

## SMB

Если отойти немного от протокола RPC и посмотреть на NPs отдельно, мы обнаружим, что NPs может вполне заменить RPC, так как первый исполняет функции удаленно даже без второго. Для этих целей он использует протокол **SMB (Server Message Block)**. При этом фактически SMB нужен только для доступа к служебной директории `IPC$`, аббревиатура которой расшифровывается как Interprocess Communication**.** Через эту «папку» можно читать, записывать, но только NPs, что вполне в духе SMB, и вызывать таким образом удаленные функции.

## LRPC

До этого мы говорили про протоколы, которые используются в удаленным вызове, но есть и локальный вариант RPC — **протокол LRPC**, у которого существует две трактовки: **Local RPC или Lightweight RPC**. Этот протокол предназначен только для локальных вызовов. Конечно, при использовании подключений по NPs или RPC на адрес `localhost` эффект будет тот же. Более того, некоторые программы так и делают, но для локальных вызовов LRPC работает куда быстрее и он удобнее в использовании. В выводе [*rpcdump.py*](http://rpcdump.py/) мы его видели «зашифрованным» под `ncalrpc`. При этом LRPC работает поверх ALPC — еще одного протокола, о котором будет сказано чуть позже.  
Но сначала про LPC.

## LPC

**LPC (Local Procedure Call)** — также отвечает за механизм общения процессов в одной и той же системе. Данный протокол является недокументированным и используется (использовался) только внутри самой Microsoft. БОльшую часть информации об этом протоколе мы можем узнать исходя из работ реверс специалистов. Сторонний софт использует его не напрямую, а взаимодействует через документированный LRPC.

А теперь вернемся к ALPC.

## ALPC

LPC — это все же устаревшая технология и в явном виде уже не используется. На смену ей пришел **ALPC (Advanced Local Procedure Call)**, являющийся асинхронным и также недокументированным протоколом. Работает он по принципу клиент‑серверной модели. В качестве сервера выступает процесс, принимающий соединения на определённый порт. Порт для подключения открывается с помощью функции `NtAlpcCreatePort`. Любой процесс имеет возможность подключиться к этому порту в качестве клиента, используя функцию `NtAlpcConnectPort`. Один «процесс‑сервер» может взаимодействовать сразу с несколькими клиентами одновременно.

## DCOM

Рассмотрим последний протокол, который фигурирует в RPC — **DCOM**, чья аббревиатура расшифровывается как **Distributed COM**. Фактически эта технология вызова COM‑интерфейсов удалённо. Тут нет больших отличий со стороны трафика, но есть различия в механизме вызова удаленных функций. DCOM не вызывает функции напрямую, а сначала инициализирует COM‑объект, функционал которого будет использовать. Концептуально это похоже на NPs с их разделением функционала на отдельные именованные каналы. Если рассматривать алгоритм общения клиента и сервера, то здесь не так много отличий от «чистого» RPC, но есть два исключения — вызов функций ***ISystemActivator*** и [***IDispatch***](https://learn.microsoft.com/en-us/windows/win32/api/oaidl/nn-oaidl-idispatch)**.**

Для вызова функции определённого COM объекта, такой объект сначала нужно вызвать, чтобы затем он «запустился»: загрузился в оперативную память и был доступен для работы. В локальном мире этим занимается COM интерфейс [***IUnknown***](https://learn.microsoft.com/en-us/windows/win32/api/unknwn/nn-unknwn-iunknown). Он позволяет также узнать функции неизвестных COM интерфейсов для работы с ними.

При работе с DCOM ту же функцию выполняет *ISystemActivator*, позволяя обратиться к неизвестным DCOM интерфейсам, являющимися по сути теми же COM объектам, и работать с ними. *ISystemActivator* вызывается каждый раз при новом DCOM подключении.

![Рисунок 4. Пример, как выглядит DCOM в Wireshark](https://habrastorage.org/r/w1560/getpro/habr/upload_files/535/64b/664/53564b66488fdcf3addaaea303667cef.png)

Рисунок 4. Пример, как выглядит DCOM в Wireshark

Также *IUnknown* интерфейс дает возможность вызывать и другие функции COM объекта напрямую, фактически сводя всю работу с COM объектами до одной лишь функции *IUnknown* интерфейса. Тоже самое выполняет и интерфейс *IDispatch* для DCOM, позволяя выполнять любую функцию в мире DCOM через него. Поэтому, если мы взглянем на трафик, то увидим сначала вызов *ISystemActivator*, а потом только лишь обращения к *IDispatch*, вне зависимости от того какую DCOM функцию использует клиент.

Рассказывая про ALPC, мы упомянули, что эта технология используется только локально. Но это, конечно, не совсем правда, так как ALPC задействован чуть ли не во всех компонентах Windows. Поэтому, так или иначе, любое действие, в том числе и удалённое, будет прямо или косвенно применять ALPC. Это особенно интересно в контексте DCOM, потому что он напрямую использует ALPC на локальной машине, при этом будучи вызванным удалённым пользователем.

## Схема вариантов RPC-подключений

Подведем итог вышесказаного в виде схемы вариантов подключения к удалённой машине, отражающей возможные пути со стороны клиента, которые в том числе доступны и для атакующего. Как видим из рисунка 5, все не так просто.

![Рисунок 5. Возможные способы подключения к RPC серверу](https://habrastorage.org/r/w1560/getpro/habr/upload_files/fe6/f45/6a0/fe6f456a07bad23d0fbbdf645a9f3a32.png)

Рисунок 5. Возможные способы подключения к RPC серверу

## Способы мониторинга

Разобравшись с вариантами RPC‑подключений, и, как следствие, с потенциально возможными действиями со стороны атакующего, рассмотрим, варианты мониторинга, которые нам может предоставить сама операционная система: **ETW, журналы безопасности, SACL, RPC Filtering, RPC Firewall и сетевой трафик.**

И начнем с технологии, на базе которой строится функционал для логирования событий в операционной системе Windows — **Event Tracing for Windows (ETW).**

## Event Tracing for Windows

**Event Tracing for Windows** или сокращено [ETW](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/event-tracing-for-windows--etw-) имеет множество, так называемых, провайдеров, которых в ОС более нескольких тысяч. Они позволяют отслеживать через события как отдельные технологии, так и конкретные процессы. Часть провайдеров формируют вполне понятные для обыденного пользователя события, другая же, бОльшая часть, используется исключительно только самой Microsoft для отладки.

ETW предоставляет возможность смотреть события вызовов RPC функций через стандартную оснастку Event Viewer. ETW провайдеры, связанные с RPC, представлены в таблице ниже.

Провайдеры, связанные с RPC

| **Название** **провайдера** | **GUID** |
| --- | --- |
| Microsoft-Windows-RPC | {6AD52B32-D609-4BE9-AE07-CE8DAE937E39} |
| Microsoft-Windows-RPC-Events | {F4AED7C7-A898-4627-B053-44A7CAA12FCD} |
| Microsoft-Windows-RPC-FirewallManager | {F997CD11-0FC9-4AB4-ACBA-BC742A4C0DD3} |
| Microsoft-Windows-RPC-Proxy-LBS | {272A979B-34B5-48EC-94F5-7225A59C85A0} |
| Microsoft-Windows-RPCSS | {D8975F88-7DDB-4ED0-91BF-3ADF48C48E0C} |

Саму настройку событий можно посмотреть здесь.

Настройка просмотра событий

Как ранее говорилось, мы можем увидеть события в оснастке Event Viewer. Для этого нам необходимо включить отображение события отладки (View Show → Analytic and Debug Log ), после чего появятся доступные к просмотру журналы событий, в том числе и RPC.

![Рисунок 6 Призыв RPC логов в Event Viewer](https://habrastorage.org/r/w1560/getpro/habr/upload_files/951/c57/ce7/951c57ce7011ba28fb72d8a28982d3ac.png)

Рисунок 6 Призыв RPC логов в Event Viewer

События, связанные с RPC будут доступны по пути *Application and Services Logs → Microsoft → Windows → RPC*, в журнале *Debug*.

## Разбор событий

Теперь проведем разбор события на одном из примеров, показанных на рисунке 7.

![Рисунок 7. Пример лога из ETW](https://habrastorage.org/r/w1560/getpro/habr/upload_files/bcd/535/b03/bcd535b03a258305f50908fcbc2d8223.png)

Рисунок 7. Пример лога из ETW

В данном событии мы видим информацию об RPC запросе к именованному каналу `\pipe\lsass` по интерфейсу UUID ***12 345 778–1234-abcd‑ef00–0 123 456 789ac*** и с номером процедуры **(ProcNum / OpCode) — 34**.

Переведем это событие с «машинного» языка: здесь мы фиксируем обращение к интерфейсу [SAMR](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-samr/0aee1c31-ec40-4633-bb56-0cf8429093c0) (Security Account Manager Remote). Атрибут Endpoint имеет значение `\pipe\lsass`, потому что SAMR интерфейс содержит в поле Named Pipe значение `\pipe\lsass` и конечное подключение производится к нему. Также виден протокол номер 2, что трактуется как NPs.

| Поле | «Сырое» значение | Расшифровка |
| --- | --- | --- |
| InterfaceUuid | 2345778-1234-abcd-ef00-0123456789ac | SAMR |
| ProcNum | 34 | SamrOpenUser |
| Protocol | 2 | Named Pipe |

Стоит отметить, что некоторые NPs, такие как **srvsvc** и **wkssvc** динамически меняют свои GUID номера и, как следствие, их нельзя идентифицировать по одному общеизвестному GUID, но это можно сделать через поле Endpoint, которое четко указывает на соответствующий интерфейс.

![Рисунок 8. Событие подключения к srvsvc](https://habrastorage.org/r/w1560/getpro/habr/upload_files/c1e/75b/9be/c1e75b9be19bde90d864f4dcca345c00.png)

Рисунок 8. Событие подключения к srvsvc

Рассмотрим другой пример: при выполнении атаки **DCShadow,** мы можем увидеть следующее событие в журнале (рисунок 9).

![Рисунок 9. RPC через TCP протокол в деталях](https://habrastorage.org/r/w1560/getpro/habr/upload_files/6f2/5f8/1ff/6f25f81ff08cdcd572b5a3aa4a2e0eb4.png)

Рисунок 9. RPC через TCP протокол в деталях

На этом рисунке можно увидеть подключение к интерфейсу DRSUAPI, который имеет GUID ***e3 514 235–4b06–11d1-ab04–00c04fc2dcd2*,** протокол (Protocol) 1 или его человеко‑читаемое имя ‑TCP, а также IP‑адрес, с которого было совершено подключение. Как и в предыдущем примере здесь отображен номер процедуры (ProcNum) — 3, который [трактуется](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-drsr/58f33216-d9f1-43bf-a183-87e3c899c410) как репликация обновления из NC реплики.

## Журнал безопасности

Политики аудита позволяют нам настроить сбор событий, которые относятся в Windows к событиям безопасности. Они фиксируют обращения к NPs через SMB и «папку» `IPC$`. Сразу отметим минус такого подхода: если, к примеру, клиент будет обращаться к NPs через *RPC*, а не `IPC$`, то в событиях мы этого не увидим.

`IPC$` — это системная папка общего доступа, с ее помощью мы можем логировать события подключения через политику Detailed File Share. Пример возможного события указан на рисунке 10 ниже.

![Рисунок 10. Detailed File Share показывает кто подключается](https://habrastorage.org/r/w1560/getpro/habr/upload_files/f47/9f4/7d8/f479f47d8df139d43a98518f03d63b97.png)

Рисунок 10. Detailed File Share показывает кто подключается

События безопасности будут сформированы, если подключиться к NPs с именем `srvsvc`, как нам и показывает второй лог в разделе ***Сведение об общем ресурсе (Share Information)* → *Относительное имя конечного объекта (Relative Target Name)*.** Как вы могли заметить, в данном событии не фиксируется номер процедуры (ProcNum), по которому можно было бы отследить что происходит.

![Рисунок 11. Detailed File Share показывает не только "кто" подключается, но и "куда"!](https://habrastorage.org/r/w1560/getpro/habr/upload_files/f18/8cf/2af/f188cf2aff7d41deafd55e5bc2816d32.png)

Рисунок 11. Detailed File Share показывает не только "кто" подключается, но и "куда"!

## System Access Control List

Для NPs также можно включить **SACL** ([System Access Control List](https://learn.microsoft.com/en-us/windows/win32/secauthz/sacl-access-right)), чтобы фиксировать любые действия с ними. Пример события указан на рисунке 12.

![Рисунок 12. Событие 4656 - что даёт нам SACL](https://habrastorage.org/r/w1560/getpro/habr/upload_files/dcb/14a/724/dcb14a72401eadb72bb017ea21884303.png)

Рисунок 12. Событие 4656 - что даёт нам SACL

Эти события практически идентичны тем, что мы получаем от политики аудита Detailed FileShare. Поэтому гораздо проще включить политику, чем выставлять SACLповсеместно. Но включение SACL может помочь отслеживать подключение там, где оно происходит напрямую по RPC, при этом совершенно минуя SMB.

Выставлять SACL на NPs — не самая тривиальная задача, так как она не переживает перезагрузку машины и требует написания собственного кода, тем не менее является одним из вариантов проведения мониторинга.

Мы подготовили небольшой код, который может менять SACL на NPs.

Код C++ для выставления SACL

```cpp
#include <aclapi.h>
#include <iostream>

BOOL SetPrivilege(
    HANDLE hToken,          // access token handle
    LPCTSTR lpszPrivilege,  // name of privilege to enable/disable
    BOOL bEnablePrivilege   // to enable or disable privilege
)
{
    TOKEN_PRIVILEGES tp;
    LUID luid;

    if (!LookupPrivilegeValue(
        NULL,            // lookup privilege on local system
        lpszPrivilege,   // privilege to lookup 
        &luid))        // receives LUID of privilege
    {
        printf("LookupPrivilegeValue error: %u\n", GetLastError());
        return FALSE;
    }

    tp.PrivilegeCount = 1;
    tp.Privileges[0].Luid = luid;
    if (bEnablePrivilege)
        tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    else
        tp.Privileges[0].Attributes = 0;

    // Enable the privilege or disable all privileges.

    if (!AdjustTokenPrivileges(
        hToken,
        FALSE,
        &tp,
        sizeof(TOKEN_PRIVILEGES),
        (PTOKEN_PRIVILEGES)NULL,
        (PDWORD)NULL))
    {
        printf("AdjustTokenPrivileges error: %u\n", GetLastError());
        return FALSE;
    }

    if (GetLastError() == ERROR_NOT_ALL_ASSIGNED)

    {
        printf("The token does not have the specified privilege. \n");
        return FALSE;
    }

    return TRUE;
};

BOOL SetSecurityPrivilage(BOOL bEnablePrivilege) {
    LPCTSTR lpszPrivilege = L"SeSecurityPrivilege";
    HANDLE hToken;
    // Open a handle to the access token for the calling process. That is this running program
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, &hToken)) {
        printf("OpenProcessToken() error %u\n", GetLastError());
        return FALSE;
    }
    // Call the user defined SetPrivilege() function to enable and set the needed privilege
    if (!SetPrivilege(hToken, lpszPrivilege, bEnablePrivilege)) {
        printf("Failed to adjust Privilege\n");
        return FALSE;
    }
    return TRUE;
};

wchar_t *convertCharArrayToLPCWSTR(const char* charArray)
{
    wchar_t* wString=new wchar_t[4096];
    MultiByteToWideChar(CP_ACP, 0, charArray, -1, wString, 4096);
    return wString;
}

int main(int argc, char* argv[])
{

    LPCWSTR pipeName = NULL;
    LPWCH groupName = NULL;
    BOOL clrSACL = FALSE;

    if (argc <= 1)
    {
        printf("%s\n", "Help page, do it like this:\nprog.exe -path \\\\.\\pipe\\lsass -name Everyone\nOr to clear the SACL use -clr\nIt sets both success and failure audit, by now it works only with pipes");
        return 0;
    }

    // Argument parsing
    for (int i = 0; i < argc; ++i)
    {
        if (strcmp(argv[i], "-path") == 0)
        {
            pipeName = convertCharArrayToLPCWSTR(argv[i + 1]);
        }
        if (strcmp(argv[i], "-name") == 0)
        {
            groupName = convertCharArrayToLPCWSTR(argv[i + 1]);
        }
        if (strcmp(argv[i], "-clr") == 0)
        {
            clrSACL = TRUE;
        }
    }

    // Get Priv
    if (!SetSecurityPrivilage(TRUE)) {
        printf("Try to launch with Admin rights\n");
        return 1;
    }

    // Open the pipe with ACCESS_SYSTEM_SECURITY, the only right which allows to edit SACL
    HANDLE hPipe = CreateFile(pipeName, ACCESS_SYSTEM_SECURITY, 0, NULL, OPEN_EXISTING, NULL, NULL);

    if (hPipe == INVALID_HANDLE_VALUE)
    {
        printf("%s\n%d\n", "Incorrect handle", GetLastError());
        return 1;
    }

    // Just clear SACL and get out
    if (clrSACL)
    {
        if (SetSecurityInfo(hPipe, SE_KERNEL_OBJECT, SACL_SECURITY_INFORMATION, NULL, NULL, NULL, NULL) != ERROR_SUCCESS)
        {
            printf("%s\n%d\n", "SetSecurityInfo", GetLastError());
            return 1;
        }
        printf("%s\n", "[+] Successufully cleared SACL");
        return 0;
    }

    PACL pOldSACL = NULL;
    PSECURITY_DESCRIPTOR pPipeSD = NULL;
    
    // Just need an already existing SACL to be able to edit it
    if (GetSecurityInfo(hPipe, SE_KERNEL_OBJECT, SACL_SECURITY_INFORMATION, NULL, NULL, NULL, &pOldSACL, &pPipeSD) != ERROR_SUCCESS)
    {
        printf("%s\n%d\n", "GetSecurityInfo", GetLastError());
        return 1;
    }

    // Init TRUSTEE, which is basically SACL stucture
    TRUSTEE trusteeSACL[1];
    trusteeSACL[0].TrusteeForm = TRUSTEE_IS_NAME;
    trusteeSACL[0].TrusteeType = TRUSTEE_IS_GROUP;
    trusteeSACL[0].ptstrName = groupName;
    trusteeSACL[0].MultipleTrusteeOperation = NO_MULTIPLE_TRUSTEE;
    trusteeSACL[0].pMultipleTrustee = NULL;

    EXPLICIT_ACCESS explicit_access_listSACL[1];
    ZeroMemory(&explicit_access_listSACL[0], sizeof(EXPLICIT_ACCESS));

    // Here I buit SACL
    explicit_access_listSACL[0].grfAccessMode = SET_AUDIT_SUCCESS;
    // I wasn't able to made two right at the same time.
    //explicit_access_listSACL[0].grfAccessMode = SET_AUDIT_FAILURE;

    // If your change GENERIC_ALL, to something else, like ACCESS_SECURITY, then SACL will audit only handles with ACCESS_SECURITY rights.
    explicit_access_listSACL[0].grfAccessPermissions = GENERIC_ALL;
    
    explicit_access_listSACL[0].grfInheritance = NO_INHERITANCE;
    explicit_access_listSACL[0].Trustee = trusteeSACL[0];

    PACL pNewSACL = NULL;
    PACL pNewSACLFal = NULL;

    // This is not ideal, but I dont know how to unite SET_AUDIT_SUCCESS and SET_AUDIT_FAILURE and I dont want to waste much time on it.

    if (SetEntriesInAcl(1, explicit_access_listSACL, pOldSACL, &pNewSACL) != ERROR_SUCCESS)
    {
        printf("%s\n%d\n", "SetEntriesInAcl", GetLastError());
        return 1;
    }
    
    explicit_access_listSACL[0].grfAccessMode = SET_AUDIT_FAILURE;

    if (SetEntriesInAcl(1, explicit_access_listSACL, pNewSACL, &pNewSACLFal) != ERROR_SUCCESS)
    {
        printf("%s\n%d\n", "SetEntriesInAcl", GetLastError());
        return 1;
    }

    if (SetSecurityInfo(hPipe, SE_KERNEL_OBJECT, SACL_SECURITY_INFORMATION, NULL, NULL, NULL, pNewSACLFal) != ERROR_SUCCESS)
    {
        printf("%s\n%d\n", "SetSecurityInfo", GetLastError());
        return 1;
    }

    printf("%s\n", "[+] Successufully set SACL");

    LocalFree(pNewSACL);
    LocalFree(pNewSACLFal);
    LocalFree(pOldSACL);
    CloseHandle(hPipe);
}Объяснить с
```

Также для работы SACL должны быть включены следующие политики аудита:

```powershell
Доступ к объектам | Object Access
--> Объект-задание (Успех и сбой)  | Kernel Object Success and Failure (Success and Failure)
--> Работа с дескриптором (Успех и сбой) | Handle Manipulation Success and Failure () (Success and Failure)

// Дополнительная информация, не работает без Объект-заданиеОбъяснить с
```

## RPC Filtering

Интересной альтернативой событиям, поставляемым через ETW провайдеры, может быть [**RPC Filtering**](https://Networks%5D\(https://github.com/zeronetworks/\)). Решение устанавливается на конечное устройство и основано на возможностях межсетевого экрана самой ОС. Из плюсов — мы имеем возможность просмотра события в привычном нам Event Viewer. Но как и в случае с SACL, требуется предварительное выполнение настройки. Можно воспользоваться двумя способами:

- Утилитой **netsh.exe;**
- Использовать **WinAPI.**

В качестве примера возьмем RPC‑интерфейс, который связан с ранее упомянутой атакой PetitPotam — EFS.

```powershell
rpc filter
add rule layer=um actiontype=permit audit=enable
add condition field=if_uuid matchtype=equal data=c681d488-d850-11d0-8c52-00c04fd90f7e
add filter
Объяснить с
```

Установить правило можно с помощью утилиты `netsh`:

```
netsh -f rpcauditrule.txtОбъяснить с
```

При выполнении обращения был получен следующий лог:

```json
<REDACTED>
LogName=Security
EventCode=5712
EventType=0
ComputerName=<REDACTED>
SourceName=Microsoft Windows security auditing.
Type=Information
RecordNumber=39145598
Keywords=Audit Success
TaskCategory=RPC Events
OpCode=Info
Message=A Remote Procedure Call (RPC) was attempted.

Subject:
    SID:            S-1-5-7
    Name:            ANONYMOUS LOGON
    Account Domain:        NT AUTHORITY
    LogonId:        0x95FDD924

Process Information:
    PID:            716
    Name:            lsass.exe

Network Information:
    Remote IP Address:    0.0.0.0
    Remote Port:        0

RPC Attributes:
    Interface UUID:        {c681d488-d850-11d0-8c52-00c04fd90f7e}
    Protocol Sequence:    ncacn_np
    Authentication Service:    0
    Authentication Level:    0Объяснить с
```

Этот метод является прекрасной альтернативой ETW. Он не только генерирует удобный лог, но и имеет бОльшую информативность (например, наличие поля *Subject*). Также у такого метода нет каких‑либо технических ограничений по сбору событий, это все тот же *EventLog*.

## RPC Firewall

Коллеги из [Zero Networks](https://github.com/zeronetworks/) предлагают идти дальше. С помощью решения [RPC‑firewall](https://github.com/zeronetworks/rpcfirewall), которое устанавливается на конечное устройство, они рассматривают возможность не только мониторинга, но блокировки конкретных RPC методов, чего нельзя сделать через стандартный Windows Firewall. Дополнительным бонусом предлагается заметно улучшенный журнал событий, так как в нем будет присутствовать информация о номере процедуры (ProcNum/ OpNum).

![Рисунок 13 - событие из журнала мониторинга, созданное RPC-firewall, при попытке выполнения атаки DCSync](https://habrastorage.org/r/w1560/getpro/habr/upload_files/f96/186/502/f96186502b8442c1f92ae6352d1ad1fe.png)

Рисунок 13 - событие из журнала мониторинга, созданное RPC-firewall, при попытке выполнения атаки DCSync

Закончив с уровнем операционной системы, перейдем к сетевому.

## Сетевой уровень

Сетевой трафик весьма информативен. При его мониторинге мы можем увидеть не только подключение к `IPC$` ресурсу, но и сразу номер процедуры (ProcNum/ OpNum). Это очень полезно, так как у нас появляется вся нужная информация о клиенте, а именно:

1. Кто именно клиент (так как мы видим *Bind* подключение);
2. Куда клиент подключается;
3. Какие именно функции выполняет клиент;
4. Как на них реагирует сервер (Ошибка или Успех).

Интереснее всего это получать информацию о выполняемых клиентом функциях, поскольку такие данные могут предоставить только ETW, RPC Firewall и трафик.

На рисунке 14 приведен пример NPs ориентированного подключения, где виден номер операции, в нашем случае это 64, в атрибуте ***SAMR → Operation***.

![Рисунок 14. Как подключение Named Pipe выглядит в трафике](https://habrastorage.org/r/w1560/getpro/habr/upload_files/e2a/714/94a/e2a71494a13674962f95c6916ef2f8b2.png)

Рисунок 14. Как подключение Named Pipe выглядит в трафике

Таким же образом можно просматривать и поведение TCP‑ориентированных подключений. В примере была запущена репликация домен‑контроллера, где мы можем увидеть RPC запрос вместе с номером процедуры (в примере на рисунке 15 он равен *5*) и интерфейсом подключения (в примере это DRSUAPI).

![Рисунок 15. Operation == DRSUAPI_REPLICA_ADD](https://habrastorage.org/r/w1560/getpro/habr/upload_files/319/a51/2fc/319a512fc9ac9fc9bc15a700633fe8f3.png)

Рисунок 15. Operation == DRSUAPI\_REPLICA\_ADD

## Шифрование

Тема шифрования RPC‑трафика до этого в статье не затрагивалась, тем не менее оно есть. Шифрование может добавить проблем при мониторинге трафика в сети, так как расшифровывать его сложно, да и никто не любит это делать.

Трафик можно разделить на 2 вида:

- на инкапсулированный в TCP/ UDP/ HTTP и не предполагающий никакого шифрования кроме того, что реализовано в самом RPC протоколе;
- на использование NPs через SMB протокол.

Посмотрим как это выглядит в Wireshark (рисунок 16). В RPC трафике видно NPs, к которому обращается клиент, а также вызываемую функцию, поскольку эти данные не зашифрованы, а зашифрованы только аргументы к функции. Напомним, что любая функция RPC имеет свой OpNum, статически закреплённый за каждой из них. Так функции можно точно идентифицировать.

![*Рисунок 16. Использование Named Pipes через RPC напрямую.*](https://habrastorage.org/r/w1560/getpro/habr/upload_files/80d/ebd/b72/80debdb72ba810b0233dc9de4580c93a.png)

\*Рисунок 16. Использование Named Pipes через RPC напрямую.\*

С SMB так не получится. Если используется SMB версии 3, то весь трафик целиком будет зашифрован и ничего нельзя будет увидеть. SMB3 поддерживается всеми современными версиями Windows и злоумышленник без проблем может использовать его, чтобы скрыть свои действия.

![Рисунок 17. Использование Named Pipes через SMB протокол.](https://habrastorage.org/r/w1560/getpro/habr/upload_files/ad8/dda/abb/ad8ddaabb706642930834454f56d4297.png)

Рисунок 17. Использование Named Pipes через SMB протокол.

Поэтому если есть необходимость мониторить RPC взаимодействие, то можно это сделать через протокол SMB, либо если нужно выбрать один источник для мониторинга всего и сразу, то трафик лучше не использовать.

## Заключение

В этой статье мы разобрали механизмы работы RPC, протоколы его интерфейсов и основные способы мониторинга удаленного вызова функций. Определенно, при сравнении всех трёх подходов логирования для мониторинга фаворитом будет являться ETW. Но в частных случаях, когда, например, точно известно об ограниченных возможностях злоумышленника и его неспособности использовать TCP‑ориентированное подключение, существует вариант применения политик аудита. В случае, если можно провести мониторинг трафика, такой способ имеет шанс стать альтернативой ETW и другим средствам логирования. Но здесь важно помнить о возможности его шифрования, если атакующий использует SMB.

| Метод логирования | Информативность | Простота настройки |
| --- | --- | --- |
| ETW | + | + |
| Журналы безопасности | +/- | + |
| SACL | + | \- |
| Сетевой трафик | + | \- |

## Схема источников логов

Ниже представлена схема, показывающая возможности атакующего при подключении к сервису RPC и каким образом можно cобирать события по каждому из вариантов подключения.

![Рисунок 18. Схема возможностей подключения по RPC и какими логами их можно мониторить](https://habrastorage.org/r/w1560/getpro/habr/upload_files/dcf/ca0/860/dcfca0860e2d7fc18a5964dfa58833e3.png)

Рисунок 18. Схема возможностей подключения по RPC и какими логами их можно мониторить

Если у вас остались вопросы, пишите в комментариях. Надеемся, статья оказалась вам полезной!

Авторы:  
*\- Черных Кирилл ([@Ruucker](https://habr.com/users/Ruucker)), аналитик-исследователь киберугроз;*  
*\- Мавлютова Валерия (*[*@Iceflipper*](https://habr.com/ru/users/iceflipper/)*), младший аналитик-исследователь киберугроз.*

+9