package main

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"strings"
)

var rxPortNo = regexp.MustCompile(`:\d+$`)

func callCgi(interpreter, script string,
	w http.ResponseWriter,
	req *http.Request,
	logger func(string), cgierr io.Writer) error {

	cmd := exec.Command(interpreter, script)
	toCgi, err := cmd.StdinPipe()
	if err != nil {
		return err
	}

	var cookie strings.Builder
	for _, c := range req.Cookies() {
		if cookie.Len() > 0 {
			cookie.WriteString("; ")
		}
		cookie.WriteString(c.String())
	}

	env := []string{
		"QUERY_STRING=" + req.URL.RawQuery,
		fmt.Sprintf("CONTENT_LENGTH=%d", req.ContentLength),
		"REQUEST_METHOD=" + strings.ToUpper(req.Method),
		"HTTP_COOKIE=" + cookie.String(),
		"HTTP_USER_AGENT=" + req.UserAgent(),
		"SCRIPT_NAME=" + req.URL.Path,
		"REMOTE_ADDR=" + rxPortNo.ReplaceAllString(req.RemoteAddr, ""),
	}
	cmd.Env = append(env, os.Environ()...)

	fromCgi, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	go func() {
		br := bufio.NewReader(fromCgi)
		defer fromCgi.Close()
		for {
			line, err := br.ReadString('\n')
			if err != nil {
				break
			}
			line = strings.TrimSpace(line)
			f := strings.SplitN(line, ": ", 2)
			if len(f) < 2 {
				w.WriteHeader(http.StatusOK)
				io.Copy(w, br)
				return
			}
			w.Header().Add(f[0], f[1])
		}
	}()

	cmd.Stderr = cgierr
	cmd.Start()
	if logger != nil {
		logger(fmt.Sprintf("Call \"%s\" \"%s\"", interpreter, script))
	}
	io.Copy(toCgi, req.Body)
	toCgi.Close()
	req.Body.Close()
	cmd.Wait()
	if logger != nil {
		logger(fmt.Sprintf("Done \"%s\" \"%s\"", interpreter, script))
	}
	return nil
}
