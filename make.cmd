@echo off
setlocal
call :"%1"
endlocal
exit /b

:""
:"all"
    go build
    exit /b

:"package"
    set /P "VERSION=Version ? (x.y.z) "
    for %%I in (linux windows.exe) do (
        set "GOOS=%%~nI"
        @for %%J in (386 amd64) do @(
            set "GOARCH=%%J"
            go build
            zip xnhttpd-%VERSION%-%%~nI-%%J.zip xnhttpd%%~xI
        )
    )
    echo off
    exit /b
