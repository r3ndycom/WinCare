@echo off
:: =====================================
:: WinCare - Windows Maintenance All-in-One
:: Auto-update via GitHub r3ndycom
:: =====================================

:: -------------------------------
:: Auto-update MD5 dari GitHub dengan feedback singkat & countdown
:: -------------------------------
set SCRIPT_URL=https://raw.githubusercontent.com/r3ndycom/WinCare/main/WinCare.bat
set TEMP_SCRIPT=%TEMP%\WinCare_new.bat

:: Memeriksa apakah script sudah dijalankan dengan hak admin
if not defined ADMIN_CHECK (
    set ADMIN_CHECK=NotAdmin
)

if "%ADMIN_CHECK%"=="NotAdmin" (
    echo Memeriksa Pembaruan pertama kali...
    set "ADMIN_CHECK=Admin"
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit
)

:: Jika sudah dengan hak admin, lakukan pengecekan pembaruan
echo Mengecek Pembaruan...

:: Menggunakan PowerShell untuk mendownload script terbaru
powershell -Command "try { Invoke-WebRequest -Uri '%SCRIPT_URL%' -OutFile '%TEMP_SCRIPT%' -ErrorAction Stop } catch { exit 1 }"
if errorlevel 1 (
    echo GAGAL: Internet tidak tersedia atau belum terhubung!
    echo Melanjutkan dalam 5 detik...
    timeout /t 5 /nobreak >nul
    goto :MENU
)

echo Menghitung MD5 file lokal...
certutil -hashfile "%~f0" MD5 | find /i /v "hash" | find /i /v "CertUtil" > "%TEMP%\local_md5.txt"
set /p LOCAL_MD5=<"%TEMP%\local_md5.txt"

echo Menghitung MD5 file terbaru dari GitHub...
certutil -hashfile "%TEMP_SCRIPT%" MD5 | find /i /v "hash" | find /i /v "CertUtil" > "%TEMP%\new_md5.txt"
set /p NEW_MD5=<"%TEMP%\new_md5.txt"

if "%LOCAL_MD5%"=="%NEW_MD5%" (
    echo Versi sudah terbaru.
    echo Melanjutkan dalam 5 detik...
    timeout /t 5 /nobreak >nul
) else (
    echo File baru terdeteksi! Mengupdate WinCare...
    move /y "%TEMP_SCRIPT%" "%~f0" >nul 2>&1
    if errorlevel 1 (
        echo GAGAL: Tidak bisa memperbarui file!
        echo Melanjutkan dalam 5 detik...
        timeout /t 5 /nobreak >nul
    ) else (
        echo Update SUKSES!
        echo Melanjutkan dalam 5 detik...
        timeout /t 5 /nobreak >nul
        start "" "%~f0"
        exit
    )
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
echo Melanjutkan dalam 5 detik...
timeout /t 5 /nobreak >nul
goto MENU

:EnableUpdate
sc config wuauserv start= auto
net start wuauserv
echo [%date% %time%] Windows Update diaktifkan >> "%LOGFILE%"
echo Melanjutkan dalam 5 detik...
timeout /t 5 /nobreak >nul
goto MENU

:EnableTempUpdate
set /p DURASI_DAY="Masukkan jumlah hari aktif Windows Update sementara [2/3/7]: "
for /f %%i in ('powershell -NoProfile -Command "(Get-Date).AddDays(%DURASI_DAY%).ToString('yyyy-MM-dd')"') do set SCHED_DATE=%%i
schtasks /create /tn "EnableWindowsUpdateTemp" /tr "powershell -Command 'Start-Process \"C:\\Windows\\scripts\\EnableUpdate.bat\" -Verb RunAs'" /sc once /st 00:00 /sd !SCHED_DATE! /rl highest /f
echo [%date% %time%] Windows Update sementara diaktifkan selama %DURASI_DAY% hari >> "%LOGFILE%"
echo Melanjutkan dalam 5 detik...
timeout /t 5 /nobreak >nul
goto MENU

:CheckStatus
for /f "tokens=3" %%s in ('sc query wuauserv ^| findstr "STATE"') do set STATUS=%%s
cls
echo ================================
echo Status Windows Update:
if /i "!STATUS!"=="RUNNING" (echo [ACTIVE] Windows Update berjalan.) else (echo [INACTIVE] Windows Update berhenti.)
echo [%date% %time%] Status Windows Update dicek >> "%LOGFILE%"
echo Melanjutkan dalam 5 detik...
timeout /t 5 /nobreak >nul
goto MENU

:ResetWindowsUpdate
net stop wuauserv >nul 2>&1
rd /s /q "%windir%\SoftwareDistribution"
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f >nul 2>&1
sc config wuauserv start= auto
net start wuauserv
echo [%date% %time%] Windows Update direset >> "%LOGFILE%"
echo Melanjutkan dalam 5 detik...
timeout /t 5 /nobreak >nul
goto MENU

:ClearCache
takeown /f "%windir%\SoftwareDistribution" /r /d y >nul
icacls "%windir%\SoftwareDistribution" /grant Administrators:F /t >nul
rd /s /q "%windir%\SoftwareDistribution\Download"
echo [%date% %time%] Cache Windows Update dihapus >> "%LOGFILE%"
echo Melanjutkan dalam 5 detik...
timeout /t 5 /nobreak >nul
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
if exist "%SystemRoot%\System32\mpcmdrun.exe" (
    "%SystemRoot%\System32\mpcmdrun.exe" -scan
    echo [%date% %time%] Windows Defender diperbaiki dan menjalankan pemindaian >> "%LOGFILE%"
) else (
    echo Gagal memperbaiki Windows Defender. >> "%LOGFILE%"
)
echo Melanjutkan dalam 5 detik...
timeout /t 5 /nobreak >nul
goto MENU
