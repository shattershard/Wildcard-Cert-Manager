#Requires -Version 5.1
<#
  Wildcard Cert Manager - Windows/PowerShell port of cert.sh
  Issues/manages wildcard Let's Encrypt certificates via certbot (manual DNS-01)
  and converts them to PFX for IIS.
#>

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Paths & settings
# ---------------------------------------------------------------------------

$ScriptDir    = $PSScriptRoot
$DomainsFile  = if ($env:DOMAINS_FILE) { $env:DOMAINS_FILE } else { Join-Path $ScriptDir 'domains.conf' }
$ConfigFile   = if ($env:CONFIG_FILE) { $env:CONFIG_FILE } else { Join-Path $ScriptDir 'cert.windows.conf' }

# certbot needs a writable config/work/logs dir. Default to the user's own
# profile so this never requires an elevated (Administrator) shell - manual
# DNS-01 issuance doesn't bind to any port, so admin rights aren't needed.
$CertbotHome  = if ($env:CERTBOT_HOME) { $env:CERTBOT_HOME } else { Join-Path $env:LOCALAPPDATA 'Certbot' }
$LiveDir      = Join-Path $CertbotHome 'live'
$CertbotBin   = if ($env:CERTBOT_BIN) { $env:CERTBOT_BIN } else { 'certbot' }

function ConvertTo-Bool {
  param([string]$Value)
  return $Value -in @('1', 'true', 'True', 'TRUE', 'yes', 'on')
}

$Email  = $env:EMAIL
$UILang = $env:UI_LANG
$OutputDir = if ($env:OUTPUT_DIR) { $env:OUTPUT_DIR } else { Join-Path $HOME 'ssl' }
$Staging = ConvertTo-Bool $env:STAGING

function Import-Config {
  if (-not (Test-Path $ConfigFile)) { return }
  foreach ($line in Get-Content $ConfigFile) {
    if ($line -notmatch '^(EMAIL|OUTPUT_DIR|UI_LANG|STAGING)=(.*)$') { continue }
    switch ($Matches[1]) {
      'EMAIL'      { if (-not $Email)  { $script:Email  = $Matches[2] } }
      'OUTPUT_DIR' { if (-not $env:OUTPUT_DIR) { $script:OutputDir = $Matches[2] } }
      'UI_LANG'    { if (-not $UILang) { $script:UILang = $Matches[2] } }
      'STAGING'    { if (-not $env:STAGING) { $script:Staging = ConvertTo-Bool $Matches[2] } }
    }
  }
}

function Save-Config {
  @(
    "EMAIL=$Email"
    "OUTPUT_DIR=$OutputDir"
    "UI_LANG=$UILang"
    "STAGING=$(if ($Staging) { 'true' } else { 'false' })"
  ) | Set-Content -Path $ConfigFile -Encoding UTF8
}

Import-Config

# ---------------------------------------------------------------------------
# i18n
# ---------------------------------------------------------------------------

$Strings = @{
  'en:deps_missing_title' = 'Missing required tools:'
  'ru:deps_missing_title' = 'Не найдены необходимые утилиты:'
  'en:deps_choco_hint'    = 'Install via Chocolatey:'
  'ru:deps_choco_hint'    = 'Установить через Chocolatey:'
  'en:deps_winget_hint'   = 'or via winget:'
  'ru:deps_winget_hint'   = 'или через winget:'
  'en:deps_fatal'         = 'Cannot continue without the tool(s) listed above.'
  'ru:deps_fatal'         = 'Продолжение невозможно без перечисленных утилит.'

  'en:first_run_notice'        = 'Looks like this is the first run: email and/or the domain list are not configured yet.'
  'ru:first_run_notice'        = 'Похоже, это первый запуск: email и/или список доменов ещё не настроены.'
  'en:first_run_email_hint'    = '  -> set the email in item 5 (Settings)'
  'ru:first_run_email_hint'    = '  -> задайте email в пункте 5 (Настройки)'
  'en:first_run_domains_hint'  = '  -> add domain(s) in item 2, or place existing domain folders next to the script'
  'ru:first_run_domains_hint'  = '  -> добавьте домен(ы) в пункте 2, либо положите папки доменов рядом со скриптом'

  'en:discovered_domains' = 'Auto-detected {0} domain folder(s) next to the script or in the output folder - added to the list.'
  'ru:discovered_domains' = 'Автоматически найдено папок доменов рядом со скриптом/в папке вывода: {0} — добавлены в список.'

  'en:table_empty'      = 'The domain list is empty. Add a domain via item 2 of the main menu, or place a domain folder next to the script.'
  'ru:table_empty'      = 'Список доменов пуст. Добавьте домен через пункт 2 главного меню, либо положите папку домена рядом со скриптом.'
  'en:table_col_domain'  = 'DOMAIN'
  'ru:table_col_domain'  = 'ДОМЕН'
  'en:table_col_status'  = 'STATUS'
  'ru:table_col_status'  = 'СТАТУС'
  'en:table_col_expires' = 'EXPIRES IN'
  'ru:table_col_expires' = 'ИСТЕКАЕТ'

  'en:status_not_issued'    = 'NOT ISSUED'
  'ru:status_not_issued'    = 'НЕ ВЫПУЩЕН'
  'en:status_unreadable'    = 'UNREADABLE'
  'ru:status_unreadable'    = 'НЕ ЧИТАЕТСЯ'
  'en:status_expired'       = 'EXPIRED'
  'ru:status_expired'       = 'ИСТЁК'
  'en:status_critical'      = 'CRITICAL'
  'ru:status_critical'      = 'КРИТИЧНО'
  'en:status_expiring_soon' = 'EXPIRING SOON'
  'ru:status_expiring_soon' = 'СКОРО ИСТЕКАЕТ'
  'en:status_valid'         = 'VALID'
  'ru:status_valid'         = 'ДЕЙСТВУЕТ'

  'en:live_check_title' = 'Checking live certificates on the sites (connecting to port 443)...'
  'ru:live_check_title' = 'Проверяем сертификаты на самих сайтах (подключение к порту 443)...'
  'en:live_checking' = 'Checking {0}...'
  'ru:live_checking' = 'Проверяем {0}...'
  'en:live_table_col_status' = 'LIVE STATUS'
  'ru:live_table_col_status' = 'СТАТУС НА САЙТЕ'
  'en:live_table_col_deployed' = 'DEPLOYED'
  'ru:live_table_col_deployed' = 'РАЗВЁРНУТ'
  'en:live_status_unreachable' = 'UNREACHABLE'
  'ru:live_status_unreachable' = 'НЕДОСТУПЕН'
  'en:deployed_yes' = 'YES'
  'ru:deployed_yes' = 'ДА'
  'en:deployed_no' = 'NO'
  'ru:deployed_no' = 'НЕТ'
  'en:live_deployed_legend' = '  DEPLOYED: does the live certificate match the one issued locally? "?" = no local copy to compare against.'
  'ru:live_deployed_legend' = '  РАЗВЁРНУТ: совпадает ли сертификат на сайте с тем, что выпущен локально? "?" — нет локальной копии для сравнения.'

  'en:issue_email_missing' = "Email for Let's Encrypt is not set. Configure it in item 5 (Settings)."
  'ru:issue_email_missing' = 'Email для Lets Encrypt не задан. Настройте его в пункте 5 (Настройки).'
  'en:issue_running_label' = 'Running certbot for'
  'ru:issue_running_label' = 'Запускаем certbot для'
  'en:issue_dns_hint'      = '  certbot will ask you to add a TXT record _acme-challenge.{0} to DNS'
  'ru:issue_dns_hint'      = '  certbot попросит добавить TXT-запись _acme-challenge.{0} в DNS'
  'en:issue_done'          = 'Certificate issued!'
  'ru:issue_done'          = 'Сертификат выпущен!'
  'en:issue_staging_tag'   = ' [STAGING]'
  'ru:issue_staging_tag'   = ' [ТЕСТОВЫЙ]'

  'en:copy_missing_src' = 'Folder {0} not found, skipping copy.'
  'ru:copy_missing_src' = 'Папка {0} не найдена, пропускаем копирование.'
  'en:copy_running'     = 'Copying certificates to {0}\'
  'ru:copy_running'     = 'Копируем сертификаты в {0}\'
  'en:copy_done'        = 'Files copied to {0}\'
  'ru:copy_done'        = 'Файлы скопированы в {0}\'
  'en:copy_files_note'  = '  fullchain.pem  cert.pem  chain.pem  privkey.pem'
  'ru:copy_files_note'  = '  fullchain.pem  cert.pem  chain.pem  privkey.pem'
  'en:keys_mismatch_warning' = 'Certificate and private key do not match for {0} - aborting to avoid installing a broken pair. Check {1} manually.'
  'ru:keys_mismatch_warning' = 'Сертификат и приватный ключ не совпадают для {0} — прерываем, чтобы не поставить нерабочую пару. Проверьте {1} вручную.'

  'en:add_domain_prompt'          = 'Enter a domain (without wildcard, e.g. example.com)'
  'ru:add_domain_prompt'          = 'Введите домен (без wildcard, например example.com)'
  'en:add_domain_empty'           = 'Empty domain, cancelled.'
  'ru:add_domain_empty'           = 'Пустой домен, отмена.'
  'en:add_domain_invalid'         = "Doesn't look like a valid domain: {0}"
  'ru:add_domain_invalid'         = 'Похоже на некорректный домен: {0}'
  'en:add_domain_confirm_anyway'  = '  Add it anyway? [y/N]'
  'ru:add_domain_confirm_anyway'  = '  Всё равно добавить? [y/N]'
  'en:cancelled'                  = 'Cancelled.'
  'ru:cancelled'                  = 'Отменено.'
  'en:add_domain_known'           = 'Domain {0} is already in the list.'
  'ru:add_domain_known'           = 'Домен {0} уже есть в списке.'
  'en:add_domain_added'           = 'Domain {0} added to the list (saved to {1}).'
  'ru:add_domain_added'           = 'Домен {0} добавлен в список (сохранён в {1}).'
  'en:add_domain_issue_now'       = '  Issue a certificate for it right now? [y/N]'
  'ru:add_domain_issue_now'       = '  Выпустить сертификат для него прямо сейчас? [y/N]'

  'en:remove_domain_title'   = 'Choose a domain to remove from the list:'
  'ru:remove_domain_title'   = 'Выберите домен для удаления из списка:'
  'en:remove_domain_confirm' = '  Remove {0} from the list? [y/N]'
  'ru:remove_domain_confirm' = '  Удалить {0} из списка? [y/N]'
  'en:remove_domain_done'    = 'Domain {0} removed from the list.'
  'ru:remove_domain_done'    = 'Домен {0} удалён из списка.'
  'en:remove_domain_note'    = '  Note: certificate files were not deleted. If a folder named {0} still exists next to the script or in the output folder, it will be re-discovered on the next run.'
  'ru:remove_domain_note'    = '  Обратите внимание: файлы сертификата не удалены. Если папка {0} всё ещё существует рядом со скриптом или в папке вывода, она будет снова обнаружена при следующем запуске.'

  'en:select_domain_title' = 'Choose a domain to issue/reissue:'
  'ru:select_domain_title' = 'Выберите домен для выпуска/перевыпуска:'
  'en:hint_missing'  = '* not issued'
  'ru:hint_missing'  = '* не выпущен'
  'en:hint_expired'  = '* expired'
  'ru:hint_expired'  = '* истёк'
  'en:hint_critical' = '* < 14 days'
  'ru:hint_critical' = '* < 14 дней'
  'en:hint_warn'     = '* < 30 days'
  'ru:hint_warn'     = '* < 30 дней'
  'en:hint_ok'       = '* ok'
  'ru:hint_ok'       = '* ok'
  'en:hint_unknown'  = '* ?'
  'ru:hint_unknown'  = '* ?'
  'en:select_domain_prompt'    = '  Domain number (0 - back)'
  'ru:select_domain_prompt'    = '  Номер домена (0 — назад)'
  'en:select_domain_range_err' = 'Enter a number from 0 to {0}'
  'ru:select_domain_range_err' = 'Введите число от 0 до {0}'
  'en:label_domain'   = '  Domain:  '
  'ru:label_domain'   = '  Домен:   '
  'en:label_wildcard'  = '  Wildcard:'
  'ru:label_wildcard'  = '  Wildcard:'
  'en:label_output'   = '  Output:  '
  'ru:label_output'   = '  Куда:    '
  'en:confirm_prompt' = '  Continue? [y/N]'
  'ru:confirm_prompt' = '  Продолжить? [y/N]'

  'en:iis_menu_title' = 'Convert to PFX for IIS'
  'ru:iis_menu_title' = 'Конвертация в PFX для IIS'
  'en:iis_menu_note1' = "  IIS can't work with PEM directly - it needs a .pfx (PKCS#12)"
  'ru:iis_menu_note1' = '  IIS не умеет работать с PEM напрямую — ему нужен .pfx (PKCS#12)'
  'en:iis_menu_note2' = '  with the private key and cert chain bundled into a single file.'
  'ru:iis_menu_note2' = '  с приватным ключом и цепочкой сертификатов внутри одного файла.'
  'en:iis_invalid_number'   = 'Invalid number.'
  'ru:iis_invalid_number'   = 'Неверный номер.'
  'en:iis_missing_cert'      = 'fullchain.pem/privkey.pem not found for {0}.'
  'ru:iis_missing_cert'      = 'Не найдены fullchain.pem/privkey.pem для {0}.'
  'en:iis_missing_cert_hint' = 'First issue a certificate (item 1 in the menu) or check {0}\'
  'ru:iis_missing_cert_hint' = 'Сначала выпустите сертификат (пункт 1 в меню) или проверьте {0}\'
  'en:iis_gen_password_prompt'   = '  Generate a random PFX password? [Y/n]'
  'ru:iis_gen_password_prompt'   = '  Сгенерировать случайный пароль для PFX? [Y/n]'
  'en:iis_enter_password_prompt' = '  Enter the PFX password'
  'ru:iis_enter_password_prompt' = '  Введите пароль для PFX'
  'en:iis_empty_password' = "Empty password won't work for IIS, cancelled."
  'ru:iis_empty_password' = 'Пустой пароль не подходит для IIS, отмена.'
  'en:iis_building_label' = 'Building'
  'ru:iis_building_label' = 'Собираем'
  'en:iis_done'  = 'PFX created: {0}'
  'ru:iis_done'  = 'PFX создан: {0}'
  'en:iis_password_label' = '  Import password for IIS:'
  'ru:iis_password_label' = '  Пароль для импорта в IIS:'
  'en:iis_password_note'  = '  The password is not stored anywhere else - write it down now.'
  'ru:iis_password_note'  = '  Пароль нигде больше не сохраняется — запишите его сейчас.'
  'en:iis_import_hint'  = '  In IIS Manager: Server Certificates -> Import... -> point to the .pfx and this password.'
  'ru:iis_import_hint'  = '  В IIS Manager: Server Certificates -> Import... -> укажите .pfx и этот пароль.'
  'en:iis_binding_hint' = "  Don't forget to bind the certificate to the site via Site Bindings -> https."
  'ru:iis_binding_hint' = '  Не забудьте привязать сертификат к сайту через Site Bindings -> https.'

  'en:settings_title'        = 'Settings'
  'ru:settings_title'        = 'Настройки'
  'en:settings_email_label'  = "  Email for Let's Encrypt   : {0}"
  'ru:settings_email_label'  = '  Email для Lets Encrypt    : {0}'
  'en:settings_output_label' = '  Certificate output folder : {0}'
  'ru:settings_output_label' = '  Папка вывода сертификатов : {0}'
  'en:settings_lang_label'   = '  Interface language        : {0}'
  'ru:settings_lang_label'   = '  Язык интерфейса           : {0}'
  'en:settings_staging_label' = '  Staging mode (test certs) : {0}'
  'ru:settings_staging_label' = '  Тестовый режим (staging)  : {0}'
  'en:staging_on'  = 'ON'
  'ru:staging_on'  = 'ВКЛ'
  'en:staging_off' = 'OFF'
  'ru:staging_off' = 'ВЫКЛ'
  'en:settings_opt_email'  = '  1) Change email'
  'ru:settings_opt_email'  = '  1) Изменить email'
  'en:settings_opt_output' = '  2) Change output folder'
  'ru:settings_opt_output' = '  2) Изменить папку вывода'
  'en:settings_opt_lang'   = '  3) Change language'
  'ru:settings_opt_lang'   = '  3) Изменить язык'
  'en:settings_opt_staging' = '  4) Toggle staging mode (test certificates)'
  'ru:settings_opt_staging' = '  4) Переключить тестовый режим (staging)'
  'en:settings_opt_back'   = '  0) Back'
  'ru:settings_opt_back'   = '  0) Назад'
  'en:settings_new_email_prompt'  = '  New email'
  'ru:settings_new_email_prompt'  = '  Новый email'
  'en:settings_email_updated' = 'Email updated: {0}'
  'ru:settings_email_updated' = 'Email обновлён: {0}'
  'en:settings_email_invalid' = "Doesn't look like a valid email, not saved."
  'ru:settings_email_invalid' = 'Похоже на некорректный email, не сохранено.'
  'en:settings_new_output_prompt' = '  New output folder [{0}]'
  'ru:settings_new_output_prompt' = '  Новая папка вывода [{0}]'
  'en:settings_output_updated' = 'Output folder updated: {0}'
  'ru:settings_output_updated' = 'Папка вывода обновлена: {0}'
  'en:settings_lang_updated'   = 'Language updated: {0}'
  'ru:settings_lang_updated'   = 'Язык обновлён: {0}'
  'en:settings_staging_updated' = 'Staging mode: {0}'
  'ru:settings_staging_updated' = 'Тестовый режим: {0}'

  'en:staging_banner' = '⚠ STAGING MODE is ON - issued certificates are TEST certificates and are not trusted by browsers.'
  'ru:staging_banner' = '⚠ ВКЛЮЧЁН ТЕСТОВЫЙ РЕЖИМ (staging) — выпущенные сертификаты ТЕСТОВЫЕ и не будут доверенными в браузерах.'

  'en:press_enter' = 'Press Enter to continue...'
  'ru:press_enter' = 'Нажмите Enter для продолжения...'

  'en:invalid_choice' = 'Invalid choice.'
  'ru:invalid_choice' = 'Неверный выбор.'
  'en:menu_title' = 'What do you want to do?'
  'ru:menu_title' = 'Что делаем?'
  'en:menu_opt_issue'    = '  1) Issue / reissue a certificate from the list'
  'ru:menu_opt_issue'    = '  1) Выпустить / перевыпустить сертификат из списка'
  'en:menu_opt_add'      = '  2) Add a new domain'
  'ru:menu_opt_add'      = '  2) Добавить новый домен'
  'en:menu_opt_remove'   = '  3) Remove a domain from the list'
  'ru:menu_opt_remove'   = '  3) Удалить домен из списка'
  'en:menu_opt_iis'      = '  4) Convert a certificate to PFX for IIS'
  'ru:menu_opt_iis'      = '  4) Конвертировать сертификат в PFX для IIS'
  'en:menu_opt_live'     = '  5) Check live certificates on the sites'
  'ru:menu_opt_live'     = '  5) Проверить сертификаты на самих сайтах'
  'en:menu_opt_refresh'  = '  6) Refresh the table'
  'ru:menu_opt_refresh'  = '  6) Показать таблицу заново'
  'en:menu_opt_settings' = '  7) Settings (email, output folder, language, staging)'
  'ru:menu_opt_settings' = '  7) Настройки (email, папка вывода, язык, staging)'
  'en:menu_opt_exit'     = '  0) Exit'
  'ru:menu_opt_exit'     = '  0) Выход'
  'en:menu_prompt' = '  Choice'
  'ru:menu_prompt' = '  Выбор'
}

function T {
  param([string]$Key, [object[]]$FormatArgs = @())
  $fmt = $Strings["${UILang}:${Key}"]
  if (-not $fmt) { return $Key }
  if ($FormatArgs.Count -eq 0) { return $fmt }
  return ($fmt -f $FormatArgs)
}

function Select-Language {
  Write-Host ''
  Write-Host 'Choose language / Выберите язык:'
  Write-Host '  1) English'
  Write-Host '  2) Русский'
  Write-Host ''
  while ($true) {
    $choice = Read-Host '  >'
    switch ($choice) {
      '1' { $script:UILang = 'en'; break }
      '2' { $script:UILang = 'ru'; break }
      default { Write-Host '1 or 2 / 1 или 2'; continue }
    }
    break
  }
  Save-Config
}

if (-not $UILang) { Select-Language }

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

function Log     { param([string]$Msg) Write-Host '[INFO]  ' -ForegroundColor Cyan -NoNewline; Write-Host $Msg }
function Warn-Msg { param([string]$Msg) Write-Host '[WARN]  ' -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Ok-Msg   { param([string]$Msg) Write-Host '[ OK ]  ' -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Die      { param([string]$Msg) Write-Host '[ERR ]  ' -ForegroundColor Red -NoNewline; Write-Host $Msg; exit 1 }

$NoClear = ConvertTo-Bool $env:NO_CLEAR

function Clear-Screen {
  if ($NoClear) { return }
  Clear-Host
}

function Wait-ForEnter {
  if ($NoClear) { return }
  Write-Host ''
  Read-Host (T press_enter) | Out-Null
}

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

function Test-CommandExists {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Assert-Dependency {
  param([string]$Name, [string]$ChocoPackage, [string]$WingetId)
  if (Test-CommandExists $Name) { return }

  Write-Host (T deps_missing_title) -ForegroundColor Red
  Write-Host "  * $Name" -ForegroundColor Red
  Write-Host ''
  Write-Host (T deps_choco_hint)
  Write-Host "  choco install $ChocoPackage" -ForegroundColor White
  Write-Host (T deps_winget_hint)
  Write-Host "  winget install $WingetId" -ForegroundColor White
  Write-Host ''
  Die (T deps_fatal)
}

Assert-Dependency -Name 'certbot' -ChocoPackage 'certbot' -WingetId 'EFF.Certbot'
Assert-Dependency -Name 'openssl' -ChocoPackage 'openssl' -WingetId 'ShiningLight.OpenSSL.Light'

function Test-KeyMatchesCert {
  param([string]$CertPath, [string]$KeyPath)
  if (-not (Test-Path $CertPath) -or -not (Test-Path $KeyPath)) { return $false }
  $certPubKey = & openssl x509 -in $CertPath -pubkey -noout 2>$null
  $certPub = $certPubKey | & openssl md5 2>$null
  $keyPubKey = & openssl pkey -in $KeyPath -pubout 2>$null
  $keyPub = $keyPubKey | & openssl md5 2>$null
  return ($certPub -and $keyPub -and ($certPub -eq $keyPub))
}

# ---------------------------------------------------------------------------
# Domain list
# ---------------------------------------------------------------------------

$Domains = New-Object System.Collections.Generic.List[string]
$DiscoveredCount = 0

function Test-DomainKnown {
  param([string]$Needle)
  return $Domains.Contains($Needle)
}

if (Test-Path $DomainsFile) {
  foreach ($line in Get-Content $DomainsFile) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
    if (-not (Test-DomainKnown $trimmed)) { $Domains.Add($trimmed) }
  }
}

function Find-DomainDirs {
  param([string]$Base)
  if (-not (Test-Path $Base -PathType Container)) { return }
  Get-ChildItem -Path $Base -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $name = $_.Name
    if ($name -notmatch '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$') { return }
    if (Test-DomainKnown $name) { return }
    $Domains.Add($name)
    $script:DiscoveredCount++
  }
}

Find-DomainDirs -Base $ScriptDir
Find-DomainDirs -Base $OutputDir

# ---------------------------------------------------------------------------
# Certificate status
# ---------------------------------------------------------------------------

function Get-DaysLeft {
  param([string]$Domain)
  $cert = Join-Path (Join-Path $OutputDir $Domain) 'cert.pem'
  if (-not (Test-Path $cert)) { return 'MISSING' }
  try {
    $x509 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
    return [math]::Floor(($x509.NotAfter - (Get-Date)).TotalDays)
  } catch {
    return 'ERROR'
  }
}

function Get-LiveCertificate {
  param([string]$DomainName, [int]$TimeoutSeconds = 6)

  $tcp = New-Object System.Net.Sockets.TcpClient
  try {
    $connectTask = $tcp.ConnectAsync($DomainName, 443)
    if (-not $connectTask.Wait([TimeSpan]::FromSeconds($TimeoutSeconds))) { return $null }
    if ($connectTask.IsFaulted -or -not $tcp.Connected) { return $null }

    $callback = { param($sender, $certificate, $chain, $sslPolicyErrors) return $true }
    $sslStream = New-Object System.Net.Security.SslStream($tcp.GetStream(), $false, $callback)
    $sslStream.AuthenticateAsClient($DomainName)
    $remoteCert = $sslStream.RemoteCertificate
    if (-not $remoteCert) { return $null }
    return New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($remoteCert)
  } catch {
    return $null
  } finally {
    $tcp.Close()
  }
}

$script:StatusMap = @{}

function Show-Table {
  $script:StatusMap = @{}

  if ($Staging) {
    Write-Host ''
    Write-Host (T staging_banner) -ForegroundColor Yellow
  }

  if ($Domains.Count -eq 0) {
    Write-Host ''
    Warn-Msg (T table_empty)
    Write-Host ''
    return
  }

  Write-Host ''
  $sep = '  +----+------------------------------+----------------+--------------+'
  Write-Host $sep
  Write-Host ('  | {0,-2} | {1,-28} | {2,-14} | {3,-12} |' -f '#', (T table_col_domain), (T table_col_status), (T table_col_expires))
  Write-Host $sep

  for ($i = 0; $i -lt $Domains.Count; $i++) {
    $domain = $Domains[$i]
    $days = Get-DaysLeft $domain
    $color = 'Gray'; $status = ''; $expires = ''; $st = ''

    if ($days -eq 'MISSING') { $status = T status_not_issued; $color = 'Red'; $expires = '-'; $st = 'missing' }
    elseif ($days -eq 'ERROR') { $status = T status_unreadable; $color = 'Yellow'; $expires = '?'; $st = 'error' }
    elseif ($days -lt 0) { $status = T status_expired; $color = 'Red'; $expires = "${days}d"; $st = 'expired' }
    elseif ($days -le 14) { $status = T status_critical; $color = 'Red'; $expires = "${days}d"; $st = 'critical' }
    elseif ($days -le 30) { $status = T status_expiring_soon; $color = 'Yellow'; $expires = "${days}d"; $st = 'warn' }
    else { $status = T status_valid; $color = 'Green'; $expires = "${days}d"; $st = 'ok' }

    $script:StatusMap[$i] = $st

    Write-Host ('  | {0,-2} | {1,-28} | ' -f ($i + 1), $domain) -NoNewline
    Write-Host ('{0,-14}' -f $status) -ForegroundColor $color -NoNewline
    Write-Host (' | {0,-12} |' -f $expires)
  }

  Write-Host $sep
  Write-Host ''
}

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

function Invoke-IssueCert {
  param([string]$Domain)

  if (-not $Email) {
    Warn-Msg (T issue_email_missing)
    return $false
  }

  $stagingTag = if ($Staging) { T issue_staging_tag } else { '' }
  Log "$(T issue_running_label) $Domain + *.$Domain$stagingTag"
  Write-Host (T issue_dns_hint @($Domain))
  Write-Host ''

  New-Item -ItemType Directory -Force -Path $CertbotHome | Out-Null

  $certbotArgs = @(
    'certonly'
    '--manual'
    '--preferred-challenges', 'dns'
    '--agree-tos'
    '--email', $Email
    '--expand'
    '--cert-name', $Domain
    '--config-dir', $CertbotHome
    '--work-dir', (Join-Path $CertbotHome 'work')
    '--logs-dir', (Join-Path $CertbotHome 'logs')
    '-d', $Domain
    '-d', "*.$Domain"
  )
  if ($Staging) { $certbotArgs += '--staging' }

  & $CertbotBin @certbotArgs

  if ($LASTEXITCODE -ne 0) { return $false }

  Ok-Msg (T issue_done)
  return $true
}

function Copy-Cert {
  param([string]$Domain)

  $src = Join-Path $LiveDir $Domain
  $dst = Join-Path $OutputDir $Domain

  if (-not (Test-Path $src -PathType Container)) {
    Warn-Msg (T copy_missing_src @($src))
    return $false
  }

  Log (T copy_running @($dst))
  New-Item -ItemType Directory -Force -Path $dst | Out-Null

  foreach ($f in 'fullchain.pem', 'privkey.pem', 'cert.pem', 'chain.pem') {
    Copy-Item -Path (Join-Path $src $f) -Destination (Join-Path $dst $f) -Force
  }

  try {
    icacls (Join-Path $dst 'privkey.pem') /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null
  } catch {}

  if (-not (Test-KeyMatchesCert (Join-Path $dst 'cert.pem') (Join-Path $dst 'privkey.pem'))) {
    Warn-Msg (T keys_mismatch_warning @($Domain, $dst))
    return $false
  }

  Ok-Msg (T copy_done @($dst))
  Write-Host (T copy_files_note)
  return $true
}

function Add-Domain {
  Write-Host ''
  $newDomain = (Read-Host (T add_domain_prompt)).Trim().ToLower()

  if (-not $newDomain) {
    Warn-Msg (T add_domain_empty)
    return
  }

  if ($newDomain -notmatch '^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$') {
    Warn-Msg (T add_domain_invalid @($newDomain))
    $force = Read-Host (T add_domain_confirm_anyway)
    if ($force -notmatch '^[Yy]$') { Warn-Msg (T cancelled); return }
  }

  if (Test-DomainKnown $newDomain) {
    Warn-Msg (T add_domain_known @($newDomain))
    return
  }

  $Domains.Add($newDomain)
  Add-Content -Path $DomainsFile -Value $newDomain -Encoding UTF8
  Ok-Msg (T add_domain_added @($newDomain, $DomainsFile))

  $now = Read-Host (T add_domain_issue_now)
  if ($now -match '^[Yy]$') {
    if (-not (Invoke-IssueCert $newDomain)) { return }
    Copy-Cert $newDomain | Out-Null
  }
}

function Remove-Domain {
  if ($Domains.Count -eq 0) { Warn-Msg (T table_empty); return }

  Write-Host (T remove_domain_title)
  Write-Host ''

  for ($i = 0; $i -lt $Domains.Count; $i++) {
    Write-Host ('  {0,2}) {1}' -f ($i + 1), $Domains[$i])
  }
  Write-Host ''

  $choice = Read-Host (T select_domain_prompt)
  if ($choice -eq '0') { return }
  if ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $Domains.Count) {
    Warn-Msg (T select_domain_range_err @($Domains.Count))
    return
  }

  $target = $Domains[[int]$choice - 1]
  $confirm = Read-Host (T remove_domain_confirm @($target))
  if ($confirm -notmatch '^[Yy]$') { Warn-Msg (T cancelled); return }

  if (Test-Path $DomainsFile) {
    $remaining = Get-Content $DomainsFile | Where-Object { $_.Trim() -ne $target }
    Set-Content -Path $DomainsFile -Value $remaining -Encoding UTF8
  }

  $Domains.Remove($target) | Out-Null

  Ok-Msg (T remove_domain_done @($target))
  Warn-Msg (T remove_domain_note @($target))
}

function Select-Domain {
  if ($Domains.Count -eq 0) { Warn-Msg (T table_empty); return }

  Write-Host (T select_domain_title)
  Write-Host ''

  for ($i = 0; $i -lt $Domains.Count; $i++) {
    $st = $script:StatusMap[$i]
    $hint = switch ($st) {
      'missing'  { @{ Text = (T hint_missing);  Color = 'Red' } }
      'expired'  { @{ Text = (T hint_expired);  Color = 'Red' } }
      'critical' { @{ Text = (T hint_critical); Color = 'Red' } }
      'warn'     { @{ Text = (T hint_warn);     Color = 'Yellow' } }
      'ok'       { @{ Text = (T hint_ok);       Color = 'Green' } }
      default    { @{ Text = (T hint_unknown);  Color = 'Yellow' } }
    }
    Write-Host ('  {0,2}) {1,-30} ' -f ($i + 1), $Domains[$i]) -NoNewline
    Write-Host $hint.Text -ForegroundColor $hint.Color
  }

  Write-Host ''
  $domain = $null
  while ($true) {
    $choice = Read-Host (T select_domain_prompt)
    if ($choice -eq '0') { return }
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $Domains.Count) {
      $domain = $Domains[[int]$choice - 1]
      break
    }
    Warn-Msg (T select_domain_range_err @($Domains.Count))
  }

  Write-Host ''
  Write-Host "$(T label_domain) $domain"
  Write-Host "$(T label_wildcard) *.$domain"
  Write-Host "$(T label_output) $(Join-Path $OutputDir $domain)\"
  Write-Host ''
  $confirm = Read-Host (T confirm_prompt)
  if ($confirm -notmatch '^[Yy]$') { Warn-Msg (T cancelled); return }

  if (-not (Invoke-IssueCert $domain)) { return }
  Copy-Cert $domain | Out-Null
}

function Invoke-ConvertToIisMenu {
  if ($Domains.Count -eq 0) { Warn-Msg (T table_empty); return }

  Write-Host ''
  Write-Host (T iis_menu_title)
  Write-Host (T iis_menu_note1)
  Write-Host (T iis_menu_note2)
  Write-Host ''

  for ($i = 0; $i -lt $Domains.Count; $i++) {
    Write-Host ('  {0,2}) {1}' -f ($i + 1), $Domains[$i])
  }
  Write-Host ''

  $choice = Read-Host (T select_domain_prompt)
  if ($choice -eq '0') { return }
  if ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $Domains.Count) {
    Warn-Msg (T iis_invalid_number)
    return
  }

  Convert-ToIis $Domains[[int]$choice - 1]
}

function Convert-ToIis {
  param([string]$Domain)

  $outSrc = Join-Path $OutputDir $Domain
  $liveSrc = Join-Path $LiveDir $Domain
  $certDir = $null

  if ((Test-Path (Join-Path $outSrc 'fullchain.pem')) -and (Test-Path (Join-Path $outSrc 'privkey.pem'))) {
    $certDir = $outSrc
  } elseif ((Test-Path (Join-Path $liveSrc 'fullchain.pem')) -and (Test-Path (Join-Path $liveSrc 'privkey.pem'))) {
    $certDir = $liveSrc
  } else {
    Warn-Msg (T iis_missing_cert @($Domain))
    Warn-Msg (T iis_missing_cert_hint @($outSrc))
    return
  }

  if (-not (Test-KeyMatchesCert (Join-Path $certDir 'cert.pem') (Join-Path $certDir 'privkey.pem'))) {
    Warn-Msg (T keys_mismatch_warning @($Domain, $certDir))
    return
  }

  $dst = Join-Path $OutputDir $Domain
  $pfxPath = Join-Path $dst "$Domain.pfx"
  New-Item -ItemType Directory -Force -Path $dst | Out-Null

  $gen = Read-Host (T iis_gen_password_prompt)
  if ($gen -match '^[Nn]$') {
    $secure = Read-Host (T iis_enter_password_prompt) -AsSecureString
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    if (-not $password) { Warn-Msg (T iis_empty_password); return }
  } else {
    $bytes = New-Object byte[] 18
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $password = [Convert]::ToBase64String($bytes)
  }

  Log "$(T iis_building_label) $pfxPath <- $certDir\{cert,privkey,chain}.pem"

  & openssl pkcs12 -export `
    -out $pfxPath `
    -inkey (Join-Path $certDir 'privkey.pem') `
    -in (Join-Path $certDir 'cert.pem') `
    -certfile (Join-Path $certDir 'chain.pem') `
    -name $Domain `
    -passout "pass:$password"

  if ($LASTEXITCODE -ne 0) { return }

  try {
    icacls $pfxPath /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null
  } catch {}

  Ok-Msg (T iis_done @($pfxPath))
  Write-Host ''
  Write-Host "$(T iis_password_label) $password"
  Write-Host (T iis_password_note)
  Write-Host (T iis_import_hint)
  Write-Host (T iis_binding_hint)
}

function Invoke-CheckLiveMenu {
  if ($Domains.Count -eq 0) { Warn-Msg (T table_empty); return }

  Write-Host ''
  Write-Host (T live_check_title)
  Write-Host ''

  $rows = @()

  foreach ($domain in $Domains) {
    Log "$(T live_checking @($domain))"

    $liveCert = Get-LiveCertificate -DomainName $domain
    $color = 'Gray'; $status = ''; $expires = ''
    $deployed = '?'; $deployedColor = 'DarkGray'

    if (-not $liveCert) {
      $status = T live_status_unreachable; $color = 'Red'; $expires = '-'
    } else {
      $days = [math]::Floor(($liveCert.NotAfter - (Get-Date)).TotalDays)
      if ($days -lt 0) { $status = T status_expired; $color = 'Red'; $expires = "${days}d" }
      elseif ($days -le 14) { $status = T status_critical; $color = 'Red'; $expires = "${days}d" }
      elseif ($days -le 30) { $status = T status_expiring_soon; $color = 'Yellow'; $expires = "${days}d" }
      else { $status = T status_valid; $color = 'Green'; $expires = "${days}d" }

      $localCertPath = Join-Path (Join-Path $OutputDir $domain) 'cert.pem'
      if (Test-Path $localCertPath) {
        try {
          $localCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($localCertPath)
          if ($localCert.Thumbprint -eq $liveCert.Thumbprint) {
            $deployed = T deployed_yes; $deployedColor = 'Green'
          } else {
            $deployed = T deployed_no; $deployedColor = 'Red'
          }
        } catch {}
      }
    }

    $rows += [pscustomobject]@{ Domain = $domain; Status = $status; Color = $color; Expires = $expires; Deployed = $deployed; DeployedColor = $deployedColor }
  }

  Write-Host ''
  $sep = '  +----+------------------------------+----------------+--------------+------------+'
  Write-Host $sep
  Write-Host ('  | {0,-2} | {1,-28} | {2,-14} | {3,-12} | {4,-10} |' -f '#', (T table_col_domain), (T live_table_col_status), (T table_col_expires), (T live_table_col_deployed))
  Write-Host $sep

  for ($i = 0; $i -lt $rows.Count; $i++) {
    $r = $rows[$i]
    Write-Host ('  | {0,-2} | {1,-28} | ' -f ($i + 1), $r.Domain) -NoNewline
    Write-Host ('{0,-14}' -f $r.Status) -ForegroundColor $r.Color -NoNewline
    Write-Host (' | {0,-12} | ' -f $r.Expires) -NoNewline
    Write-Host ('{0,-10}' -f $r.Deployed) -ForegroundColor $r.DeployedColor -NoNewline
    Write-Host ' |'
  }

  Write-Host $sep
  Write-Host (T live_deployed_legend)
  Write-Host ''
}

function Show-SettingsMenu {
  while ($true) {
    Clear-Screen
    Show-Header
    Write-Host ''
    Write-Host (T settings_title)
    Write-Host (T settings_email_label @($Email))
    Write-Host (T settings_output_label @($OutputDir))
    Write-Host (T settings_lang_label @($UILang))
    Write-Host (T settings_staging_label @($(if ($Staging) { T staging_on } else { T staging_off })))
    Write-Host ''
    Write-Host (T settings_opt_email)
    Write-Host (T settings_opt_output)
    Write-Host (T settings_opt_lang)
    Write-Host (T settings_opt_staging)
    Write-Host (T settings_opt_back)
    Write-Host ''
    $choice = Read-Host (T menu_prompt)
    switch ($choice) {
      '1' {
        $newEmail = Read-Host (T settings_new_email_prompt)
        if ($newEmail -match '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
          $script:Email = $newEmail
          Save-Config
          Ok-Msg (T settings_email_updated @($Email))
        } else {
          Warn-Msg (T settings_email_invalid)
        }
      }
      '2' {
        $newDir = Read-Host (T settings_new_output_prompt @($OutputDir))
        if ($newDir) {
          $script:OutputDir = $newDir
          Save-Config
          Ok-Msg (T settings_output_updated @($OutputDir))
        }
      }
      '3' {
        Select-Language
        Ok-Msg (T settings_lang_updated @($UILang))
      }
      '4' {
        $script:Staging = -not $Staging
        Save-Config
        Ok-Msg (T settings_staging_updated @($(if ($Staging) { T staging_on } else { T staging_off })))
      }
      '0' { return }
      default { Warn-Msg (T invalid_choice) }
    }
    Wait-ForEnter
  }
}

function Show-Header {
  $title = 'Wildcard Certificate Manager'
  $border = '=' * ($title.Length + 4)
  Write-Host ''
  Write-Host "  +$border+" -ForegroundColor Cyan
  Write-Host "  |  $title  |" -ForegroundColor Cyan
  Write-Host "  +$border+" -ForegroundColor Cyan
}

function Show-MainMenu {
  Write-Host (T menu_title)
  Write-Host (T menu_opt_issue)
  Write-Host (T menu_opt_add)
  Write-Host (T menu_opt_remove)
  Write-Host (T menu_opt_iis)
  Write-Host (T menu_opt_live)
  Write-Host (T menu_opt_refresh)
  Write-Host (T menu_opt_settings)
  Write-Host (T menu_opt_exit)
  Write-Host ''
  $action = Read-Host (T menu_prompt)
  switch ($action) {
    '1' { Select-Domain }
    '2' { Add-Domain }
    '3' { Remove-Domain }
    '4' { Invoke-ConvertToIisMenu }
    '5' { Invoke-CheckLiveMenu }
    '6' { Show-Table }
    '7' { Show-SettingsMenu }
    '0' { exit 0 }
    default { Warn-Msg (T invalid_choice) }
  }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Clear-Screen
Show-Header

$showedStartupNotice = $false

if ($DiscoveredCount -gt 0) {
  Write-Host ''
  Ok-Msg (T discovered_domains @($DiscoveredCount))
  $showedStartupNotice = $true
}

if (-not $Email -or $Domains.Count -eq 0) {
  Write-Host ''
  Warn-Msg (T first_run_notice)
  if (-not $Email) { Warn-Msg (T first_run_email_hint) }
  if ($Domains.Count -eq 0) { Warn-Msg (T first_run_domains_hint) }
  $showedStartupNotice = $true
}

if ($showedStartupNotice) { Wait-ForEnter }

while ($true) {
  Clear-Screen
  Show-Header
  Show-Table
  Show-MainMenu
  Wait-ForEnter
}
