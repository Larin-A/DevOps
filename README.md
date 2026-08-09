# DevOps инфраструктура

## Описание проекта

Инфраструктура для WordPress с системой мониторинга на базе Prometheus и Grafana.  
Все сервисы запускаются в Docker-контейнерах, конфигурации хранятся на хосте и монтируются в режиме read-only.

**Состав стека:**
- Nginx (фронтенд, проксирование)
- WordPress + PHP-FPM
- MariaDB
- Prometheus + Node Exporter
- Grafana

Используются последние стабильные версии на момент выполнения проекта. 

---

## Быстрый старт

### Автоматическое развертывание (Ansible)

Для развертывания на хосте (в частности Ubuntu 24.04) используется Ansible-плейбук.

```bash
cd ansible
ansible-playbook -i inventory.yml playbook.yml
```

Плейбук:
- устанавливает зависимости, включая Docker, Docker Compose, Git, Make, Fail2ban
- клонирует репозиторий
- выполняет `make configure`
- запускает `make up`

---

### Ручное развертывание (Makefile)

Если Ansible не используется, инфраструктура разворачивается вручную с использованием make.

Все доступные команды можно посмотреть через:

```bash
make help
```

#### 1. Настройка хоста

```bash
make configure
```

Эта команда:
- добавляет `site.local` и `metrics.local` в `/etc/hosts`
- устанавливает конфиг Fail2ban для защиты SSH

#### 2. Запуск контейнеров

```bash
make up
```

Автоматически:
- создаётся `.env` с определенным IP-адресом
- генерируется самоподписанный SSL-сертификат
- создаётся конфиг Nginx с подстановкой IP
- запускаются все контейнеры

#### 3. Доступ к сервисам

| Сервис | Адрес | Логин / пароль |
|--------|-------|----------------|
| WordPress | https://site.local | устанавливается при первом входе |
| Grafana | http://metrics.local | admin / admin (из `.env`) |
| Prometheus | http://localhost:9090 | – |

---

## Мониторинг

Prometheus собирает метрики с Node Exporter.  
Grafana автоматически подключается к Prometheus через provisioning.  
Дашборд **OS General**:
- входящий / исходящий сетевой трафик
- свободное место на диске (в процентах, а также дополнительный запрос для отображения в GiB)
- количество файловых дескрипторов

Дашборд импортируется автоматически при старте Grafana и установлен как домашний.

---

## Безопасность

### WordPress

- `/wp-admin/` – доступ только с IP, указанного в `.env` и из сети 172.16.0.0/12
- `/wp-login.php` – доступ с указанного IP и из локальных сетей (`192.168.0.0/16`, `172.16.0.0/12`)

### SSH

Настроен Fail2ban:
- 5 неудачных попыток -> бан на 10 минут
- белый список: локальные сети

---

## Управление окружениями

Реализован механизм переключения окружений через переменную `ENVIRONMENT` в `.env`.
При запуске make up автоматически создаётся docker-compose.override.yml из соответствующего шаблона.

Подготовлен шаблон для режима **`debug`** (docker-compose.override.debug.template.yml):
- открыты порты для всех сервисов
- включён дебаг-режим WordPress
- добавлены Adminer и Mailhog

```bash
make set-enviroment ENV=debug
make restart
```

Другие окружения (`dev`, `prod`) могут быть добавлены по аналогии – достаточно создать соответствующий `.template.yml`.

---

## CI/CD (GitHub Actions)

При пушах в `main` / `develop` и при создании PR в `main` запускается CI-пайплайн:

- проверка синтаксиса `docker-compose.yml`
- запуск всех контейнеров
- проверка их статуса (все должны быть `Up`)

---

## Структура проекта

```
.
├── Makefile
├── .env.template
├── docker-compose.yml
├── docker-compose.override.debug.template.yml
├── ansible/
│   ├── inventory.yml
│   ├── playbook.yml
│   └── vars.yml
├── configs/
│   ├── fail2ban/
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── dashboards.yml
│   │   │   └── os-general.json
│   │   └── datasources/
│   │       └── datasource.yml
│   ├── nginx/
│   │   ├── metrics.local.conf
│   │   ├── site.local.conf.template
│   │   └── site.local.conf (создаётся из шаблона, в .gitignore)
│   └── prometheus/
│       └── prometheus.yml
├── ssl/
│   └── .gitkeep
└── .github/workflows/
    └── ci.yml
```

---

## Принятые решения

- **Docker Compose v2** (`docker compose`) – актуальная версия
- **Самоподписанный SSL** – для тестовой среды, не требует домена и внешней верификации
- **Конфиги на хосте, монтируются read-only** – безопасно, удобно обновлять без пересборки
- **Makefile** – единая точка входа для всех операций –
- **Ansible** – автоматическое развертывание на чистом хосте, использует Makefile для снижения дублирования
- **Fail2ban** – защита SSH от брутфорса
- **Provisioning в Grafana** – datasource и дашборд настраиваются автоматически
- **Разделение окружений** – через override-файлы, шаблон для `debug` уже подготовлен
- **GitHub Actions** – автоматическая проверка синтаксиса и старта контейнеров при пушах и 


