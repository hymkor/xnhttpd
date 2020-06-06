package main

import (
	"net/http"
	"strings"

	"github.com/yuin/gopher-lua"
)

func callLuaHandler(targetPath string,
	req *http.Request,
	w http.ResponseWriter) error {
	L := lua.NewState()
	defer L.Close()

	var cookie strings.Builder
	for _, c := range req.Cookies() {
		if cookie.Len() > 0 {
			cookie.WriteString("; ")
		}
		cookie.WriteString(c.String())
	}

	L.SetGlobal("QUERY_STRING", lua.LString(req.URL.RawQuery))
	L.SetGlobal("CONTENT_LENGTH", lua.LString(req.ContentLength))
	L.SetGlobal("REQUEST_METHOD", lua.LString(strings.ToUpper(req.Method)))
	L.SetGlobal("HTTP_COOKIE", lua.LString(cookie.String()))
	L.SetGlobal("HTTP_USER_AGENT", lua.LString(req.UserAgent()))
	L.SetGlobal("SCRIPT_NAME", lua.LString(req.URL.Path))
	L.SetGlobal("REMOTE_ADDR", lua.LString(rxPortNo.ReplaceAllString(req.RemoteAddr, "")))

	L.SetGlobal("SetHeader", L.NewFunction(func(LL *lua.LState) int {
		end := LL.GetTop()
		for i := 1; i <= end; i += 2 {
			name := LL.Get(i).String()
			if i+1 <= end {
				w.Header().Add(name, LL.Get(i+1).String())
			} else {
				w.Header().Del(name)
			}
		}
		return 0
	}))

	output := []byte{}
	L.SetGlobal("print", L.NewFunction(func(LL *lua.LState) int {
		end := LL.GetTop()
		for i := 1; i <= end; i++ {
			if i > 1 {
				output = append(output, ' ')
			}
			output = append(output, L.Get(i).String()...)
		}
		output = append(output, '\n')
		return 0
	}))

	err := L.DoFile(targetPath)
	if err == nil {
		w.WriteHeader(http.StatusOK)
		w.Write(output)
	} else {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("<html><body><h1>Internal Server Error</h1></body></html>"))
	}
	return err
}
