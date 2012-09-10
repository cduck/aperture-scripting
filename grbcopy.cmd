@echo off
setlocal
lua "%~dpn0" %*
endlocal
exit /B %ERRORLEVEL%
