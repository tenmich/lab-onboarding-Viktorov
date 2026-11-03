@echo off
chcp 65001 >nul
REM ==========================================================
REM  Практическая работа 8. Диагностика клиентского компьютера
REM  Автор: Викторов Д.А., группа 3525П1ИН3
REM  Дата: 03.11.2026
REM  Примечание: в этой сборке Windows 11 утилита wmic удалена,
REM  поэтому те же классы (Win32_OperatingSystem, Win32_Processor,
REM  Win32_LogicalDisk) читаются через PowerShell Get-CimInstance.
REM ==========================================================

REM Отчёт создаётся рядом с самим bat-файлом
set "REPORT=%~dp0pc_report.txt"
set PS=powershell -NoProfile -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8;

REM ---------- Заголовок ----------
echo ==========================================
echo         ДИАГНОСТИКА КОМПЬЮТЕРА
echo ==========================================
echo ==========================================> "%REPORT%"
echo         ДИАГНОСТИКА КОМПЬЮТЕРА>> "%REPORT%"
echo ==========================================>> "%REPORT%"
echo Дата проверки: %DATE% %TIME:~0,8%
echo Дата проверки: %DATE% %TIME:~0,8%>> "%REPORT%"
echo.
echo.>> "%REPORT%"

REM ---------- Операционная система ----------
for /f "usebackq delims=" %%a in (`%PS% (Get-CimInstance Win32_OperatingSystem).Caption"`) do set "OS_NAME=%%a"
for /f "usebackq delims=" %%a in (`%PS% (Get-CimInstance Win32_OperatingSystem).Version"`) do set "OS_VER=%%a"
echo [Операционная система]
echo   Название: %OS_NAME%
echo   Версия:   %OS_VER%
echo [Операционная система]>> "%REPORT%"
echo   Название: %OS_NAME%>> "%REPORT%"
echo   Версия:   %OS_VER%>> "%REPORT%"
echo ------------------------------------------
echo ------------------------------------------>> "%REPORT%"

REM ---------- Процессор ----------
REM Берём только поле Name, без имени класса и служебных строк
for /f "usebackq delims=" %%a in (`%PS% (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()"`) do set "CPU_NAME=%%a"
echo [Процессор]
echo   %CPU_NAME%
echo [Процессор]>> "%REPORT%"
echo   %CPU_NAME%>> "%REPORT%"
echo ------------------------------------------
echo ------------------------------------------>> "%REPORT%"

REM ---------- Оперативная память ----------
REM Значения приходят в килобайтах, переводим в ГБ: делим на 1048576
for /f "usebackq delims=" %%a in (`%PS% (Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize"`) do set "MEM_TOTAL_KB=%%a"
for /f "usebackq delims=" %%a in (`%PS% (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory"`) do set "MEM_FREE_KB=%%a"
set /a MEM_TOTAL_GB=MEM_TOTAL_KB/1048576
set /a MEM_FREE_GB=MEM_FREE_KB/1048576
echo [Оперативная память]
echo   Всего памяти:    %MEM_TOTAL_GB% ГБ
echo   Свободно памяти: %MEM_FREE_GB% ГБ
echo [Оперативная память]>> "%REPORT%"
echo   Всего памяти:    %MEM_TOTAL_GB% ГБ>> "%REPORT%"
echo   Свободно памяти: %MEM_FREE_GB% ГБ>> "%REPORT%"
echo ------------------------------------------
echo ------------------------------------------>> "%REPORT%"

REM ---------- Диск C ----------
REM Размер диска в байтах не помещается в 32-битное set /a,
REM поэтому деление на 1073741824 выполняет PowerShell
for /f "usebackq delims=" %%a in (`%PS% [math]::Floor((Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq 'C:').Size/1073741824)"`) do set "DISK_TOTAL_GB=%%a"
for /f "usebackq delims=" %%a in (`%PS% [math]::Floor((Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq 'C:').FreeSpace/1073741824)"`) do set "DISK_FREE_GB=%%a"
echo [Диск C]
echo   Размер диска: %DISK_TOTAL_GB% ГБ
echo   Свободно:     %DISK_FREE_GB% ГБ
echo [Диск C]>> "%REPORT%"
echo   Размер диска: %DISK_TOTAL_GB% ГБ>> "%REPORT%"
echo   Свободно:     %DISK_FREE_GB% ГБ>> "%REPORT%"
echo ------------------------------------------
echo ------------------------------------------>> "%REPORT%"

REM ---------- Установленные программы ----------
REM Читаем реестр (64- и 32-битные программы), оставляем только DisplayName.
REM tokens=2,* : %%a = тип REG_SZ, %%b = само название программы
echo [Установленные программы]
echo [Установленные программы]>> "%REPORT%"
for /f "tokens=2,*" %%a in ('reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s /v DisplayName 2^>nul ^| findstr /i "DisplayName"') do (
    echo   %%b
    echo   %%b>> "%REPORT%"
)
for /f "tokens=2,*" %%a in ('reg query "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /v DisplayName 2^>nul ^| findstr /i "DisplayName"') do (
    echo   %%b
    echo   %%b>> "%REPORT%"
)
echo ==========================================
echo ==========================================>> "%REPORT%"

REM ---------- Завершение ----------
echo.
echo Отчёт сохранён: %REPORT%
pause
