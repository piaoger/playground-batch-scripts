@echo off


set SYSTEM_USERNAME=administrator
set SYSTEM_PWD=123456

SET MACHINE_HOST_NAME=XXXXXX
cmdkey /generic:TERMSRV/%MACHINE_HOST_NAME% /user:%SYSTEM_USERNAME% /pass:%SYSTEM_PWD%

@echo on
