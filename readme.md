# Lab App — Terraform, Ansible, Docker Compose и Trivy

## 1. Описание проекта

Веб-приложение состоит из фронтенда и бэкенда. Оно развёртывается в Docker-контейнерах внутри виртуальной машины Ubuntu, созданной на KVM/libvirt с помощью Terraform.

Для автоматизации настройки виртуальной машины и развёртывания приложения используется Ansible. Для проверки Docker-образов на известные уязвимости настроен CI workflow в GitHub Actions с использованием Trivy.

**Используемые технологии:**

- **KVM/QEMU и libvirt** — виртуализация.
- **Terraform** — создание и управление виртуальной машиной.
- **cloud-init** — первоначальная настройка Ubuntu, пользователя и SSH-доступа.
- **Ansible** — установка Docker, настройка системы и развёртывание приложения.
- **Docker Compose** — сборка и управление контейнерами.
- **Nginx** — раздача фронтенда и проксирование запросов к API.
- **FastAPI и Uvicorn** — бэкенд приложения.
- **GitHub Actions** — автоматический запуск CI при изменениях в репозитории.
- **Trivy** — сканирование Docker-образов на уязвимости системных пакетов и библиотек.
- **JSON и GitHub Actions Artifacts** — сохранение и скачивание результатов сканирования.

## 2. Архитектура

```text
Ноутбук
├── deploy.sh
│   ├── Terraform: создание/обновление VM
│   ├── Получение IP через terraform output
│   ├── Обновление ansible/inventory.ini
│   └── Запуск Ansible playbook
│
├── Terraform
│   └── KVM/libvirt
│       └── Ubuntu VM
│           ├── cloud-init
│           │   └── Первоначальная настройка Ubuntu
│           ├── Docker Engine
│           └── Docker Compose
│               ├── Frontend
│               │   └── Сборка статических файлов
│               ├── Backend
│               │   └── FastAPI + Uvicorn, порт 8000
│               └── Nginx
│                   ├── Раздача frontend
│                   ├── Проксирование /api/*
│                   └── Порт 8080 на VM
│
└── GitHub Actions
    └── Trivy image scan
        ├── Сборка frontend и backend
        ├── Загрузка образа Nginx
        ├── Сканирование трёх образов
        ├── Проверка политики безопасности
        └── Публикация JSON-отчётов

Браузер
└── http://IP_VM:8080
    └── Nginx
        ├── /       → статический frontend
        └── /api/*  → backend:8000
```

## 3. Настройка переменных Docker Compose

В корне проекта рядом с `docker-compose.yml` должен находиться файл `.env.example`. При первоначальной настройке скопируйте его в `.env`:

```bash
cp .env.example .env
```

В `docker-compose.yml` эти переменные используются для определения имён образов:

```yaml
services:
  frontend:
    image: ${FRONTEND_IMAGE:-lab-app-frontend:latest}
    # Сохраните существующие параметры build и другие настройки.

  backend:
    image: ${BACKEND_IMAGE:-lab-app-backend:latest}
    # Сохраните существующие параметры build и другие настройки.

  nginx:
    image: ${NGINX_IMAGE:-nginx:1.30-alpine}
    # Сохраните существующие настройки сервиса.
```

Имена образов в Compose должны совпадать с именами, указанными в workflow Trivy. Значения `env` в GitHub Actions переопределяют соответствующие значения `.env` во время CI.

## 4. Подготовка и ручная работа с Terraform

Terraform-файлы находятся в каталоге `terraform/`, а `deploy.sh` и `ansible/` — в корне проекта. Все команды ниже выполняются из корня репозитория. В ручных командах используется `-chdir=terraform`, чтобы Terraform работал с правильным каталогом.

При первоначальной настройке создайте файл параметров из примера:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

В `terraform/terraform.tfvars` укажите актуальные параметры VM, включая пути к SSH-ключам, память, количество vCPU и размер диска. Не перезаписывайте существующий `terraform.tfvars`, если он уже настроен.

Инициализируйте Terraform и проверьте конфигурацию:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform plan
```

Создать или обновить виртуальную машину вручную можно командой:

```bash
terraform -chdir=terraform apply
```

Перед подтверждением проверьте план предлагаемых изменений.

Посмотреть выходные значения Terraform:

```bash
terraform -chdir=terraform output
terraform -chdir=terraform output -raw vm_ipv4
terraform -chdir=terraform output -raw ssh_command
```

Проверить виртуальные машины через libvirt:

```bash
virsh -c qemu:///system list --all
```

## 5. Полное развёртывание с помощью `deploy.sh`

Скрипт `deploy.sh` объединяет создание/обновление инфраструктуры Terraform и развёртывание приложения через Ansible. Запускайте его из корня проекта. Скрипт также определяет каталог проекта по собственному расположению, поэтому его можно вызвать и из другого текущего каталога.

Перед первым запуском убедитесь, что:

- в `terraform/terraform.tfvars` настроены параметры виртуальной машины;
- в `terraform/terraform.tfvars.example` имеется пример параметров для первоначальной настройки;
- создан файл `.env` на основе `.env.example`;
- каталог `ansible/` содержит `inventory.ini` и `playbook.yml`;
- приватный SSH-ключ доступен по пути `~/.ssh/apo_lab_VM`;
- установлены Terraform и Ansible;
- на управляющем компьютере доступны необходимые Ansible-коллекции, включая `community.docker`.

```bash
./deploy.sh
```

Скрипт выполняет следующие шаги:

1. Запускает `terraform -chdir=<путь-к-проекту>/terraform init`.
2. Запускает `terraform -chdir=<путь-к-проекту>/terraform apply` и при необходимости запрашивает подтверждение.
3. Получает актуальный IP виртуальной машины командой `terraform -chdir=<путь-к-проекту>/terraform output -raw vm_ipv4`.
4. Проверяет, что IP получен и не пустой.
5. Перезаписывает `ansible/inventory.ini`, подставляя актуальный IP, пользователя `ubuntu`, путь к приватному SSH-ключу и путь к Python на VM.
6. Запускает `ansible-playbook` с обновлённым inventory.
7. Ansible устанавливает Docker, копирует файлы приложения, при изменениях пересобирает приложение и проверяет Nginx.

**Важно:** скрипт полностью перезаписывает `ansible/inventory.ini`. Если в нём есть дополнительные хосты или настройки, сохраните их отдельно либо измените скрипт. В текущем варианте путь к приватному ключу задаётся как `${HOME}/.ssh/apo_lab_VM`.

Если не хотите использовать единый сценарий, Terraform и Ansible можно запускать отдельно по инструкциям в следующих разделах.

## 6. Настройка виртуальной машины через Ansible

Ansible запускается на ноутбуке и подключается к Ubuntu по SSH. При запуске `deploy.sh` инвентарь обновляется автоматически. При ручном запуске убедитесь, что `ansible/inventory.ini` содержит актуальный IP VM.

Проверить актуальный IP:

```bash
terraform -chdir=terraform output -raw vm_ipv4
```

Проверить доступность виртуальной машины:

```bash
ansible -i ansible/inventory.ini app -m ansible.builtin.ping
```

Ожидаемый результат:

```text
lab-vm | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Проверить синтаксис playbook:

```bash
ansible-playbook \
  -i ansible/inventory.ini \
  ansible/playbook.yml \
  --syntax-check
```

Запустить развёртывание вручную:

```bash
ansible-playbook \
  -i ansible/inventory.ini \
  ansible/playbook.yml
```

Playbook выполняет следующие действия:

1. Ожидает доступности VM по SSH.
2. Устанавливает Docker Engine и плагин Docker Compose.
3. Запускает Docker и включает его автозапуск.
4. Создаёт каталог приложения `/opt/lab-app` и подкаталоги.
5. Копирует Compose-файл, исходники frontend/backend и конфигурацию Nginx.
6. Проверяет корректность Compose-конфигурации.
7. При изменении файлов вызывает handler для пересборки и запуска приложения.
8. Обеспечивает запуск сервисов `backend` и `nginx`.
9. Проверяет доступность TCP-порта 8080.
10. Выполняет HTTP-проверку главной страницы.

## 7. Проверка приложения

### 7.1. Получение IP

Из корня проекта:

```bash
VM_IP="$(terraform -chdir=terraform output -raw vm_ipv4)"
echo "$VM_IP"
```

### 7.2. Проверка главной страницы

```bash
curl --noproxy '*' -i "http://${VM_IP}:8080/"
```

Ожидаемый результат — успешный HTTP-ответ, обычно `200 OK`, и HTML фронтенда.

### 7.3. Проверка API через Nginx

```bash
curl --noproxy '*' -i "http://${VM_IP}:8080/api/hello"
```

Ожидаемый ответ:

```json
{
  "message": "Hello from backend via nginx!"
}
```

### 7.4. Проверка состояния контейнеров

```bash
ssh -i ~/.ssh/apo_lab_VM ubuntu@"${VM_IP}" \
  'cd /opt/lab-app && sudo docker compose ps'
```

Backend и Nginx должны находиться в рабочем состоянии.

Frontend-контейнер выполняет сборку статических файлов в volume `frontend_dist` и может завершиться с кодом `0`. Состояние `Exited (0)` допустимо, если файлы успешно созданы и Nginx их раздаёт.

### 7.5. Просмотр логов

```bash
ssh -i ~/.ssh/apo_lab_VM ubuntu@"${VM_IP}" \
  'cd /opt/lab-app && sudo docker compose logs --tail=100 nginx backend'
```

## 8. CI-сканирование Docker-образов с Trivy

Workflow расположен в `.github/workflows/trivy.yml`.

Он запускается автоматически при:

- отправке коммитов в ветку `main`;
- создании или обновлении pull request, направленного в `main`;
- ручном запуске через `workflow_dispatch` в GitHub Actions.

### 8.1. Этапы workflow

1. Checkout исходного кода.
2. Подготовка Docker Buildx.
3. Проверка конфигурации `docker-compose.yml`.
4. Сборка образов frontend и backend.
5. Загрузка образа Nginx.
6. Проверка имён образов и их наличия локально.
7. Сканирование каждого образа с помощью Trivy.
8. Сохранение JSON-отчётов.
9. Проверка политики безопасности.
10. Загрузка отчётов как GitHub Actions Artifacts.

Для сканирования используются три образа:

| Сервис | Имя образа |
|---|---|
| Frontend | `lab-app-frontend:latest` |
| Backend | `lab-app-backend:latest` |
| Nginx | `nginx:1.30-alpine` |

Имена в Compose-конфигурации должны совпадать с именами, которые передаются Trivy. Workflow проверяет имена и наличие образов до начала сканирования.

### 8.2. Какие уязвимости проверяет Trivy

Trivy анализирует уязвимости двух типов:

- `os` — уязвимости пакетов операционной системы внутри образа;
- `library` — уязвимости обнаруженных программных библиотек.

Отчёты включают уровни `UNKNOWN`, `LOW`, `MEDIUM`, `HIGH` и `CRITICAL`. Результаты в формате `table` отображаются в логах GitHub Actions.

### 8.3. Политика безопасности

Индивидуальные сканирования сохраняют результаты без немедленного провала только из-за обнаруженных уязвимостей. Затем отдельная задача анализирует JSON-отчёты.

**Порог блокировки CI — `HIGH` и `CRITICAL`.**

- Если такие уязвимости не найдены, проверка безопасности проходит.
- Если найдена хотя бы одна уязвимость `HIGH` или `CRITICAL`, security gate завершается с ошибкой, и job получает статус failed.
- Если сканирование или формирование обязательных отчётов не удалось, запуск также может завершиться ошибкой.

### 8.4. Сохранение отчётов

Для каждого образа формируется отдельный JSON-файл:

| Файл | Содержимое |
|---|---|
| `trivy-reports/frontend.json` | Результаты сканирования frontend |
| `trivy-reports/backend.json` | Результаты сканирования backend |
| `trivy-reports/nginx.json` | Результаты сканирования Nginx |

В конце workflow файлы загружаются как GitHub Actions Artifacts и хранятся 30 дней. Загрузка отчётов выполняется даже при провале security gate, если файлы были успешно сформированы.

Чтобы скачать отчёты:

1. Открыть репозиторий на GitHub.
2. Перейти на вкладку **Actions**.
3. Открыть нужный запуск `Trivy image scan`.
4. Найти раздел **Artifacts**.
5. Скачать архив `trivy-json-reports-...`.

JSON-отчёты можно использовать для анализа уязвимостей, автоматизированной обработки и сравнения результатов между запусками. Успешное сканирование не гарантирует полного отсутствия уязвимостей: результат зависит от состава образа, актуальности базы Trivy и возможностей обнаружения компонентов.

## 9. Результат

В проекте предусмотрена автоматизация полного цикла развёртывания приложения:

- создание Ubuntu VM через Terraform и KVM/libvirt;
- первоначальная настройка Ubuntu с помощью cloud-init;
- автоматическое получение IP-адреса Terraform и обновление Ansible inventory через `deploy.sh`;
- установка Docker и развёртывание приложения через Ansible;
- запуск контейнеров и проверка доступности приложения через Nginx;
- автоматическое сканирование образов frontend, backend и Nginx через Trivy в GitHub Actions;
- сохранение JSON-отчётов в артефактах CI;
- блокировка CI при обнаружении уязвимостей уровней `HIGH` и `CRITICAL`.

Terraform отвечает за инфраструктуру, Ansible — за настройку системы и развёртывание, Docker Compose — за контейнеры, `deploy.sh` — за объединение Terraform и Ansible в один процесс, а GitHub Actions и Trivy — за автоматизированную проверку безопасности образов.

## 10. Безопасность

Не добавлять в открытый репозиторий:

- приватные SSH-ключи;
- локальный `terraform.tfvars`, если он содержит чувствительные данные;
- `terraform.tfstate` и резервные копии состояния;
- пароли, токены и другие секреты.

Для локальных чувствительных файлов использовать `.gitignore`. В GitHub Actions хранить секреты в GitHub Actions Secrets, если они необходимы.

В текущем проекте `.env` содержит имена образов, а не секреты. Если в него будут добавлены пароли или токены, его необходимо исключить из репозитория и хранить такие значения отдельно.
