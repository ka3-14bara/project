# Разработка инфраструктуры для сайта, включающую мониторинг, сбор логов и резервное копирование основных данных - `Латыпов Данияр`

## Содержание
* [Сайт](#Сайт)
* [Мониторинг](#Мониторинг)
* [Логи](#Логи)
* [Сеть](#Сеть)
* [Резервное-копирование](#Резервное-копирование)
* [Развертывание ВМ и ПО](#развертывание-приожений-на-серверах)

### Сайт <a name="Сайт"></a>

Две виртуаьные машины созданы в различных зонах для достижения распределённости и отказоустойчивости:

* ru-central1-a
* ru-central1-b

На вебсервера установлено следующее ПО:

* NGINX в качестве вебсервера
* Filebeat для сбора и передачи логов в elasticsearch
* Zabbix-agent для сбора и отправки метрик на zabbix-server

Виртуальные машины не обладают внешним IP для уменьшения площади атаки извне. Для доступа к вебсерверам используется бастион хост, находящийся во внешнем контуре сети. Доступ к веб-порту обеспечивается через балансировщик yamdex cloud, который одновременно занимается и балансировкой трафика не вебсервера.

Настройки балансировщика:

1. Созданы целевые ресурсы:
   <img src = "img/ya-cloud/ya-load_balance-target_groups.png" width = 100%>
2. Создана группа бекенда:
   <img src = "img/ya-cloud/ya-load_balance-backend_groups.png" width = 100%>
3. Создан HTTP роутер:
   <img src = "img/ya-cloud/ya-load_balance-http_router.png" width = 100%>
4. Создан балансировщик и listener:
   <img src = "img/ya-cloud/ya-load_balance-balancer.png" width = 100%>

Карта балансировки выглядит следующим образом:

   <img src = "img/ya-cloud/ya-load_balance-balance_map.png" width = 100%>

Сайт доступен по следующей ссылке:
   http://51.250.39.49:80

<img src = "img/webpage-serv1.png" width = 100%>
<img src = "img/webpage-serv2.png" width = 100%>

Конфигурационный файл filebeat:
```
filebeat.inputs:
  - type: log
    enabled: true

    paths:
      - /var/log/nginx/access.log

  - type: log
    enabled: true

    paths:
      - /var/log/nginx/error.log

output.elasticsearch:
  hosts: ["10.120.0.23:9200"]
  protocol: http
  index: "WEBS-%{+yyyy.MM.dd}"
  username: "elastic"
  password: "changed_password"

setup.kibana:
  host: ["10.122.0.30:5601"]

setup.ilm.enabled: false

setup.template.name: "filebeat"
setup.template.pattern: "filebeat"
setup.template.settings:
  index.number_of_shards: 1
```

---

### Мониторинг <a name="Мониторинг"></a>

Мониторинг осуществляется при помощи Zabbix. Для zabbix-server создана отдельная виртуальная машина, находящаяся во внешнем контуре сети. На данную машину отправляются метрики с хостов вебсерверов.

Конфигурационный файл zabbix-server:
```
LogFile=/var/log/zabbix/zabbix_server.log

LogFileSize=0

PidFile=/run/zabbix/zabbix_server.pid

SocketDir=/run/zabbix

DBName=zabbix

DBUser=zabbix

DBPassword=changed_password

SNMPTrapperFile=/var/log/snmptrap/snmptrap.log

Timeout=4

FpingLocation=/usr/bin/fping

Fping6Location=/usr/bin/fping6

LogSlowQueries=3000

StatsAllowedIP=127.0.0.1

EnableGlobalScripts=0
```

Для сбора метрик настроены хосты в веб интерфейсе: 
   <img src = "img/zabbix/zabbix-monitoring-hosts.png" width = 100%>

Созданы следующие дашборды:
1. Главная страница с основной информацией:
   <img src = "img/zabbix/zabbix-dashboard-main.png" width = 100%>
2. Страница с информацией о дисковых системах:
   <img src = "img/zabbix/zabbix-dashboard-disks1.png" width = 100%>
   <img src = "img/zabbix/zabbix-dashboard-disks2.png" width = 100%>
3. Страница с информацией о сети:
   <img src = "img/zabbix/zabbix-dashboard-network1.png" width = 100%>
4. Страница с информацией об ОЗУ:
   <img src = "img/zabbix/zabbix-dashboard-ram.png" width = 100%>
5. Страница с информацией о ЦПУ:
   <img src = "img/zabbix/zabbix-dashboard-cpu.png" width = 100%>

---

### Логи <a name="Логи"></a>

Сбор логов осушествляется в 3 этапа:
1. Сбор логов на хостах.
2. Отправка логов на сервер elasticsearch.
3. Обработка логов на сервере elasticsearch.

Далее для визуализации данных сервер Kibana запрашивает и получает данные с сервера elasticsearch. Для визуализации данных необходимо:
1. Создать шаблон считываемых индексов:
   <img src = "img/kibana/kibana-index_pattern.png" width = 100%>
   1.1 Под этот шаблон подпадают следующие индексы:
   <img src = "img/kibana/kibana-index_managment.png" width = 100%>
2. Далее необходимо проанализировать какие поля присутствуют в логах:
   <img src = "img/kibana/kibana-index_pattern-index_fields.png" width = 100%>
3. На основании полей построить дашборд:
   <img src = "img/kibana/kibana-dashboard.png" width = 100%>

В дашборде присутствует диаграмма, в которой показывается разделение логов по типу лога и по типу хоста. А также диаграмма кривой количества запросов к каждой машине ко времени.

Конфигурационный файл elasticsearch:
```
cluster.name: websites

path.data: /var/lib/elasticsearch

path.logs: /var/log/elasticsearch

network.host: 0.0.0.0

discovery.type: single-node

xpack.security.enabled: true
xpack.license.self_generated.type: basic

```

Конфигурационный файл kibana:
```
server.name: "kibana"
server.host: 10.122.0.30
server.port: 5601
server.publicBaseUrl: "http://84.201.178.82:5601"

elasticsearch.hosts: 
  - http://10.120.0.23:9200

elasticsearch.username: "elastic"
elasticsearch.password: "changed_password"

logging.dest: /var/log/kibana/kibana.log

```

---

### Сеть <a name="Сеть"></a>

Принципиальная схема взаимодействия хостов в сети:
<img src = "img/net-structure-global.png" width = 100%>

Хосты web1, web2, elasticsearch не имеют прямого доступа к внешней сети. Все общение происходит через сервера посредники - bastion (NAT gateway) и балансировщик. Для этого бы настроен gateway через bastion host и таблица маршрутизации:
   <img src = "img/ya-cloud/ya-vpc-gateway.png" width = 100%>
   <img src = "img/ya-cloud/ya-vpc-routes.png" width = 100%>

Подключение к хостам по ssh происходит через бастион в качестве jump сервера и используется fqdn имена виртуальных машин в зоне:
```
ssh -J bastion@51.250.19.231 admin@web1.ru-central1.internal
```
Схема сети VPC в yandex cloud:
   <img src = "img/ya-cloud/ya-vpc-structure.png" width = 100%>

Подсети VPC в yandex cloud:
   <img src = "img/ya-cloud/ya-vpc-subnets.png" width = 100%>

Также были настроены различные группы безопасности предоставляющие доступ только к необходимым портам: 
   <img src = "img/ya-cloud/ya-vpc-security_groups.png" width = 100%>

Подробнее о каждой группе:
1. Elastic
   <img src = "img/ya-cloud/ya-vpc-security_groups-elastic.png" width = 100%>
2. For_web
   <img src = "img/ya-cloud/ya-vpc-security_groups-for_web.png" width = 100%>
3. http
   <img src = "img/ya-cloud/ya-vpc-security_groups-http.png" width = 100%>
4. kibana
   <img src = "img/ya-cloud/ya-vpc-security_groups-kibana.png" width = 100%>
5. ssh
   <img src = "img/ya-cloud/ya-vpc-security_groups-ssh.png" width = 100%>
6. zabbix
   <img src = "img/ya-cloud/ya-vpc-security_groups-zabbix.png" width = 100%>

---

### Резервное копирование <a name="Резервное-копирование"></a>

Резервное копирование производилось встроенным инструментом yandex backup cloud.

Была настроена политика бэкапов:
   <img src = "img/ya-cloud/ya-backup-backup_politics.png" width = 100%>

В качестве вида бэкапов выбраны инкрементные бэкапы. После этого все виртуальные машины были подкючены к этой политике резервного копирования, после чего был снят первый (полный) бэкап:
   <img src = "img/ya-cloud/ya-backup-backups.png" width = 100%>

---

### Развертывание серверов и приожений на серверах <a name="Развертывание"></a>

Развертывание приложений происходило при помощи terraform и API yandex cloud. Этот файл также лежит в этой ветке.

Развертывание приложений происходило при помощи ansible, который был установлен на bastion host. Этот файл также лежит в этой ветке.

---
