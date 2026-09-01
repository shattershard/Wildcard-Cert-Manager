#!/usr/bin/env bash

set -eo pipefail

EMAIL="${EMAIL:-}"
UI_LANG="${UI_LANG:-}"
STAGING="${STAGING:-false}"

OUTPUT_USER="${SUDO_USER:-${USER:-$(id -un 2>/dev/null)}}"
OUTPUT_HOME=$(eval echo "~${OUTPUT_USER}")
OUTPUT_DIR="${OUTPUT_DIR:-${OUTPUT_HOME}/ssl}"

LANG="${LANG:-en_US.UTF-8}"
LC_ALL="${LC_ALL:-en_US.UTF-8}"

LIVE_DIR="/etc/letsencrypt/live"
CERTBOT_BIN="${CERTBOT_BIN:-certbot}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAINS_FILE="${DOMAINS_FILE:-${SCRIPT_DIR}/domains.conf}"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/cert.conf}"

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
success() { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
die()     { echo -e "${RED}[ERR ]${RESET}  $*" >&2; exit 1; }

is_truthy() {
  [[ "$1" =~ ^([1Yy]|[Tt]rue|[Oo]n|[Yy]es)$ ]]
}

NO_CLEAR="${NO_CLEAR:-false}"

clear_screen() {
  is_truthy "$NO_CLEAR" && return
  clear 2>/dev/null || printf '\033[2J\033[H'
}

press_enter() {
  is_truthy "$NO_CLEAR" && return
  echo
  read -rp "$(t press_enter)"
}

save_config() {
  cat > "$CONFIG_FILE" <<CFG
EMAIL="${EMAIL}"
OUTPUT_DIR="${OUTPUT_DIR}"
UI_LANG="${UI_LANG}"
STAGING="${STAGING}"
CFG
  chown "$OUTPUT_USER" "$CONFIG_FILE" 2>/dev/null || true
}

keys_match() {
  local cert="$1" key="$2"
  [[ -f "$cert" && -f "$key" ]] || return 1
  local cert_pub key_pub
  cert_pub=$(openssl x509 -in "$cert" -pubkey -noout 2>/dev/null | openssl md5 2>/dev/null) || true
  key_pub=$(openssl pkey -in "$key" -pubout 2>/dev/null | openssl md5 2>/dev/null) || true
  [[ -n "$cert_pub" && "$cert_pub" == "$key_pub" ]]
}

t() {
  local key="$1"; shift || true
  local fmt=""

  case "${UI_LANG}:${key}" in
    en:deps_missing_title) fmt="Missing required tools:" ;;
    ru:deps_missing_title) fmt="Не найдены необходимые утилиты:" ;;
    en:deps_macos_l1) fmt="macOS, install via Homebrew:" ;;
    ru:deps_macos_l1) fmt="macOS, установить через Homebrew:" ;;
    en:deps_macos_l2) fmt="(sudo/date/id/tr/mkdir/cp/chown/chmod/seq are usually already present -" ;;
    ru:deps_macos_l2) fmt="(sudo/date/id/tr/mkdir/cp/chown/chmod/seq обычно уже есть в системе -" ;;
    en:deps_macos_l3) fmt=" if something is missing, check your PATH or reinstall coreutils)" ;;
    ru:deps_macos_l3) fmt=" если их не хватает, проверьте PATH или переустановите coreutils)" ;;
    en:deps_linux_apt) fmt="Debian/Ubuntu:" ;;
    ru:deps_linux_apt) fmt="Debian/Ubuntu:" ;;
    en:deps_linux_dnf) fmt="RHEL/CentOS/Fedora:" ;;
    ru:deps_linux_dnf) fmt="RHEL/CentOS/Fedora:" ;;
    en:deps_linux_arch) fmt="Arch:" ;;
    ru:deps_linux_arch) fmt="Arch:" ;;
    en:deps_unknown) fmt="Install the missing tools with your OS package manager." ;;
    ru:deps_unknown) fmt="Установите недостающие утилиты пакетным менеджером вашей ОС." ;;
    en:deps_fatal) fmt="Cannot start without the tools listed above." ;;
    ru:deps_fatal) fmt="Запуск невозможен без перечисленных утилит." ;;

    en:user_not_found) fmt="User '%s' not found" ;;
    ru:user_not_found) fmt="Пользователь '%s' не найден" ;;

    en:first_run_notice) fmt="Looks like this is the first run: email and/or the domain list are not configured yet." ;;
    ru:first_run_notice) fmt="Похоже, это первый запуск: email и/или список доменов ещё не настроены." ;;
    en:first_run_email_hint) fmt="  -> set the email in item 5 (Settings)" ;;
    ru:first_run_email_hint) fmt="  -> задайте email в пункте 5 (Настройки)" ;;
    en:first_run_domains_hint) fmt="  -> add domain(s) in item 2, or place existing domain folders next to the script" ;;
    ru:first_run_domains_hint) fmt="  -> добавьте домен(ы) в пункте 2, либо положите папки доменов рядом со скриптом" ;;

    en:discovered_domains) fmt="Auto-detected %s domain folder(s) next to the script or in the output folder - added to the list." ;;
    ru:discovered_domains) fmt="Автоматически найдено папок доменов рядом со скриптом/в папке вывода: %s — добавлены в список." ;;

    en:table_empty) fmt="The domain list is empty. Add a domain via item 2 of the main menu, or place a domain folder next to the script." ;;
    ru:table_empty) fmt="Список доменов пуст. Добавьте домен через пункт 2 главного меню, либо положите папку домена рядом со скриптом." ;;
    en:table_col_domain) fmt="DOMAIN" ;;
    ru:table_col_domain) fmt="ДОМЕН" ;;
    en:table_col_status) fmt="STATUS" ;;
    ru:table_col_status) fmt="СТАТУС" ;;
    en:table_col_expires) fmt="EXPIRES IN" ;;
    ru:table_col_expires) fmt="ИСТЕКАЕТ" ;;

    en:status_not_issued) fmt="NOT ISSUED" ;;
    ru:status_not_issued) fmt="НЕ ВЫПУЩЕН" ;;
    en:status_unreadable) fmt="UNREADABLE" ;;
    ru:status_unreadable) fmt="НЕ ЧИТАЕТСЯ" ;;
    en:status_expired) fmt="EXPIRED" ;;
    ru:status_expired) fmt="ИСТЁК" ;;
    en:status_critical) fmt="CRITICAL" ;;
    ru:status_critical) fmt="КРИТИЧНО" ;;
    en:status_expiring_soon) fmt="EXPIRING SOON" ;;
    ru:status_expiring_soon) fmt="СКОРО ИСТЕКАЕТ" ;;
    en:status_valid) fmt="VALID" ;;
    ru:status_valid) fmt="ДЕЙСТВУЕТ" ;;

    en:live_check_title) fmt="Checking live certificates on the sites (connecting to port 443)..." ;;
    ru:live_check_title) fmt="Проверяем сертификаты на самих сайтах (подключение к порту 443)..." ;;
    en:live_checking) fmt="Checking %s..." ;;
    ru:live_checking) fmt="Проверяем %s..." ;;
    en:live_table_col_status) fmt="LIVE STATUS" ;;
    ru:live_table_col_status) fmt="СТАТУС НА САЙТЕ" ;;
    en:live_table_col_deployed) fmt="DEPLOYED" ;;
    ru:live_table_col_deployed) fmt="РАЗВЁРНУТ" ;;
    en:live_status_unreachable) fmt="UNREACHABLE" ;;
    ru:live_status_unreachable) fmt="НЕДОСТУПЕН" ;;
    en:live_status_no_cert) fmt="NO CERT" ;;
    ru:live_status_no_cert) fmt="НЕТ СЕРТ." ;;
    en:deployed_yes) fmt="YES" ;;
    ru:deployed_yes) fmt="ДА" ;;
    en:deployed_no) fmt="NO" ;;
    ru:deployed_no) fmt="НЕТ" ;;
    en:live_deployed_legend) fmt="  DEPLOYED: does the live certificate match the one issued locally? \"?\" = no local copy to compare against." ;;
    ru:live_deployed_legend) fmt="  РАЗВЁРНУТ: совпадает ли сертификат на сайте с тем, что выпущен локально? «?» — нет локальной копии для сравнения." ;;

    en:issue_email_missing) fmt="Email for Let's Encrypt is not set. Configure it in item 5 (Settings)." ;;
    ru:issue_email_missing) fmt="Email для Let's Encrypt не задан. Настройте его в пункте 5 (Настройки)." ;;
    en:issue_running_label) fmt="Running certbot for" ;;
    ru:issue_running_label) fmt="Запускаем certbot для" ;;
    en:issue_dns_hint) fmt="  certbot will ask you to add a TXT record _acme-challenge.%s to DNS" ;;
    ru:issue_dns_hint) fmt="  certbot попросит добавить TXT-запись _acme-challenge.%s в DNS" ;;
    en:issue_done) fmt="Certificate issued!" ;;
    ru:issue_done) fmt="Сертификат выпущен!" ;;
    en:issue_staging_tag) fmt=" [STAGING]" ;;
    ru:issue_staging_tag) fmt=" [ТЕСТОВЫЙ]" ;;

    en:copy_missing_src) fmt="Folder %s not found, skipping copy." ;;
    ru:copy_missing_src) fmt="Папка %s не найдена, пропускаем копирование." ;;
    en:copy_running) fmt="Copying certificates to %s/" ;;
    ru:copy_running) fmt="Копируем сертификаты в %s/" ;;
    en:copy_done) fmt="Files copied to %s/" ;;
    ru:copy_done) fmt="Файлы скопированы в %s/" ;;
    en:copy_files_note) fmt="  fullchain.pem  cert.pem  chain.pem  privkey.pem (600)" ;;
    ru:copy_files_note) fmt="  fullchain.pem  cert.pem  chain.pem  privkey.pem (600)" ;;
    en:keys_mismatch_warning) fmt="Certificate and private key do not match for %s - aborting to avoid installing a broken pair. Check %s manually." ;;
    ru:keys_mismatch_warning) fmt="Сертификат и приватный ключ не совпадают для %s — прерываем, чтобы не поставить нерабочую пару. Проверьте %s вручную." ;;

    en:add_domain_prompt) fmt="  Enter a domain (without wildcard, e.g. example.com): " ;;
    ru:add_domain_prompt) fmt="  Введите домен (без wildcard, например example.com): " ;;
    en:add_domain_empty) fmt="Empty domain, cancelled." ;;
    ru:add_domain_empty) fmt="Пустой домен, отмена." ;;
    en:add_domain_invalid) fmt="Doesn't look like a valid domain: %s" ;;
    ru:add_domain_invalid) fmt="Похоже на некорректный домен: %s" ;;
    en:add_domain_confirm_anyway) fmt="  Add it anyway? [y/N]: " ;;
    ru:add_domain_confirm_anyway) fmt="  Всё равно добавить? [y/N]: " ;;
    en:cancelled) fmt="Cancelled." ;;
    ru:cancelled) fmt="Отменено." ;;
    en:add_domain_known) fmt="Domain %s is already in the list." ;;
    ru:add_domain_known) fmt="Домен %s уже есть в списке." ;;
    en:add_domain_added) fmt="Domain %s added to the list (saved to %s)." ;;
    ru:add_domain_added) fmt="Домен %s добавлен в список (сохранён в %s)." ;;
    en:add_domain_issue_now) fmt="  Issue a certificate for it right now? [y/N]: " ;;
    ru:add_domain_issue_now) fmt="  Выпустить сертификат для него прямо сейчас? [y/N]: " ;;

    en:remove_domain_title) fmt="Choose a domain to remove from the list:" ;;
    ru:remove_domain_title) fmt="Выберите домен для удаления из списка:" ;;
    en:remove_domain_confirm) fmt="  Remove %s from the list? [y/N]: " ;;
    ru:remove_domain_confirm) fmt="  Удалить %s из списка? [y/N]: " ;;
    en:remove_domain_done) fmt="Domain %s removed from the list." ;;
    ru:remove_domain_done) fmt="Домен %s удалён из списка." ;;
    en:remove_domain_note) fmt="  Note: certificate files were not deleted. If a folder named %s still exists next to the script or in the output folder, it will be re-discovered on the next run." ;;
    ru:remove_domain_note) fmt="  Обратите внимание: файлы сертификата не удалены. Если папка %s всё ещё существует рядом со скриптом или в папке вывода, она будет снова обнаружена при следующем запуске." ;;

    en:select_domain_title) fmt="Choose a domain to issue/reissue:" ;;
    ru:select_domain_title) fmt="Выберите домен для выпуска/перевыпуска:" ;;
    en:hint_missing) fmt="* not issued" ;;
    ru:hint_missing) fmt="* не выпущен" ;;
    en:hint_expired) fmt="* expired" ;;
    ru:hint_expired) fmt="* истёк" ;;
    en:hint_critical) fmt="* < 14 days" ;;
    ru:hint_critical) fmt="* < 14 дней" ;;
    en:hint_warn) fmt="* < 30 days" ;;
    ru:hint_warn) fmt="* < 30 дней" ;;
    en:hint_ok) fmt="* ok" ;;
    ru:hint_ok) fmt="* ok" ;;
    en:hint_unknown) fmt="* ?" ;;
    ru:hint_unknown) fmt="* ?" ;;
    en:select_domain_prompt) fmt="  Domain number (0 - back): " ;;
    ru:select_domain_prompt) fmt="  Номер домена (0 — назад): " ;;
    en:select_domain_range_err) fmt="Enter a number from 0 to %s" ;;
    ru:select_domain_range_err) fmt="Введите число от 0 до %s" ;;
    en:label_domain) fmt="  Domain:  " ;;
    ru:label_domain) fmt="  Домен:   " ;;
    en:label_wildcard) fmt="  Wildcard:" ;;
    ru:label_wildcard) fmt="  Wildcard:" ;;
    en:label_output) fmt="  Output:  " ;;
    ru:label_output) fmt="  Куда:    " ;;
    en:confirm_prompt) fmt="  Continue? [y/N]: " ;;
    ru:confirm_prompt) fmt="  Продолжить? [y/N]: " ;;

    en:iis_menu_title) fmt="Convert to PFX for IIS" ;;
    ru:iis_menu_title) fmt="Конвертация в PFX для IIS" ;;
    en:iis_menu_note1) fmt="  IIS can't work with PEM directly - it needs a .pfx (PKCS#12)" ;;
    ru:iis_menu_note1) fmt="  IIS не умеет работать с PEM напрямую — ему нужен .pfx (PKCS#12)" ;;
    en:iis_menu_note2) fmt="  with the private key and cert chain bundled into a single file." ;;
    ru:iis_menu_note2) fmt="  с приватным ключом и цепочкой сертификатов внутри одного файла." ;;
    en:iis_invalid_number) fmt="Invalid number." ;;
    ru:iis_invalid_number) fmt="Неверный номер." ;;
    en:iis_missing_cert) fmt="fullchain.pem/privkey.pem not found for %s." ;;
    ru:iis_missing_cert) fmt="Не найдены fullchain.pem/privkey.pem для %s." ;;
    en:iis_missing_cert_hint) fmt="First issue a certificate (item 1 in the menu) or check %s/." ;;
    ru:iis_missing_cert_hint) fmt="Сначала выпустите сертификат (пункт 1 в меню) или проверьте %s/." ;;
    en:iis_gen_password_prompt) fmt="  Generate a random PFX password? [Y/n]: " ;;
    ru:iis_gen_password_prompt) fmt="  Сгенерировать случайный пароль для PFX? [Y/n]: " ;;
    en:iis_enter_password_prompt) fmt="  Enter the PFX password: " ;;
    ru:iis_enter_password_prompt) fmt="  Введите пароль для PFX: " ;;
    en:iis_empty_password) fmt="Empty password won't work for IIS, cancelled." ;;
    ru:iis_empty_password) fmt="Пустой пароль не подходит для IIS, отмена." ;;
    en:iis_building_label) fmt="Building" ;;
    ru:iis_building_label) fmt="Собираем" ;;
    en:iis_done) fmt="PFX created: %s" ;;
    ru:iis_done) fmt="PFX создан: %s" ;;
    en:iis_password_label) fmt="  Import password for IIS:" ;;
    ru:iis_password_label) fmt="  Пароль для импорта в IIS:" ;;
    en:iis_password_note) fmt="  The password is not stored anywhere else - write it down now." ;;
    ru:iis_password_note) fmt="  Пароль нигде больше не сохраняется — запишите его сейчас." ;;
    en:iis_import_hint) fmt="  In IIS Manager: Server Certificates -> Import... -> point to the .pfx and this password." ;;
    ru:iis_import_hint) fmt="  В IIS Manager: Server Certificates -> Import... -> укажите .pfx и этот пароль." ;;
    en:iis_binding_hint) fmt="  Don't forget to bind the certificate to the site via Site Bindings -> https." ;;
    ru:iis_binding_hint) fmt="  Не забудьте привязать сертификат к сайту через Site Bindings -> https." ;;

    en:settings_title) fmt="Settings" ;;
    ru:settings_title) fmt="Настройки" ;;
    en:settings_email_label) fmt="  Email for Let's Encrypt   : %s" ;;
    ru:settings_email_label) fmt="  Email для Let's Encrypt   : %s" ;;
    en:settings_output_label) fmt="  Certificate output folder : %s" ;;
    ru:settings_output_label) fmt="  Папка вывода сертификатов : %s" ;;
    en:settings_lang_label) fmt="  Interface language        : %s" ;;
    ru:settings_lang_label) fmt="  Язык интерфейса           : %s" ;;
    en:settings_staging_label) fmt="  Staging mode (test certs) : %s" ;;
    ru:settings_staging_label) fmt="  Тестовый режим (staging)  : %s" ;;
    en:staging_on) fmt="ON" ;;
    ru:staging_on) fmt="ВКЛ" ;;
    en:staging_off) fmt="OFF" ;;
    ru:staging_off) fmt="ВЫКЛ" ;;
    en:settings_opt_email) fmt="  1) Change email" ;;
    ru:settings_opt_email) fmt="  1) Изменить email" ;;
    en:settings_opt_output) fmt="  2) Change output folder" ;;
    ru:settings_opt_output) fmt="  2) Изменить папку вывода" ;;
    en:settings_opt_lang) fmt="  3) Change language" ;;
    ru:settings_opt_lang) fmt="  3) Изменить язык" ;;
    en:settings_opt_staging) fmt="  4) Toggle staging mode (test certificates)" ;;
    ru:settings_opt_staging) fmt="  4) Переключить тестовый режим (staging)" ;;
    en:settings_opt_back) fmt="  0) Back" ;;
    ru:settings_opt_back) fmt="  0) Назад" ;;
    en:settings_new_email_prompt) fmt="  New email: " ;;
    ru:settings_new_email_prompt) fmt="  Новый email: " ;;
    en:settings_email_updated) fmt="Email updated: %s" ;;
    ru:settings_email_updated) fmt="Email обновлён: %s" ;;
    en:settings_email_invalid) fmt="Doesn't look like a valid email, not saved." ;;
    ru:settings_email_invalid) fmt="Похоже на некорректный email, не сохранено." ;;
    en:settings_new_output_prompt) fmt="  New output folder [%s]: " ;;
    ru:settings_new_output_prompt) fmt="  Новая папка вывода [%s]: " ;;
    en:settings_output_updated) fmt="Output folder updated: %s" ;;
    ru:settings_output_updated) fmt="Папка вывода обновлена: %s" ;;
    en:settings_lang_updated) fmt="Language updated: %s" ;;
    ru:settings_lang_updated) fmt="Язык обновлён: %s" ;;
    en:settings_staging_updated) fmt="Staging mode: %s" ;;
    ru:settings_staging_updated) fmt="Тестовый режим: %s" ;;

    en:staging_banner) fmt="⚠ STAGING MODE is ON — issued certificates are TEST certificates and are not trusted by browsers." ;;
    ru:staging_banner) fmt="⚠ ВКЛЮЧЁН ТЕСТОВЫЙ РЕЖИМ (staging) — выпущенные сертификаты ТЕСТОВЫЕ и не будут доверенными в браузерах." ;;

    en:press_enter) fmt="Press Enter to continue..." ;;
    ru:press_enter) fmt="Нажмите Enter для продолжения..." ;;

    en:invalid_choice) fmt="Invalid choice." ;;
    ru:invalid_choice) fmt="Неверный выбор." ;;
    en:menu_title) fmt="What do you want to do?" ;;
    ru:menu_title) fmt="Что делаем?" ;;
    en:menu_opt_issue) fmt="  1) Issue / reissue a certificate from the list" ;;
    ru:menu_opt_issue) fmt="  1) Выпустить / перевыпустить сертификат из списка" ;;
    en:menu_opt_add) fmt="  2) Add a new domain" ;;
    ru:menu_opt_add) fmt="  2) Добавить новый домен" ;;
    en:menu_opt_remove) fmt="  3) Remove a domain from the list" ;;
    ru:menu_opt_remove) fmt="  3) Удалить домен из списка" ;;
    en:menu_opt_iis) fmt="  4) Convert a certificate to PFX for IIS" ;;
    ru:menu_opt_iis) fmt="  4) Конвертировать сертификат в PFX для IIS" ;;
    en:menu_opt_live) fmt="  5) Check live certificates on the sites" ;;
    ru:menu_opt_live) fmt="  5) Проверить сертификаты на самих сайтах" ;;
    en:menu_opt_refresh) fmt="  6) Refresh the table" ;;
    ru:menu_opt_refresh) fmt="  6) Показать таблицу заново" ;;
    en:menu_opt_settings) fmt="  7) Settings (email, output folder, language, staging)" ;;
    ru:menu_opt_settings) fmt="  7) Настройки (email, папка вывода, язык, staging)" ;;
    en:menu_opt_exit) fmt="  0) Exit" ;;
    ru:menu_opt_exit) fmt="  0) Выход" ;;
    en:menu_prompt) fmt="  Choice: " ;;
    ru:menu_prompt) fmt="  Выбор: " ;;

    *) fmt="$key" ;;
  esac

  printf -- "$fmt" "$@"
}

select_language() {
  echo
  echo "Choose language / Выберите язык:"
  echo "  1) English"
  echo "  2) Русский"
  echo
  local choice
  while true; do
    read -rp "  > " choice
    case "$choice" in
      1) UI_LANG="en"; break ;;
      2) UI_LANG="ru"; break ;;
      *) echo "1 or 2 / 1 или 2" ;;
    esac
  done
  save_config
}

[[ -z "$UI_LANG" ]] && select_language

check_dependencies() {
  local required=(certbot openssl sudo date mkdir cp chown chmod id tr seq wc)
  local missing=() tool

  for tool in "${required[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done

  [[ ${#missing[@]} -eq 0 ]] && return 0

  echo -e "${RED}${BOLD}$(t deps_missing_title)${RESET}"
  for tool in "${missing[@]}"; do
    echo -e "  ${RED}*${RESET} ${tool}"
  done
  echo

  case "$(uname -s)" in
    Darwin)
      echo -e "${DIM}$(t deps_macos_l1)${RESET}"
      echo -e "  ${BOLD}brew install ${missing[*]}${RESET}"
      echo -e "${DIM}$(t deps_macos_l2)${RESET}"
      echo -e "${DIM}$(t deps_macos_l3)${RESET}"
      ;;
    Linux)
      echo -e "${DIM}$(t deps_linux_apt)${RESET}"
      echo -e "  ${BOLD}sudo apt install ${missing[*]}${RESET}"
      echo -e "${DIM}$(t deps_linux_dnf)${RESET}"
      echo -e "  ${BOLD}sudo dnf install ${missing[*]}${RESET}"
      echo -e "${DIM}$(t deps_linux_arch)${RESET}"
      echo -e "  ${BOLD}sudo pacman -S ${missing[*]}${RESET}"
      ;;
    *)
      echo -e "${DIM}$(t deps_unknown)${RESET}"
      ;;
  esac
  echo

  die "$(t deps_fatal)"
}

check_dependencies

if [[ $EUID -ne 0 ]]; then
  exec sudo \
    LANG="$LANG" LC_ALL="$LC_ALL" \
    OUTPUT_USER="$OUTPUT_USER" OUTPUT_HOME="$OUTPUT_HOME" OUTPUT_DIR="$OUTPUT_DIR" \
    DOMAINS_FILE="$DOMAINS_FILE" CONFIG_FILE="$CONFIG_FILE" UI_LANG="$UI_LANG" \
    "$0" "$@"
fi

DOMAINS=()
DISCOVERED_COUNT=0

domain_known() {
  local needle="$1" d
  for d in "${DOMAINS[@]}"; do
    [[ "$d" == "$needle" ]] && return 0
  done
  return 1
}

if [[ -f "$DOMAINS_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    domain_known "$line" || DOMAINS+=("$line")
  done < "$DOMAINS_FILE"
fi

discover_domain_dirs() {
  local base="$1" d name
  [[ -d "$base" ]] || return 0
  for d in "$base"/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    [[ "$name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$ ]] || continue
    domain_known "$name" && continue
    DOMAINS+=("$name")
    DISCOVERED_COUNT=$((DISCOVERED_COUNT + 1))
  done
}

discover_domain_dirs "$SCRIPT_DIR"
discover_domain_dirs "$OUTPUT_DIR"

days_from_enddate() {
  local expiry="$1"
  [[ -z "$expiry" ]] && { echo "ERROR"; return; }

  local expiry_clean="${expiry% GMT}"

  local exp_epoch now_epoch
  now_epoch=$(date +%s)

  exp_epoch=$(LANG=C date -j -f "%b %d %T %Y" "$expiry_clean" +%s 2>/dev/null) \
    || exp_epoch=$(LANG=C date -d "$expiry" +%s 2>/dev/null) \
    || { echo "ERROR"; return; }

  echo $(( (exp_epoch - now_epoch) / 86400 ))
}

days_left() {
  local domain="$1"
  local cert="${OUTPUT_DIR}/${domain}/cert.pem"

  [[ -f "$cert" ]] || { echo "MISSING"; return; }

  local expiry
  expiry=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2) || true
  days_from_enddate "$expiry"
}

LIVE_CHECK_TIMEOUT="${LIVE_CHECK_TIMEOUT:-6}"

# Portable timeout wrapper - doesn't depend on GNU coreutils `timeout`/`gtimeout`,
# which aren't present on a stock macOS install. Runs "$@" in the background and
# kills it if it's still running after LIVE_CHECK_TIMEOUT seconds.
run_with_timeout() {
  "$@" &
  local cmd_pid=$!

  ( sleep "$LIVE_CHECK_TIMEOUT"; kill -9 "$cmd_pid" 2>/dev/null ) &
  local watcher_pid=$!
  disown "$watcher_pid" 2>/dev/null

  wait "$cmd_pid" 2>/dev/null
  local status=$?

  kill "$watcher_pid" 2>/dev/null
  wait "$watcher_pid" 2>/dev/null

  return "$status"
}

fetch_live_cert() {
  local domain="$1"
  { echo | run_with_timeout openssl s_client -connect "${domain}:443" -servername "$domain" 2>/dev/null; } | openssl x509 2>/dev/null || true
}

live_days_left() {
  local cert_pem="$1"
  [[ -z "$cert_pem" ]] && { echo "UNREACHABLE"; return; }

  local expiry
  expiry=$(echo "$cert_pem" | openssl x509 -enddate -noout 2>/dev/null | cut -d= -f2) || true
  [[ -z "$expiry" ]] && { echo "ERROR"; return; }
  days_from_enddate "$expiry"
}

visual_len() {
  local s="$1" lead
  lead=$(LC_ALL=C printf '%s' "$s" | LC_ALL=C tr -d '\200-\277' | wc -c)
  printf '%s' "$lead"
}

pad() {
  local s="$1" width="$2" len
  len=$(visual_len "$s")
  if (( len >= width )); then
    printf '%s' "$s"
  else
    printf '%s%*s' "$s" "$(( width - len ))" ""
  fi
}

print_header() {
  local title="Wildcard Certificate Manager"
  local width=$(( ${#title} + 4 ))
  local border
  border=$(printf '=%.0s' $(seq 1 "$width"))

  echo
  echo -e "${BOLD}${CYAN}  +${border}+${RESET}"
  echo -e "${BOLD}${CYAN}  |  ${title}  |${RESET}"
  echo -e "${BOLD}${CYAN}  +${border}+${RESET}"
}

print_table() {
  STATUS_MAP=()

  if [[ "$STAGING" == "true" ]]; then
    echo
    echo -e "${YELLOW}${BOLD}$(t staging_banner)${RESET}"
  fi

  if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    echo
    warn "$(t table_empty)"
    echo
    return
  fi

  echo
  echo -e "${BOLD}  +----+------------------------------+----------------+--------------+${RESET}"
  printf "${BOLD}  | %-2s | %s | %s | %s |${RESET}\n" "#" "$(pad "$(t table_col_domain)" 28)" "$(pad "$(t table_col_status)" 14)" "$(pad "$(t table_col_expires)" 12)"
  echo -e "${BOLD}  +----+------------------------------+----------------+--------------+${RESET}"

  local i=0
  for domain in "${DOMAINS[@]}"; do
    local days color status expires st

    days=$(days_left "$domain")

    if [[ "$days" == "MISSING" ]]; then
      status="$(t status_not_issued)"; color=$RED; expires="-"; st="missing"
    elif [[ "$days" == "ERROR" ]]; then
      status="$(t status_unreadable)"; color=$YELLOW; expires="?"; st="error"
    elif (( days < 0 )); then
      status="$(t status_expired)"; color=$RED; expires="${days}d"; st="expired"
    elif (( days <= 14 )); then
      status="$(t status_critical)"; color=$RED; expires="${days}d"; st="critical"
    elif (( days <= 30 )); then
      status="$(t status_expiring_soon)"; color=$YELLOW; expires="${days}d"; st="warn"
    else
      status="$(t status_valid)"; color=$GREEN; expires="${days}d"; st="ok"
    fi

    STATUS_MAP[$i]="$st"

    printf "  ${BOLD}|${RESET} ${DIM}%-2s${RESET} ${BOLD}|${RESET} %-28s ${BOLD}|${RESET} ${color}%s${RESET} ${BOLD}|${RESET} %-12s ${BOLD}|${RESET}\n" \
      "$((i+1))" "$domain" "$(pad "$status" 14)" "$expires"

    i=$((i + 1))
  done

  echo -e "${BOLD}  +----+------------------------------+----------------+--------------+${RESET}"
  echo
}

issue_cert() {
  local domain="$1"

  if [[ -z "$EMAIL" ]]; then
    warn "$(t issue_email_missing)"
    return 1
  fi

  local staging_tag=""
  [[ "$STAGING" == "true" ]] && staging_tag="$(t issue_staging_tag)"

  log "$(t issue_running_label) ${BOLD}${domain}${RESET} + *.${domain}${YELLOW}${staging_tag}${RESET}"
  echo -e "${DIM}$(t issue_dns_hint "$domain")${RESET}"
  echo

  local staging_flag=()
  [[ "$STAGING" == "true" ]] && staging_flag=(--staging)

  $CERTBOT_BIN certonly \
    --manual \
    --preferred-challenges dns \
    --agree-tos \
    --email "$EMAIL" \
    --expand \
    --cert-name "$domain" \
    "${staging_flag[@]}" \
    -d "$domain" \
    -d "*.${domain}"

  success "$(t issue_done)"
}

copy_cert() {
  local domain="$1"
  local src="${LIVE_DIR}/${domain}"
  local dst="${OUTPUT_DIR}/${domain}"

  if [[ ! -d "$src" ]]; then
    warn "$(t copy_missing_src "$src")"
    return 1
  fi

  log "$(t copy_running "$dst")"
  mkdir -p "$dst"

  cp -L "${src}/fullchain.pem" "${dst}/fullchain.pem"
  cp -L "${src}/privkey.pem"   "${dst}/privkey.pem"
  cp -L "${src}/cert.pem"      "${dst}/cert.pem"
  cp -L "${src}/chain.pem"     "${dst}/chain.pem"

  chown -R "$OUTPUT_USER" "$dst" 2>/dev/null || true
  chmod 644 "${dst}/fullchain.pem" "${dst}/cert.pem" "${dst}/chain.pem"
  chmod 600 "${dst}/privkey.pem"

  if ! keys_match "${dst}/cert.pem" "${dst}/privkey.pem"; then
    warn "$(t keys_mismatch_warning "$domain" "$dst")"
    return 1
  fi

  success "$(t copy_done "$dst")"
  echo -e "${DIM}$(t copy_files_note)${RESET}"
}

add_domain() {
  echo
  read -rp "$(t add_domain_prompt)" new_domain
  new_domain="$(printf '%s' "$new_domain" | tr '[:upper:]' '[:lower:]')"

  if [[ -z "$new_domain" ]]; then
    warn "$(t add_domain_empty)"
    return
  fi

  if ! [[ "$new_domain" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]]; then
    warn "$(t add_domain_invalid "$new_domain")"
    read -rp "$(t add_domain_confirm_anyway)" force
    [[ "$force" =~ ^[Yy]$ ]] || { warn "$(t cancelled)"; return; }
  fi

  if domain_known "$new_domain"; then
    warn "$(t add_domain_known "$new_domain")"
    return
  fi

  DOMAINS+=("$new_domain")
  echo "$new_domain" >> "$DOMAINS_FILE"
  chown "$OUTPUT_USER" "$DOMAINS_FILE" 2>/dev/null || true
  success "$(t add_domain_added "$new_domain" "$DOMAINS_FILE")"

  read -rp "$(t add_domain_issue_now)" now
  if [[ "$now" =~ ^[Yy]$ ]]; then
    issue_cert "$new_domain" || return
    copy_cert  "$new_domain" || return
  fi
}

remove_domain() {
  if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    warn "$(t table_empty)"
    return
  fi

  echo -e "${BOLD}$(t remove_domain_title)${RESET}"
  echo

  local i=0
  for domain in "${DOMAINS[@]}"; do
    printf "  %2s) %s\n" "$((i+1))" "$domain"
    i=$((i + 1))
  done
  echo

  local choice
  read -rp "$(t select_domain_prompt)" choice
  [[ "$choice" == "0" ]] && return
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#DOMAINS[@]} )); then
    warn "$(t select_domain_range_err "${#DOMAINS[@]}")"
    return
  fi

  local target="${DOMAINS[$((choice-1))]}"
  local confirm
  read -rp "$(t remove_domain_confirm "$target")" confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { warn "$(t cancelled)"; return; }

  if [[ -f "$DOMAINS_FILE" ]]; then
    local tmp
    tmp="$(mktemp)"
    grep -vFx "$target" "$DOMAINS_FILE" > "$tmp" || true
    mv "$tmp" "$DOMAINS_FILE"
    chown "$OUTPUT_USER" "$DOMAINS_FILE" 2>/dev/null || true
  fi

  local new_domains=() d
  for d in "${DOMAINS[@]}"; do
    [[ "$d" == "$target" ]] || new_domains+=("$d")
  done
  DOMAINS=("${new_domains[@]}")

  success "$(t remove_domain_done "$target")"
  warn "$(t remove_domain_note "$target")"
}

select_domain() {
  if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    warn "$(t table_empty)"
    return
  fi

  echo -e "${BOLD}$(t select_domain_title)${RESET}"
  echo

  local i=0
  for domain in "${DOMAINS[@]}"; do
    local st="${STATUS_MAP[$i]:-}" hint
    case "$st" in
      missing)  hint="${RED}$(t hint_missing)${RESET}" ;;
      expired)  hint="${RED}$(t hint_expired)${RESET}" ;;
      critical) hint="${RED}$(t hint_critical)${RESET}" ;;
      warn)     hint="${YELLOW}$(t hint_warn)${RESET}" ;;
      ok)       hint="${GREEN}$(t hint_ok)${RESET}" ;;
      *)        hint="${YELLOW}$(t hint_unknown)${RESET}" ;;
    esac
    printf "  ${BOLD}%2s)${RESET} %-30s %b\n" "$((i+1))" "$domain" "$hint"
    i=$((i + 1))
  done

  echo
  local choice domain
  while true; do
    read -rp "$(t select_domain_prompt)" choice
    if [[ "$choice" == "0" ]]; then
      return
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#DOMAINS[@]} )); then
      domain="${DOMAINS[$((choice-1))]}"
      break
    fi
    warn "$(t select_domain_range_err "${#DOMAINS[@]}")"
  done

  echo
  echo -e "$(t label_domain) ${BOLD}${domain}${RESET}"
  echo -e "$(t label_wildcard) ${BOLD}*.${domain}${RESET}"
  echo -e "$(t label_output) ${BOLD}${OUTPUT_DIR}/${domain}/${RESET}"
  echo
  read -rp "$(t confirm_prompt)" confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { warn "$(t cancelled)"; return; }

  issue_cert "$domain" || return
  copy_cert  "$domain" || return
}

convert_to_iis_menu() {
  if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    warn "$(t table_empty)"
    return
  fi

  echo
  echo -e "${BOLD}$(t iis_menu_title)${RESET}"
  echo -e "${DIM}$(t iis_menu_note1)${RESET}"
  echo -e "${DIM}$(t iis_menu_note2)${RESET}"
  echo

  local i=0
  for domain in "${DOMAINS[@]}"; do
    printf "  %2s) %s\n" "$((i+1))" "$domain"
    i=$((i+1))
  done
  echo

  local choice
  read -rp "$(t select_domain_prompt)" choice
  [[ "$choice" == "0" ]] && return
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#DOMAINS[@]} )); then
    warn "$(t iis_invalid_number)"
    return
  fi

  convert_to_iis "${DOMAINS[$((choice-1))]}"
}

convert_to_iis() {
  local domain="$1"
  local out_src="${OUTPUT_DIR}/${domain}"
  local live_src="${LIVE_DIR}/${domain}"
  local cert_dir=""

  if [[ -f "${out_src}/fullchain.pem" && -f "${out_src}/privkey.pem" ]]; then
    cert_dir="$out_src"
  elif [[ -f "${live_src}/fullchain.pem" && -f "${live_src}/privkey.pem" ]]; then
    cert_dir="$live_src"
  else
    warn "$(t iis_missing_cert "$domain")"
    warn "$(t iis_missing_cert_hint "${OUTPUT_DIR}/${domain}")"
    return 1
  fi

  if ! keys_match "${cert_dir}/cert.pem" "${cert_dir}/privkey.pem"; then
    warn "$(t keys_mismatch_warning "$domain" "$cert_dir")"
    return 1
  fi

  local dst="${OUTPUT_DIR}/${domain}"
  local pfx_path="${dst}/${domain}.pfx"
  mkdir -p "$dst"

  local password gen
  read -rp "$(t iis_gen_password_prompt)" gen
  if [[ "$gen" =~ ^[Nn]$ ]]; then
    read -rsp "$(t iis_enter_password_prompt)" password
    echo
    if [[ -z "$password" ]]; then
      warn "$(t iis_empty_password)"
      return 1
    fi
  else
    password=$(openssl rand -base64 18)
  fi

  log "$(t iis_building_label) ${pfx_path} <- ${cert_dir}/{cert,privkey,chain}.pem"

  openssl pkcs12 -export \
    -out "$pfx_path" \
    -inkey "${cert_dir}/privkey.pem" \
    -in "${cert_dir}/cert.pem" \
    -certfile "${cert_dir}/chain.pem" \
    -name "$domain" \
    -passout "pass:${password}"

  chown "$OUTPUT_USER" "$pfx_path" 2>/dev/null || true
  chmod 600 "$pfx_path"

  success "$(t iis_done "$pfx_path")"
  echo
  echo -e "$(t iis_password_label) ${BOLD}${password}${RESET}"
  echo -e "${DIM}$(t iis_password_note)${RESET}"
  echo -e "${DIM}$(t iis_import_hint)${RESET}"
  echo -e "${DIM}$(t iis_binding_hint)${RESET}"
}

check_live_menu() {
  if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    warn "$(t table_empty)"
    return
  fi

  echo
  echo -e "${BOLD}$(t live_check_title)${RESET}"
  echo

  local live_status=() live_color=() live_expires=() live_deployed=() live_deployed_color=()
  local domain

  for domain in "${DOMAINS[@]}"; do
    log "$(t live_checking "$domain")"

    local cert_pem days color status expires deployed deployed_color

    cert_pem="$(fetch_live_cert "$domain")"
    days=$(live_days_left "$cert_pem")

    if [[ "$days" == "UNREACHABLE" ]]; then
      status="$(t live_status_unreachable)"; color=$RED; expires="-"
    elif [[ "$days" == "ERROR" ]]; then
      status="$(t live_status_no_cert)"; color=$RED; expires="-"
    elif (( days < 0 )); then
      status="$(t status_expired)"; color=$RED; expires="${days}d"
    elif (( days <= 14 )); then
      status="$(t status_critical)"; color=$RED; expires="${days}d"
    elif (( days <= 30 )); then
      status="$(t status_expiring_soon)"; color=$YELLOW; expires="${days}d"
    else
      status="$(t status_valid)"; color=$GREEN; expires="${days}d"
    fi

    local local_cert="${OUTPUT_DIR}/${domain}/cert.pem"
    if [[ -z "$cert_pem" || ! -f "$local_cert" ]]; then
      deployed="?"; deployed_color=$DIM
    else
      local live_fp local_fp
      live_fp=$(echo "$cert_pem" | openssl x509 -noout -fingerprint -sha256 2>/dev/null) || true
      local_fp=$(openssl x509 -in "$local_cert" -noout -fingerprint -sha256 2>/dev/null) || true
      if [[ -n "$live_fp" && "$live_fp" == "$local_fp" ]]; then
        deployed="$(t deployed_yes)"; deployed_color=$GREEN
      else
        deployed="$(t deployed_no)"; deployed_color=$RED
      fi
    fi

    live_status+=("$status"); live_color+=("$color")
    live_expires+=("$expires")
    live_deployed+=("$deployed"); live_deployed_color+=("$deployed_color")
  done

  echo
  echo -e "${BOLD}  +----+------------------------------+----------------+--------------+------------+${RESET}"
  printf "${BOLD}  | %-2s | %s | %s | %s | %s |${RESET}\n" \
    "#" "$(pad "$(t table_col_domain)" 28)" "$(pad "$(t live_table_col_status)" 14)" "$(pad "$(t table_col_expires)" 12)" "$(pad "$(t live_table_col_deployed)" 10)"
  echo -e "${BOLD}  +----+------------------------------+----------------+--------------+------------+${RESET}"

  local i=0
  for domain in "${DOMAINS[@]}"; do
    printf "  ${BOLD}|${RESET} ${DIM}%-2s${RESET} ${BOLD}|${RESET} %-28s ${BOLD}|${RESET} ${live_color[$i]}%s${RESET} ${BOLD}|${RESET} %-12s ${BOLD}|${RESET} ${live_deployed_color[$i]}%s${RESET} ${BOLD}|${RESET}\n" \
      "$((i+1))" "$domain" "$(pad "${live_status[$i]}" 14)" "${live_expires[$i]}" "$(pad "${live_deployed[$i]}" 10)"
    i=$((i + 1))
  done

  echo -e "${BOLD}  +----+------------------------------+----------------+--------------+------------+${RESET}"
  echo -e "${DIM}$(t live_deployed_legend)${RESET}"
  echo
}

settings_menu() {
  while true; do
    clear_screen
    print_header
    echo
    echo -e "${BOLD}$(t settings_title)${RESET}"
    echo "$(t settings_email_label "$EMAIL")"
    echo "$(t settings_output_label "$OUTPUT_DIR")"
    echo "$(t settings_lang_label "$UI_LANG")"
    echo "$(t settings_staging_label "$([[ "$STAGING" == "true" ]] && t staging_on || t staging_off)")"
    echo
    echo "$(t settings_opt_email)"
    echo "$(t settings_opt_output)"
    echo "$(t settings_opt_lang)"
    echo "$(t settings_opt_staging)"
    echo "$(t settings_opt_back)"
    echo
    local choice
    read -rp "$(t menu_prompt)" choice
    case "$choice" in
      1)
        local new_email
        read -rp "$(t settings_new_email_prompt)" new_email
        if [[ "$new_email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
          EMAIL="$new_email"
          save_config
          success "$(t settings_email_updated "$EMAIL")"
        else
          warn "$(t settings_email_invalid)"
        fi
        ;;
      2)
        local new_dir
        read -rp "$(t settings_new_output_prompt "$OUTPUT_DIR")" new_dir
        if [[ -n "$new_dir" ]]; then
          OUTPUT_DIR="$new_dir"
          save_config
          success "$(t settings_output_updated "$OUTPUT_DIR")"
        fi
        ;;
      3)
        select_language
        success "$(t settings_lang_updated "$UI_LANG")"
        ;;
      4)
        if [[ "$STAGING" == "true" ]]; then STAGING="false"; else STAGING="true"; fi
        save_config
        success "$(t settings_staging_updated "$([[ "$STAGING" == "true" ]] && t staging_on || t staging_off)")"
        ;;
      0) return ;;
      *) warn "$(t invalid_choice)" ;;
    esac
    press_enter
  done
}

main_menu() {
  echo -e "${BOLD}$(t menu_title)${RESET}"
  echo "$(t menu_opt_issue)"
  echo "$(t menu_opt_add)"
  echo "$(t menu_opt_remove)"
  echo "$(t menu_opt_iis)"
  echo "$(t menu_opt_live)"
  echo "$(t menu_opt_refresh)"
  echo "$(t menu_opt_settings)"
  echo "$(t menu_opt_exit)"
  echo
  local action
  read -rp "$(t menu_prompt)" action
  case "$action" in
    1) select_domain ;;
    2) add_domain ;;
    3) remove_domain ;;
    4) convert_to_iis_menu ;;
    5) check_live_menu ;;
    6) print_table ;;
    7) settings_menu ;;
    0) exit 0 ;;
    *) warn "$(t invalid_choice)" ;;
  esac
}

main() {
  clear_screen
  print_header

  id "$OUTPUT_USER" >/dev/null 2>&1 || die "$(t user_not_found "$OUTPUT_USER")"

  local showed_startup_notice="false"

  if [[ $DISCOVERED_COUNT -gt 0 ]]; then
    echo
    success "$(t discovered_domains "$DISCOVERED_COUNT")"
    showed_startup_notice="true"
  fi

  if [[ -z "$EMAIL" || ${#DOMAINS[@]} -eq 0 ]]; then
    echo
    warn "$(t first_run_notice)"
    [[ -z "$EMAIL" ]]          && warn "$(t first_run_email_hint)"
    [[ ${#DOMAINS[@]} -eq 0 ]] && warn "$(t first_run_domains_hint)"
    showed_startup_notice="true"
  fi

  [[ "$showed_startup_notice" == "true" ]] && press_enter

  while true; do
    clear_screen
    print_header
    print_table
    main_menu
    press_enter
  done
}

main "$@"