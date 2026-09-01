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
- 📋 Keeps a list of managed domains (auto-discovered from folders, added manually, or removed from the list when no longer needed)
- 📊 Shows a status table with expiry countdown and color-coded warnings (valid / expiring soon / critical / expired)
- 📁 Copies issued certificates (`fullchain.pem`, `cert.pem`, `chain.pem`, `privkey.pem`) to a configurable output folder with correct permissions
- ✅ Verifies the certificate and private key actually match before copying or building a PFX — refuses to install a broken pair
- 🧪 Optional **staging mode** — issue test certificates against Let's Encrypt's staging environment, so trying things out doesn't burn your real rate limit (5 certs/domain/week)
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
- `openssl` — used to verify the key/cert pair matches and to build the PFX for IIS

```powershell
# via Chocolatey
choco install certbot openssl

# via winget
winget install EFF.Certbot
winget install ShiningLight.OpenSSL.Light
```

#### Usage

```powershell
.\cert.ps1
```

If Windows blocks the script with "running scripts is disabled on this system", allow local scripts for your user once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

⚠️ `cert.ps1` is for a native PowerShell prompt (Windows PowerShell or `pwsh`) — don't run `cert.sh` from Git Bash/MSYS on Windows, it expects a real Linux environment (`sudo`, `certbot` as a Linux package, etc.) and won't work there. Use WSL if you specifically want the Bash version on Windows.

No Administrator shell required — by default certbot's config/work/logs folders live under `%LOCALAPPDATA%\Certbot` (override with the `CERTBOT_HOME` environment variable), and manual DNS-01 issuance doesn't need to bind to any port.

### ▶️ Main menu

1. Issue / reissue a certificate from the list
2. Add a new domain
3. Remove a domain from the list
4. Convert a certificate to PFX for IIS
5. Refresh the table
6. Settings (email, output folder, language, staging mode)
0. Exit

*(`0` is always "exit" / "back" in every menu.)*

On first run you'll be asked to choose an interface language, then guided to set your email and add your first domain.

Removing a domain (item 3) only takes it off the tracked list and rewrites `domains.conf` — it does **not** delete any certificate files. If a folder named after that domain still exists next to the script or in the output folder, it will be auto-discovered and re-added on the next run; delete or move that folder too if you want it gone for good.

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
- **Staging mode** (Settings → item 4) adds `--staging` to every certbot call. Staging certificates are signed by a test CA and will show as untrusted in browsers — use it only to test the workflow, not for real traffic. Toggle it off before issuing production certificates.

---

## Русский

### ✨ Что делают скрипты

Оба скрипта предлагают одинаковый интерактивный сценарий:

- 📜 Выпускают/перевыпускают wildcard-сертификаты (`example.com` + `*.example.com`) через DNS-01 challenge
- 📋 Хранят список управляемых доменов (автоматически обнаруживают папки, добавляют вручную, а ненужные можно удалить из списка)
- 📊 Показывают таблицу статусов с обратным отсчётом до истечения и цветовой индикацией (действует / скоро истекает / критично / истёк)
- 📁 Копируют выпущенные сертификаты (`fullchain.pem`, `cert.pem`, `chain.pem`, `privkey.pem`) в настраиваемую папку вывода с правильными правами доступа
- ✅ Проверяют, что сертификат и приватный ключ действительно образуют пару, перед копированием или сборкой PFX — не дадут поставить нерабочую связку
- 🧪 Опциональный **тестовый режим (staging)** — выпуск тестовых сертификатов через staging-окружение Let's Encrypt, чтобы эксперименты не тратили реальный лимит (5 сертификатов/домен в неделю)
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
- `openssl` — используется для проверки соответствия ключа и сертификата, а также для сборки PFX для IIS

```powershell
# через Chocolatey
choco install certbot openssl

# через winget
winget install EFF.Certbot
winget install ShiningLight.OpenSSL.Light
```

#### Использование

```powershell
.\cert.ps1
```

Если Windows блокирует запуск с ошибкой «выполнение сценариев отключено в этой системе», разрешите локальные скрипты для своего пользователя один раз:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

⚠️ `cert.ps1` рассчитан на запуск из обычной PowerShell-консоли (Windows PowerShell или `pwsh`) — не запускайте `cert.sh` из Git Bash/MSYS на Windows, ему нужно настоящее Linux-окружение (`sudo`, `certbot` как Linux-пакет и т.д.), там он работать не будет. Если хочется именно Bash-версию на Windows — используйте WSL.

Запуск от администратора не требуется — по умолчанию папки config/work/logs certbot'а находятся в `%LOCALAPPDATA%\Certbot` (переопределяется переменной окружения `CERTBOT_HOME`), а ручной DNS-01 challenge не требует занимать какой-либо порт.

### ▶️ Главное меню

1. Выпустить / перевыпустить сертификат из списка
2. Добавить новый домен
3. Удалить домен из списка
4. Конвертировать сертификат в PFX для IIS
5. Показать таблицу заново
6. Настройки (email, папка вывода, язык, тестовый режим)
0. Выход

*(`0` — всегда «выход» / «назад» в любом меню.)*

При первом запуске нужно будет выбрать язык интерфейса, затем указать email и добавить первый домен.

Удаление домена (пункт 3) только убирает его из отслеживаемого списка и переписывает `domains.conf` — файлы сертификата при этом **не удаляются**. Если папка с именем этого домена всё ещё лежит рядом со скриптом или в папке вывода, она будет автоматически обнаружена и снова добавлена в список при следующем запуске; чтобы избавиться от домена насовсем, удалите или переместите и эту папку.

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
- **Тестовый режим (staging)** (Настройки → пункт 4) добавляет `--staging` к каждому вызову certbot. Тестовые сертификаты подписаны тестовым CA и будут показываться браузером как недоверенные — используйте режим только для проверки сценария, не для реального трафика. Не забудьте выключить его перед выпуском боевых сертификатов.
