# Wildcard Cert Manager

A single-file interactive Bash script for issuing and managing **wildcard Let's Encrypt certificates** via `certbot` (manual DNS-01 challenge), with automatic PFX export for IIS.

**Language / Язык:** [English](#english) · [Русский](#русский)

---

## English

### What it does

`cert.sh` is a menu-driven wrapper around `certbot` that:

- Issues/reissues wildcard certificates (`example.com` + `*.example.com`) using the DNS-01 challenge
- Keeps a list of managed domains (auto-discovered from folders or added manually)
- Shows a status table with expiry countdown and color-coded warnings (valid / expiring soon / critical / expired)
- Copies issued certificates (`fullchain.pem`, `cert.pem`, `chain.pem`, `privkey.pem`) to a configurable output folder with correct permissions
- Converts a certificate to `.pfx` (PKCS#12) for IIS, with an optional randomly generated password
- Supports English and Russian interface language, switchable at any time

### Requirements

- Linux or macOS
- `certbot`, `openssl`, `sudo`, plus standard coreutils (`date`, `id`, `tr`, `mkdir`, `cp`, `chown`, `chmod`, `seq`, `wc`)
- The script re-executes itself with `sudo` automatically if not run as root

Install on macOS:

```bash
brew install certbot openssl
```

Install on Debian/Ubuntu:

```bash
sudo apt install certbot openssl
```

### Usage

```bash
./cert.sh
```

On first run you'll be asked to choose an interface language, then guided to set your email and add your first domain. After that, the main menu offers:

1. Issue / reissue a certificate from the list
2. Add a new domain
3. Convert a certificate to PFX for IIS
4. Refresh the table
5. Settings (email, output folder, language)
6. Exit

### Configuration & generated files

The script creates the following files next to itself — they are **not** meant to be committed and are excluded via `.gitignore`:

| File | Purpose |
|---|---|
| `cert.conf` | Saved settings: email, output folder, UI language |
| `domains.conf` | List of managed domains, one per line |
| `<domain>/` | Auto-discovered domain folders (also picked up from the output folder) |

You can override paths via environment variables: `EMAIL`, `UI_LANG`, `OUTPUT_DIR`, `DOMAINS_FILE`, `CONFIG_FILE`, `CERTBOT_BIN`.

### Notes

- Certificates are issued via the **manual DNS-01 challenge** — you'll be prompted to add a `_acme-challenge.<domain>` TXT record to your DNS during issuance.
- Output files land in `~/ssl/<domain>/` by default (configurable in Settings).
- The `.pfx` password is shown once and not stored anywhere — save it immediately.

---

## Русский

### Что делает скрипт

`cert.sh` — это интерактивная оболочка над `certbot` с меню, которая:

- Выпускает/перевыпускает wildcard-сертификаты (`example.com` + `*.example.com`) через DNS-01 challenge
- Хранит список управляемых доменов (автоматически обнаруживает папки или добавляет вручную)
- Показывает таблицу статусов с обратным отсчётом до истечения и цветовой индикацией (действует / скоро истекает / критично / истёк)
- Копирует выпущенные сертификаты (`fullchain.pem`, `cert.pem`, `chain.pem`, `privkey.pem`) в настраиваемую папку вывода с правильными правами доступа
- Конвертирует сертификат в `.pfx` (PKCS#12) для IIS, с опциональной генерацией случайного пароля
- Поддерживает русский и английский интерфейс, язык можно переключить в любой момент

### Требования

- Linux или macOS
- `certbot`, `openssl`, `sudo`, а также стандартные утилиты coreutils (`date`, `id`, `tr`, `mkdir`, `cp`, `chown`, `chmod`, `seq`, `wc`)
- Если скрипт запущен не от root, он автоматически перезапустит себя через `sudo`

Установка на macOS:

```bash
brew install certbot openssl
```

Установка на Debian/Ubuntu:

```bash
sudo apt install certbot openssl
```

### Использование

```bash
./cert.sh
```

При первом запуске нужно будет выбрать язык интерфейса, затем указать email и добавить первый домен. После этого главное меню предложит:

1. Выпустить / перевыпустить сертификат из списка
2. Добавить новый домен
3. Конвертировать сертификат в PFX для IIS
4. Показать таблицу заново
5. Настройки (email, папка вывода, язык)
6. Выход

### Конфигурация и генерируемые файлы

Скрипт создаёт рядом с собой следующие файлы — они **не** предназначены для коммита и исключены через `.gitignore`:

| Файл | Назначение |
|---|---|
| `cert.conf` | Сохранённые настройки: email, папка вывода, язык интерфейса |
| `domains.conf` | Список управляемых доменов, по одному на строку |
| `<домен>/` | Автоматически обнаруженные папки доменов (также ищутся в папке вывода) |

Пути можно переопределить через переменные окружения: `EMAIL`, `UI_LANG`, `OUTPUT_DIR`, `DOMAINS_FILE`, `CONFIG_FILE`, `CERTBOT_BIN`.

### Примечания

- Сертификаты выпускаются через **ручной DNS-01 challenge** — во время выпуска нужно будет добавить TXT-запись `_acme-challenge.<домен>` в DNS.
- По умолчанию файлы сохраняются в `~/ssl/<домен>/` (можно изменить в Настройках).
- Пароль от `.pfx` показывается один раз и больше нигде не сохраняется — запишите его сразу.
