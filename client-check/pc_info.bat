@echo off
chcp 65001 >nul
REM ==========================================================
REM  Практическая работа 8, часть 2. Аудит клиентского компьютера
REM  Автор: Викторов Д.А., группа 3525П1ИН3
REM  Дата: 03.11.2026
REM
REM  Скрипт собирает сведения о компьютере, сверяет список
REM  установленных программ с эталонными списками и выдаёт
REM  рекомендации: чего не хватает для офисной работы и что
REM  установлено сверх базового набора (к проверке, не к удалению).
REM ==========================================================

REM ---------- Пути к файлам ----------
REM Отчёт лежит рядом с bat-файлом (%~dp0), временные файлы - в %TEMP%
set "REPORT=%~dp0pc_report.txt"
set "WORK=%TEMP%\pc_audit_%RANDOM%"
set "APPS=%WORK%\apps_list.txt"
set "RAW=%WORK%\apps_raw.txt"
mkdir "%WORK%" >nul 2>&1

REM Счётчики для итога
set /a CHECKED=0
set /a RECS=0

REM Отчёт создаётся заново при каждом запуске
type nul > "%REPORT%"

REM ---------- Заголовок и временная метка ----------
call :log "=========================================="
call :log "      АУДИТ КЛИЕНТСКОГО КОМПЬЮТЕРА"
call :log "=========================================="
call :log "Отчёт сформирован: %DATE% %TIME:~0,8%"
call :log "Компьютер: %COMPUTERNAME%, пользователь: %USERNAME%"
call :log ""

REM ==========================================================
REM  РАЗДЕЛ 1. Сведения о системе
REM  wmic в новых сборках Windows 11 отсутствует, поэтому данные
REM  читаются через PowerShell Get-CimInstance (подпрограмма :psget).
REM  :psget сначала очищает переменную, поэтому старое значение
REM  не может попасть в отчёт; пустой результат проверяется отдельно.
REM ==========================================================
echo [*] Сбор сведений о системе...

REM --- Операционная система ---
call :psget OS_NAME "(Get-CimInstance Win32_OperatingSystem).Caption"
call :psget OS_VER "(Get-CimInstance Win32_OperatingSystem).Version"
if not defined OS_NAME set "OS_NAME=данные получить не удалось"
if not defined OS_VER set "OS_VER=данные получить не удалось"
call :log "[Операционная система]"
call :log "  Название: %OS_NAME%"
call :log "  Версия:   %OS_VER%"
call :log "------------------------------------------"

REM --- Процессор ---
call :psget CPU_NAME "(Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()"
if not defined CPU_NAME set "CPU_NAME=данные получить не удалось"
call :log "[Процессор]"
call :log "  %CPU_NAME%"
call :log "------------------------------------------"

REM --- Оперативная память (КБ -> ГБ, делит PowerShell, 1 знак после запятой) ---
call :psget MEM_TOTAL "[math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize/1MB,1)"
call :psget MEM_FREE "[math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB,1)"
call :log "[Оперативная память]"
if defined MEM_TOTAL (call :log "  Всего памяти:    %MEM_TOTAL% ГБ") else (call :log "  Всего памяти: данные получить не удалось")
if defined MEM_FREE (call :log "  Свободно памяти: %MEM_FREE% ГБ") else (call :log "  Свободно памяти: данные получить не удалось")
call :log "------------------------------------------"

REM --- Диск C (байты -> ГБ; число байт не помещается в set /a, делит PowerShell) ---
call :psget DISK_TOTAL "[math]::Round((Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq 'C:').Size/1GB,1)"
call :psget DISK_FREE "[math]::Round((Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq 'C:').FreeSpace/1GB,1)"
call :log "[Диск C]"
if defined DISK_TOTAL (call :log "  Размер диска: %DISK_TOTAL% ГБ") else (call :log "  Размер диска: данные получить не удалось")
if defined DISK_FREE (call :log "  Свободно:     %DISK_FREE% ГБ") else (call :log "  Свободно: данные получить не удалось")
call :log "------------------------------------------"
call :log ""

REM ==========================================================
REM  РАЗДЕЛ 2. Список установленных программ -> временный файл
REM  Опрашиваются обе ветки реестра (64- и 32-битные программы)
REM  и ветка текущего пользователя. Из строки вида
REM  "    DisplayName    REG_SZ    Название" берётся только третья
REM  часть (tokens=2,* : %%a = REG_SZ, %%b = название).
REM ==========================================================
echo [*] Опрос реестра: поиск установленных программ, это может занять до минуты...
type nul > "%RAW%"
for %%K in (
    "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall"
) do (
    for /f "tokens=2,*" %%a in ('reg query %%K /s /v DisplayName 2^>nul ^| findstr /i /c:"DisplayName"') do (
        >>"%RAW%" echo(%%b
    )
)

REM Антивирус Defender не записывается в раздел Uninstall,
REM поэтому зарегистрированные антивирусы берём из Центра безопасности
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8; Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue | ForEach-Object displayName"`) do (
    >>"%RAW%" echo(%%a
)

REM Тестовый режим (шаг 8): если рядом лежит test_apps.txt, его строки
REM добавляются в список; строки из test_exclude.txt из списка убираются.
if exist "%~dp0test_apps.txt" type "%~dp0test_apps.txt" >> "%RAW%"
if exist "%~dp0test_exclude.txt" (
    findstr /i /r /v /g:"%~dp0test_exclude.txt" "%RAW%" > "%WORK%\filtered.txt"
    move /y "%WORK%\filtered.txt" "%RAW%" >nul
)

REM Сортировка и удаление повторов (одна программа часто встречается дважды)
sort /unique "%RAW%" /o "%APPS%"

set /a APP_COUNT=0
for /f "usebackq delims=" %%a in ("%APPS%") do set /a APP_COUNT+=1
call :log "[Установленные программы: %APP_COUNT%]"
if %APP_COUNT%==0 call :log "  Данные получить не удалось"
for /f "usebackq delims=" %%a in ("%APPS%") do call :log "  %%a"
call :log "------------------------------------------"
call :log ""

REM ==========================================================
REM  РАЗДЕЛ 3. Проверка базового офисного ПО
REM  Для каждой категории создаётся файл признаков, поиск идёт
REM  по списку программ без учёта регистра (findstr /i /g:).
REM  Найдено - требование выполнено; нет - конкретная рекомендация.
REM ==========================================================
echo [*] Сверка с эталонным списком базового ПО...
call :log "=========================================="
call :log " ПРОВЕРКА БАЗОВОГО ПО ОФИСНОГО РАБОЧЕГО МЕСТА"
call :log "=========================================="

> "%WORK%\need.txt" (echo Microsoft Office& echo Microsoft 365& echo LibreOffice& echo OpenOffice& echo OnlyOffice& echo МойОфис& echo MyOffice& echo WPS Office& echo Р7-Офис)
call :need "Офисный пакет" "Не обнаружен офисный пакет. Для работы с документами .docx/.xlsx рекомендуется установить LibreOffice (бесплатно) или МойОфис/Microsoft 365 по лицензии организации."

> "%WORK%\need.txt" (echo Google Chrome& echo Mozilla Firefox& echo Yandex& echo Яндекс& echo Opera& echo Vivaldi& echo Chromium)
call :need "Браузер (сторонний)" "Не обнаружен сторонний браузер, есть только встроенный Edge. Если корпоративный стандарт требует отдельный браузер, рекомендуется установить Яндекс Браузер или Firefox."
REM Edge есть в любой Windows - это компонент системы, а не результат настройки
findstr /i /l /c:"Microsoft Edge" "%APPS%" >nul && call :log "    Примечание: Microsoft Edge найден, но это встроенный компонент Windows."

> "%WORK%\need.txt" (echo Acrobat& echo Foxit& echo SumatraPDF& echo PDF-XChange& echo Okular)
call :need "Программа для чтения PDF" "Не обнаружена программа для чтения PDF. Для работы с документами и печатными формами рекомендуется установить SumatraPDF или Adobe Acrobat Reader."

> "%WORK%\need.txt" (echo 7-Zip& echo WinRAR& echo WinZip& echo PeaZip& echo Bandizip)
call :need "Архиватор" "Не обнаружен архиватор. Для работы с вложениями в почте (zip, rar, 7z) рекомендуется установить 7-Zip или WinRAR."

> "%WORK%\need.txt" (echo Windows Defender& echo Microsoft Defender& echo Kaspersky& echo ESET& echo Dr.Web& echo Avast& echo Bitdefender)
call :need "Антивирус" "Не обнаружен антивирус. Компьютер не защищён: рекомендуется включить Microsoft Defender или установить Kaspersky / ESET / Dr.Web."
call :log ""

REM ==========================================================
REM  РАЗДЕЛ 4. Проверка ПО, не относящегося к офисным задачам
REM  Четыре группы признаков. Найденное - РЕКОМЕНДАЦИЯ К ПРОВЕРКЕ,
REM  а не указание к удалению: решение принимает администратор.
REM ==========================================================
echo [*] Поиск ПО, не относящегося к базовым офисным задачам...
call :log "=========================================="
call :log " ПО, НЕ ОТНОСЯЩЕЕСЯ К БАЗОВЫМ ОФИСНЫМ ЗАДАЧАМ"
call :log " (рекомендация к проверке, а не указание к удалению)"
call :log "=========================================="

> "%WORK%\extra.txt" (echo Steam& echo Epic Games& echo GOG Galaxy& echo Origin& echo EA app& echo Ubisoft Connect& echo Battle.net& echo Riot& echo Game& echo Gaming)
call :extra "1. Игровое ПО и игровые платформы" "Игровое ПО не нужно для офисной работы, занимает место на диске и ресурсы. Проверьте, согласована ли установка."

> "%WORK%\extra.txt" (echo torrent& echo uTorrent& echo BitTorrent& echo qBittorrent& echo Vuze)
call :extra "2. Торрент-клиенты и файлообмен" "Торрент-клиенты нагружают сеть и часто являются источником нежелательного ПО. Требуется проверка в первую очередь."

> "%WORK%\extra.txt" (echo Discord& echo Telegram& echo WhatsApp& echo Viber& echo Skype)
call :extra "3. Мессенджеры для личного общения" "Проверьте, входит ли мессенджер в корпоративный стандарт: в части организаций Telegram или Skype - рабочий инструмент."

> "%WORK%\extra.txt" (echo Wallpaper Engine& echo OBS Studio& echo Soundpad& echo AIMP& echo Winamp& echo KMPlayer& echo PotPlayer& echo iTunes& echo Spotify)
call :extra "4. Развлечения и оформление" "Программы для развлечений и оформления не нужны для работы. Проверьте необходимость, если в организации есть стандартный плеер."

REM ==========================================================
REM  РАЗДЕЛ 5. Итог
REM ==========================================================
call :log ""
call :log "=========================================="
call :log " ИТОГ"
call :log "=========================================="
call :log "Проверено категорий базового ПО: %CHECKED%"
call :log "Выдано рекомендаций: %RECS%"
call :log "Отчёт сохранён: %REPORT%"
call :log "Вывод скрипта - рекомендация администратору. Решение об"
call :log "установке или удалении программ принимает человек."

REM Удаляем временные файлы
rmdir /s /q "%WORK%" >nul 2>&1

echo.
pause
exit /b


REM ==========================================================
REM  ПОДПРОГРАММЫ
REM ==========================================================

REM :log "текст" - вывод строки на экран и дописывание её в отчёт.
REM Пустой аргумент даёт пустую строку (echo( вместо echo).
REM Текст выводится через отложенное расширение (!MSG!), поэтому
REM символы < > & | ( ) в названиях программ не ломают команду.
:log
set "MSG=%~1"
setlocal EnableDelayedExpansion
if not defined MSG (
    echo(
    >>"!REPORT!" echo(
) else (
    echo(!MSG!
    >>"!REPORT!" echo(!MSG!
)
endlocal
exit /b

REM :psget ИМЯ "выражение PowerShell" - очищает переменную ИМЯ и
REM записывает в неё результат выражения (если он есть).
:psget
set "%~1="
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8; %~2"`) do set "%~1=%%a"
exit /b

REM :need "Категория" "Рекомендация" - ищет в списке программ признаки
REM из файла need.txt. Найдено - отметка и название программы,
REM не найдено - рекомендация (счётчик RECS увеличивается).
:need
set /a CHECKED+=1
set "FOUND="
for /f "usebackq delims=" %%a in (`findstr /i /r /g:"%WORK%\need.txt" "%APPS%"`) do if not defined FOUND set "FOUND=%%a"
if defined FOUND (
    call :log "[OK] %~1: требование выполнено (найдено: %FOUND%)"
) else (
    set /a RECS+=1
    call :log "[!]  %~1: %~2"
)
exit /b

REM :extra "Группа" "Пояснение" - выводит все программы из группы
REM признаков extra.txt; если ничего нет - так и пишет.
:extra
call :log "%~1"
set "HIT="
for /f "usebackq delims=" %%a in (`findstr /i /r /g:"%WORK%\extra.txt" "%APPS%"`) do (
    set "HIT=1"
    call :log "    - %%a"
)
if defined HIT (
    set /a RECS+=1
    call :log "    Рекомендация: %~2"
) else (
    call :log "    Не обнаружено."
)
exit /b
