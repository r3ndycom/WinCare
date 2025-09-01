@echo off
:: =====================================
:: WinCare - Windows Maintenance All-in-One
:: Auto-update via GitHub r3ndycom
:: =====================================

:: -------------------------------
:: Auto-update MD5 dari GitHub
:: -------------------------------
set SCRIPT_URL=https://raw.githubusercontent.com/r3ndycom/WinCare/main/WinCare.bat
set TEMP_SCRIPT=%TEMP%\WinCare_new.bat

powershell -Command "try { Invoke-WebRequest -Uri '%SCRIPT_URL%' -OutFile '%TEMP_SCRIPT%' -UseBasicParsing; exit 0 } catch { exit 1 }"

certutil -hashfile "%~f0" MD5 | find /i /v "hash" | find /i /v "CertUtil" > "%TEMP%\local_md5.txt"
set /p LOCAL_MD5=<"%TEMP%\local_md5.txt"

certutil -hashfile "%TEMP_SCRIPT%" MD5 | find /i /v "hash" | find /i /v "CertUtil" > "%TEMP%\new_md5.txt"
set /p NEW_MD5=<"%TEMP%\new_md5.txt"

if NOT "%LOCAL_MD5%"=="%NEW_MD5%" (
    echo File baru terdeteksi! Mengupdate WinCare...
    move /y "%TEMP_SCRIPT%" "%~f0"
    start "" "%~f0"
    exit
)

:: -------------------------------
:: Cek hak admin
:: -------------------------------
NET SESSION >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit
)

title WinCare - Windows Maintenance All-in-One
setlocal enabledelayedexpansion

:: -------------------------------
:: Folder & log
:: -------------------------------
if not exist "C:\Windows\scripts" mkdir "C:\Windows\scripts"
set LOGFILE=C:\Windows\scripts\WindowsUpdateLog.txt
echo ================================ >> "%LOGFILE%"
echo [%date% %time%] Script dijalankan >> "%LOGFILE%"

:: -------------------------------
:: Deteksi arsitektur
:: -------------------------------
set "ARCH=%PROCESSOR_ARCHITECTURE%"
if /i "%ARCH%"=="AMD64" set "ARCH=x64"
if /i "%ARCH%"=="x86" set "ARCH=x86"
echo [%date% %time%] Arsitektur OS: %ARCH% >> "%LOGFILE%"

:: ================================
:MENU
cls
echo ================================
echo Pilih opsi:
echo 1. Nonaktifkan Windows Update sekarang
echo 2. Aktifkan Windows Update sementara (2/3/7 hari)
echo 3. Cek status Windows Update
echo 4. Reset Windows Update Default
echo 5. Aktifkan Windows Update segera
echo 6. Hapus cache Windows Update
echo 7. Download Browser (Auto Detect x64/x86)
echo 8. Repair Windows Defender
echo 9. Manage Startup (Rapi dan Aman)
echo 10. Download dan Jalankan ESET Online Scanner
echo 11. Keluar
echo ================================
set /p choice="Masukkan pilihan [1-11] lalu tekan Enter: "

if "%choice%"=="1" (call :DisableUpdate & goto MENU)
if "%choice%"=="2" (call :EnableTempUpdate & goto MENU)
if "%choice%"=="3" (call :CheckStatus & goto MENU)
if "%choice%"=="4" (call :ResetWindowsUpdate & goto MENU)
if "%choice%"=="5" (call :EnableUpdate & goto MENU)
if "%choice%"=="6" (call :ClearCache & goto MENU)
if "%choice%"=="7" (call :DownloadBrowser & goto MENU)
if "%choice%"=="8" (call :RepairDefender & goto MENU)
if "%choice%"=="9" (call :ManageStartup & goto MENU)
if "%choice%"=="10" (call :InstallESET & goto MENU)
if "%choice%"=="11" (echo Script selesai. & pause & exit)
goto MENU

:: =====================================
:: Windows Update Subroutines
:: =====================================
:DisableUpdate
sc query wuauserv | find "RUNNING" >nul
if not errorlevel 1 net stop wuauserv
sc config wuauserv start= disabled
echo [%date% %time%] Windows Update dinonaktifkan >> "%LOGFILE%"
pause
goto MENU

:EnableUpdate
sc config wuauserv start= auto
net start wuauserv
echo [%date% %time%] Windows Update diaktifkan >> "%LOGFILE%"
pause
goto MENU

:EnableTempUpdate
set /p DURASI_DAY="Masukkan jumlah hari aktif Windows Update sementara [2/3/7]: "
for /f %%i in ('powershell -NoProfile -Command "(Get-Date).AddDays(%DURASI_DAY%).ToString('yyyy-MM-dd')"') do set SCHED_DATE=%%i
schtasks /create /tn "EnableWindowsUpdateTemp" /tr "powershell -Command 'Start-Process \"C:\\Windows\\scripts\\EnableUpdate.bat\" -Verb RunAs'" /sc once /st 00:00 /sd !SCHED_DATE! /rl highest /f
echo [%date% %time%] Windows Update sementara diaktifkan selama %DURASI_DAY% hari >> "%LOGFILE%"
pause
goto MENU

:CheckStatus
for /f "tokens=3" %%s in ('sc query wuauserv ^| findstr "STATE"') do set STATUS=%%s
cls
echo ================================
echo Status Windows Update:
if /i "!STATUS!"=="RUNNING" (echo [ACTIVE] Windows Update berjalan.) else (echo [INACTIVE] Windows Update berhenti.)
echo [%date% %time%] Status Windows Update dicek >> "%LOGFILE%"
pause
goto MENU

:ResetWindowsUpdate
net stop wuauserv >nul 2>&1
rd /s /q "%windir%\SoftwareDistribution"
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f >nul 2>&1
sc config wuauserv start= auto
net start wuauserv
echo [%date% %time%] Windows Update direset >> "%LOGFILE%"
pause
goto MENU

:ClearCache
takeown /f "%windir%\SoftwareDistribution" /r /d y >nul
icacls "%windir%\SoftwareDistribution" /grant Administrators:F /t >nul
rd /s /q "%windir%\SoftwareDistribution\Download"
echo [%date% %time%] Cache Windows Update dihapus >> "%LOGFILE%"
pause
goto MENU

:: =====================================
:: Repair Windows Defender
:: =====================================
:RepairDefender
cls
echo Memperbaiki Windows Defender...
sc query WinDefend | find "RUNNING" >nul
if errorlevel 1 (
    sc config WinDefend start= auto
    net start WinDefend >nul 2>&1
)
sc query MpsSvc | find "RUNNING" >nul
if errorlevel 1 (
    sc config MpsSvc start= auto
    net start MpsSvc >nul 2>&1
)
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Defender" /f >nul 2>&1
if exist "%ProgramFiles%\Windows Defender\MpCmdRun.exe" (
    "%ProgramFiles%\Windows Defender\MpCmdRun.exe" -SignatureUpdate
)
echo [%date% %time%] Windows Defender diperbaiki >> "%LOGFILE%"
pause
goto MENU

:: =====================================
:: Download Browser
:: =====================================
:DownloadBrowser
cls
echo Pilih browser:
echo 1. Microsoft Edge
echo 2. Google Chrome
echo 3. Mozilla Firefox
echo 4. Opera
set /p browser="Masukkan pilihan [1-4] lalu tekan Enter: "

if "%browser%"=="1" if "%ARCH%"=="x64" set "URL=https://go.microsoft.com/fwlink/?LinkID=2093437#/setup.msi"
if "%browser%"=="1" if "%ARCH%"=="x86" set "URL=https://go.microsoft.com/fwlink/?LinkID=2093505#/setup.msi"
if "%browser%"=="2" if "%ARCH%"=="x64" set "URL=https://dl.google.com/release2/chrome/AAB4yU4o/GoogleChromeStandaloneEnterprise64.msi"
if "%browser%"=="2" if "%ARCH%"=="x86" set "URL=https://dl.google.com/release2/chrome/AAB4yU4o/GoogleChromeStandaloneEnterprise.msi"
if "%browser%"=="3" if "%ARCH%"=="x64" set "URL=https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"
if "%browser%"=="3" if "%ARCH%"=="x86" set "URL=https://download.mozilla.org/?product=firefox-latest-ssl&os=win&lang=en-US"
if "%browser%"=="4" if "%ARCH%"=="x64" set "URL=https://download.opera.com/download/get/?id=73280&location=424&nothanks=yes&sub=marine&utm_tryagain=yes"
if "%browser%"=="4" if "%ARCH%"=="x86" set "URL=https://download.opera.com/download/get/?id=73279&location=424&nothanks=yes&sub=marine&utm_tryagain=yes"

set FILE=%TEMP%\browser_installer.exe
powershell -Command "try { Invoke-WebRequest -Uri '%URL%' -OutFile '%FILE%' -UseBasicParsing; exit 0 } catch { exit 1 }"
if exist "%FILE%" (
    start /wait "" "%FILE%" /silent /verysilent /install
    if exist "%FILE%" del /f /q "%FILE%"
)
pause
goto MENU

:: =====================================
:: Manage Startup (Stabil)
:: =====================================
:ManageStartup
cls
echo ==================================================
echo Startup Manager - Pilih dan Hapus (Rapi & Aman)
echo ==================================================
setlocal enabledelayedexpansion
set COUNT=0
set SEEN=

:: Folder Startup user
echo Folder Startup user:
for %%f in ("%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*") do (
    if exist "%%f" (
        set "VAL=file|%%f"
        if "!SEEN!" not contains "!VAL!" (
            set /a COUNT+=1
            set "STARTUP[!COUNT!]=!VAL!"
            set "SEEN=!SEEN! !VAL! "
            echo !COUNT!. %%~nxf
        )
    )
)
if !COUNT! EQU 0 echo (Kosong)

:: Registry Current User
echo.
echo Startup Registry (Current User):
for /f "tokens=1*" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" 2^>nul') do (
    if "%%a" NEQ "" (
        set "VAL=regcu|%%a"
        if "!SEEN!" not contains "!VAL!" (
            set /a COUNT+=1
            set "STARTUP[!COUNT!]=!VAL!"
            set "SEEN=!SEEN! !VAL! "
            echo !COUNT!. %%a - %%b
        )
    )
)

:: Registry All Users
echo.
echo Startup Registry (All Users):
for /f "tokens=1*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" 2^>nul') do (
    if "%%a" NEQ "" (
        set "VAL=reglu|%%a"
        if "!SEEN!" not contains "!VAL!" (
            set /a COUNT+=1
            set "STARTUP[!COUNT!]=!VAL!"
            set "SEEN=!SEEN! !VAL! "
            echo !COUNT!. %%a - %%b
        )
    )
)

:DELETE_LOOP
echo.
set /p delnum="Masukkan nomor item yang ingin dihapus (0 untuk selesai): "
if "%delnum%"=="0" goto END_MANAGE
if not defined STARTUP[%delnum%] (
    echo Nomor tidak valid!
    goto DELETE_LOOP
)
set "ITEM=!STARTUP[%delnum%]!"
for /f "tokens=1,2 delims=|" %%x in ("!ITEM!") do (
    set "TYPE=%%x"
    set "VAL=%%y"
)
if "!TYPE!"=="file" (
    if exist "!VAL!" del /f /q "!VAL!"
    echo [%date% %time%] File !VAL! dihapus >> "%LOGFILE%"
) else if "!TYPE!"=="regcu" (
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "!VAL!" /f >nul 2>&1
    echo [%date% %time%] Registry HKCU !VAL! dihapus >> "%LOGFILE%"
) else if "!TYPE!"=="reglu" (
    reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "!VAL!" /f >nul 2>&1
    echo [%date% %time%] Registry HKLM !VAL! dihapus >> "%LOGFILE%"
)
set "STARTUP[%delnum%]="
goto DELETE_LOOP

:END_MANAGE
pause
endlocal
goto MENU

:: =====================================
:: ESET Online Scanner
:: =====================================
:InstallESET
cls
set "ESET_URL=https://download.eset.com/com/eset/tools/online_scanner/latest/esetonlinescanner.exe"
set "ESET_FILE=%TEMP%\eset_online.exe"
powershell -Command "try { Invoke-WebRequest -Uri '%ESET_URL%' -OutFile '%ESET_FILE%' -UseBasicParsing; exit 0 } catch { exit 1 }"
if exist "%ESET_FILE%" (
    start /wait "" "%ESET_FILE%" /S
    if exist "%ESET_FILE%" del /f /q "%ESET_FILE%"
)
pause
goto MENU
