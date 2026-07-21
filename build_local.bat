@echo off
cd /d "D:\Work\prj\flutter\center_control_app\android"
set GRADLE_HOME=C:\Users\YSL\.gradle\wrapper\dists\gradle-8.14-all\8mguqc37c200i71ledpgw8n5m\gradle-8.14
set PATH=%GRADLE_HOME%\bin;%PATH%
set org.gradle.offline=true
gradle.bat assembleDebug
pause