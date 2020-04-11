package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

type Config struct {
	Handler map[string]string `json:"handler"`
}

func (this *Config) Read(r io.Reader) error {
	bin, err := ioutil.ReadAll(r)
	if err != nil {
		return err
	}
	return json.Unmarshal(bin, this)
}

type Handler struct {
	Config   Config
	workDir  string
	notFound http.Handler
}

var rxPortNo = regexp.MustCompile(`:\d+$`)

func (this *Handler) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	suffix := path.Ext(req.URL.Path)
	interpreter, ok := this.Config.Handler[suffix]
	if !ok {
		this.notFound.ServeHTTP(w, req)
		return
	}
	script := filepath.Join(this.workDir, filepath.FromSlash(req.URL.Path))
	log.Printf("%s %s\n", interpreter, script)
	cmd := exec.Command(filepath.FromSlash(interpreter), script)
	toCgi, err := cmd.StdinPipe()
	if err != nil {
		log.Fatal(err)
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
		log.Fatal(err)
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

	cmd.Stderr = os.Stderr
	cmd.Start()
	log.Println("Start")
	// io.Copy(toCgi, io.TeeReader(req.Body, os.Stderr))
	// fmt.Fprintln(os.Stderr)
	io.Copy(toCgi, req.Body)
	toCgi.Close()
	req.Body.Close()
	cmd.Wait()
	log.Println("Done")
}

func mains(args []string) error {
	var handler Handler
	err := handler.Config.Read(os.Stdin)
	if err != nil {
		return err
	}
	handler.notFound = http.NotFoundHandler()
	handler.workDir, err = os.Getwd()
	if err != nil {
		return err
	}
	service := &http.Server{
		Addr:           ":8000",
		Handler:        &handler,
		ReadTimeout:    10 * time.Second,
		WriteTimeout:   10 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}
	err = service.ListenAndServe()
	closeErr := service.Close()
	if err != nil {
		return err
	}
	return closeErr
}

func main() {
	if err := mains(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}
