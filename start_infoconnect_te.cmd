@echo off

rem
rem Configure path to directory that contains InfoConnect's versioned directories
rem
set InfoConnectBasePath=U:\ua\te

rem
rem Configure default values for InfoConnect's directory and executable
rem
set InfoConnectVersion=9.1b
set InfoConnectDirectory=infocn91b
set InfoConnectCommand=SITA_goual.cmd

rem
rem Override values if OS is Windows XP
rem
ver | find "5.1"
if %errorlevel% EQU 0 (
  set InfoConnectVersion=7.5ub
  set InfoConnectDirectory=infocn75ub
  set InfoConnectCommand=SITA_goco.cmd
)

rem
rem Change to InfoConnect's directory
rem
echo Loading Attachmate InfoConnect %InfoConnectVersion% for United Airlines... please wait
cd /d %InfoConnectBasePath%\%InfoConnectDirectory%

rem
rem Launch InfoConnect
rem
@echo on
%InfoConnectCommand%
@echo off
rem pause
