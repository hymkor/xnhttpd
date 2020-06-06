package main

import (
	"net/http"
	"strings"

	"github.com/yuin/gopher-lua"
)

var escapeList = strings.NewReplacer(
	"&", "&amp;",
	"<", "&lt;",
	">", "&gt;")

func getAllCookie(req *http.Request) string {
	cookie := []byte{}
	for _, c := range req.Cookies() {
		if len(cookie) > 0 {
			cookie = append(cookie, "; "...)
		}
		cookie = append(cookie, c.String()...)
	}
	return string(cookie)
}

func callLuaHandler(targetPath string,
	req *http.Request,
	w http.ResponseWriter) error {
	L := lua.NewState()
	defer L.Close()

	L.SetGlobal("QUERY_STRING", lua.LString(req.URL.RawQuery))
	L.SetGlobal("CONTENT_LENGTH", lua.LNumber(req.ContentLength))
	L.SetGlobal("REQUEST_METHOD", lua.LString(strings.ToUpper(req.Method)))
	L.SetGlobal("HTTP_COOKIE", lua.LString(getAllCookie(req)))
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

	L.SetGlobal("get", L.NewFunction(func(LL *lua.LState) int {
		key := LL.Get(1).String()
		val := req.FormValue(key)
		L.Push(lua.LString(val))
		return 1
	}))

	L.SetGlobal("esc", L.NewFunction(func(LL *lua.LState) int {
		end := LL.GetTop()
		for i := 1; i <= end; i++ {
			val := LL.Get(i).String()
			val = escapeList.Replace(val)
			L.Push(lua.LString(val))
		}
		return end
	}))

	L.SetGlobal("cookie", L.NewFunction(func(LL *lua.LState) int {
		name := LL.Get(1).String()
		cookie, err := req.Cookie(name)
		if err != nil {
			L.Push(lua.LNil)
			L.Push(lua.LString(err.Error()))
			return 2
		}
		tbl := L.NewTable()
		L.SetField(tbl, "name", lua.LString(cookie.Name))
		L.SetField(tbl, "value", lua.LString(cookie.Value))
		L.SetField(tbl, "path", lua.LString(cookie.Path))
		L.SetField(tbl, "domain", lua.LString(cookie.Domain))
		L.SetField(tbl, "expire", lua.LString(cookie.Expires.String()))
		L.SetField(tbl, "maxage", lua.LNumber(cookie.MaxAge))
		if cookie.Secure {
			L.SetField(tbl, "secure", lua.LTrue)
		} else {
			L.SetField(tbl, "secure", lua.LFalse)
		}
		L.SetField(tbl, "raw", lua.LString(cookie.Raw))
		L.Push(tbl)
		return 1
	}))

	L.SetGlobal("setcookie", L.NewFunction(func(LL *lua.LState) int {
		if L.GetTop() < 2 {
			L.Push(lua.LNil)
			L.Push(lua.LString("too few arguments"))
			return 2
		}
		cookie := &http.Cookie{
			Name: L.Get(1).String(),
		}
		value := L.Get(2)
		if tbl, ok := value.(*lua.LTable); ok {
			cookie.Value = L.GetField(tbl, "value").String()
		} else {
			cookie.Value = value.String()
		}
		http.SetCookie(w, cookie)
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
