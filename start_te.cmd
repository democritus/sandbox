@echo off

rem
rem Arguments
rem
set TraceLevel=OFF
if /i "%1"=="on" set TraceLevel=ON

rem
rem Configure path to directory that contains InfoConnect's versioned directories
rem
set InfoConnectBasePath=u:\ua\te

rem
rem Configure default values for InfoConnect's directory and executable
rem
set InfoConnectVersion=9.1b
set InfoConnectDirectory=infocn91b
set InfoConnectExe=goual.exe

rem
rem Override values if OS is Windows XP
rem
ver | find "5.1" && set InfoConnectVersion=7.5ub && set InfoConnectDirectory=infocn75ub && set InfoConnectExe=goco.exe

rem
rem Change to InfoConnect's directory
rem
echo Loading Attachmate Infoconnect %InfoConnectVersion% for United Airlines... please wait
cd /d %InfoConnectBasePath%\%InfoConnectDirectory%

rem
rem Launch InfoConnect
rem
rem %InfoConnectExe% VENDOR=SITA TRACE=%TraceLevel%

rem debugging start
@echo on
%InfoConnectExe% VENDOR=SITA TRACE=%TraceLevel%
pause
rem debugging end
