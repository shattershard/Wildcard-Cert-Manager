# 🔐 Wildcard Cert Manager

An interactive script for issuing and managing **wildcard Let's Encrypt certificates** via `certbot` (manual DNS-01 challenge), with automatic PFX export for IIS.

- 🐧🍎 `cert.sh` — Bash, for Linux/macOS
- 🪟 `cert.ps1` — PowerShell, for Windows

**Language / Язык:** [English](#english) · [Русский](#русский)

---

## English

### ✨ What it does

Both scripts offer the same menu-driven workflow:

- 📜 Issues/reissues wildcard certificates (`example.com` + `*.example.com`) using the DNS-01 challenge
- 📋 Keeps a list of managed domains (auto-discovered from folders or added manually)
- 📊 Shows a status table with expiry countdown and color-coded warnings (valid / expiring soon / critical / expired)
- 📁 Copies issued certificates (`fullchain.pem`, `cert.pem`, `chain.pem`, `privkey.pem`) to a configurable output folder with correct permissions
- 🔁 Converts a certificate to `.pfx` (PKCS#12) for IIS, with an optional randomly generated password
- 🌍 Supports English and Russian interface language, switchable at any time

### 🐧🍎 Linux / macOS — `cert.sh`

#### Requirements

- `certbot`, `openssl`, `sudo`, plus standard coreutils (`date`, `id`, `tr`, `mkdir`, `cp`, `chown`, `chmod`, `seq`, `wc`)
- The script re-executes itself with `sudo` automatically if not run as root

```bash
# macOS
brew install certbot openssl

# Debian/Ubuntu
sudo apt install certbot openssl
```

#### Usage

```bash
./cert.sh
```

### 🪟 Windows — `cert.ps1`

#### Requirements

- PowerShell 5.1 (built into Windows) or PowerShell 7+
- [certbot for Windows](https://certbot.eff.org/instructions)
- `openssl` — only needed for the PFX/IIS conversion step (item 3 in the menu)

```powershell
# via Chocolatey
choco install certbot openssl

# via winget
winget install EFF.Certbot
winget install ShiningLight.OpenSSL
```

#### Usage

```powershell
.\cert.ps1
```

No Administrator shell required — by default certbot's config/work/logs folders live under `%LOCALAPPDATA%\Certbot` (override with the `CERTBOT_HOME` environment variable), and manual DNS-01 issuance doesn't need to bind to any port.

### ▶️ Main menu

1. Issue / reissue a certificate from the list
2. Add a new domain
3. Convert a certificate to PFX for IIS
4. Refresh the table
5. Settings (email, output folder, language)
0. Exit

*(`0` is always "exit" / "back" in every menu.)*

On first run you'll be asked to choose an interface language, then guided to set your email and add your first domain.

### ⚙️ Configuration & generated files

The scripts create the following files next to themselves — they are **not** meant to be committed and are excluded via `.gitignore`:

| File | Created by | Purpose |
|---|---|---|
| `cert.conf` | `cert.sh` | Saved settings: email, output folder, UI language |
| `cert.windows.conf` | `cert.ps1` | Same, kept separate so Linux/macOS and Windows settings don't clash |
| `domains.conf` | both | Shared list of managed domains, one per line |
| `<domain>/` | both | Auto-discovered domain folders (also picked up from the output folder) |

You can override paths via environment variables:

- Both scripts: `EMAIL`, `UI_LANG`, `OUTPUT_DIR`, `DOMAINS_FILE`, `CONFIG_FILE`, `CERTBOT_BIN`
- `cert.sh` only: nothing extra
- `cert.ps1` only: `CERTBOT_HOME` (default `%LOCALAPPDATA%\Certbot`)

### 📝 Notes

- Certificates are issued via the **manual DNS-01 challenge** — you'll be prompted to add a `_acme-challenge.<domain>` TXT record to your DNS during issuance.
- Output files land in `~/ssl/<domain>/` (or `%USERPROFILE%\ssl\<domain>\` on Windows) by default — configurable in Settings.
- The `.pfx` password is shown once and not stored anywhere — save it immediately.

---

## Русский

### ✨ Что делают скрипты

Оба скрипта предлагают одинаковый интерактивный сценарий:

- 📜 Выпускают/перевыпускают wildcard-сертификаты (`example.com` + `*.example.com`) через DNS-01 challenge
- 📋 Хранят список управляемых доменов (автоматически обнаруживают папки или добавляют вручную)
- 📊 Показывают таблицу статусов с обратным отсчётом до истечения и цветовой индикацией (действует / скоро истекает / критично / истёк)
- 📁 Копируют выпущенные сертификаты (`fullchain.pem`, `cert.pem`, `chain.pem`, `privkey.pem`) в настраиваемую папку вывода с правильными правами доступа
- 🔁 Конвертируют сертификат в `.pfx` (PKCS#12) для IIS, с опциональной генерацией случайного пароля
- 🌍 Поддерживают русский и английский интерфейс, язык можно переключить в любой момент

### 🐧🍎 Linux / macOS — `cert.sh`

#### Требования

- `certbot`, `openssl`, `sudo`, а также стандартные утилиты coreutils (`date`, `id`, `tr`, `mkdir`, `cp`, `chown`, `chmod`, `seq`, `wc`)
- Если скрипт запущен не от root, он автоматически перезапустит себя через `sudo`

```bash
# macOS
brew install certbot openssl

# Debian/Ubuntu
sudo apt install certbot openssl
```

#### Использование

```bash
./cert.sh
```

### 🪟 Windows — `cert.ps1`

#### Требования

- PowerShell 5.1 (встроен в Windows) или PowerShell 7+
- [certbot для Windows](https://certbot.eff.org/instructions)
- `openssl` — нужен только для шага конвертации в PFX для IIS (пункт 3 в меню)

```powershell
# через Chocolatey
choco install certbot openssl

# через winget
winget install EFF.Certbot
winget install ShiningLight.OpenSSL
```

#### Использование

```powershell
.\cert.ps1
```

Запуск от администратора не требуется — по умолчанию папки config/work/logs certbot'а находятся в `%LOCALAPPDATA%\Certbot` (переопределяется переменной окружения `CERTBOT_HOME`), а ручной DNS-01 challenge не требует занимать какой-либо порт.

### ▶️ Главное меню

1. Выпустить / перевыпустить сертификат из списка
2. Добавить новый домен
3. Конвертировать сертификат в PFX для IIS
4. Показать таблицу заново
5. Настройки (email, папка вывода, язык)
0. Выход

*(`0` — всегда «выход» / «назад» в любом меню.)*

При первом запуске нужно будет выбрать язык интерфейса, затем указать email и добавить первый домен.

### ⚙️ Конфигурация и генерируемые файлы

Скрипты создают рядом с собой следующие файлы — они **не** предназначены для коммита и исключены через `.gitignore`:

| Файл | Создаётся | Назначение |
|---|---|---|
| `cert.conf` | `cert.sh` | Сохранённые настройки: email, папка вывода, язык интерфейса |
| `cert.windows.conf` | `cert.ps1` | То же самое, но отдельно — чтобы настройки Linux/macOS и Windows не пересекались |
| `domains.conf` | оба | Общий список управляемых доменов, по одному на строку |
| `<домен>/` | оба | Автоматически обнаруженные папки доменов (также ищутся в папке вывода) |

Пути можно переопределить через переменные окружения:

- Оба скрипта: `EMAIL`, `UI_LANG`, `OUTPUT_DIR`, `DOMAINS_FILE`, `CONFIG_FILE`, `CERTBOT_BIN`
- Только `cert.sh`: дополнительных нет
- Только `cert.ps1`: `CERTBOT_HOME` (по умолчанию `%LOCALAPPDATA%\Certbot`)

### 📝 Примечания

- Сертификаты выпускаются через **ручной DNS-01 challenge** — во время выпуска нужно будет добавить TXT-запись `_acme-challenge.<домен>` в DNS.
- По умолчанию файлы сохраняются в `~/ssl/<домен>/` (или `%USERPROFILE%\ssl\<домен>\` на Windows) — можно изменить в Настройках.
- Пароль от `.pfx` показывается один раз и больше нигде не сохраняется — запишите его сразу.
