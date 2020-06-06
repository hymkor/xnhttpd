package main

import (
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Handler  map[string]string `json:"handler"`
	Markdown struct {
		Html bool `json:"html"`
	} `json:"markdown"`
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

var fileServeSuffix = map[string]string{
	".gif":  "image/gif",
	".jpg":  "image/jpg",
	".png":  "image/jpg",
	".html": "text/html",
}

func findPathInsteadOfDirectory(dir string) string {
	for _, fname := range []string{"index.html", "readme.md"} {
		path := filepath.Join(dir, fname)
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}
	return ""
}

func (this *Handler) serveHttp(w http.ResponseWriter, req *http.Request) error {
	log.Printf("%s %s %s\n", req.RemoteAddr, req.Method, req.URL.Path)
	targetPath := filepath.Join(this.workDir, filepath.FromSlash(req.URL.Path))
	stat, err := os.Stat(targetPath)
	if err != nil {
		return err
	}
	if stat.IsDir() {
		targetPath = findPathInsteadOfDirectory(targetPath)
		if targetPath == "" {
			return err
		}
	}

	suffix := path.Ext(targetPath)
	if interpreter, ok := this.Config.Handler[suffix]; ok {
		interpreter = filepath.FromSlash(interpreter)
		if err := callCgi(interpreter, targetPath, w, req,
			func(s string) { log.Println(s) }, os.Stderr); err != nil {
			return err
		}
		return nil
	}
	if contentType, ok := fileServeSuffix[suffix]; ok {
		fd, err := os.Open(targetPath)
		if err != nil {
			return err
		}
		defer fd.Close()
		w.Header().Add("Content-Type", contentType)
		if stat, err := fd.Stat(); err == nil {
			w.Header().Add("Content-Length", strconv.FormatInt(stat.Size(), 10))
		}
		w.WriteHeader(http.StatusOK)
		io.Copy(w, fd)
		return nil
	}
	if strings.EqualFold(suffix, ".md") {
		return catAsMarkdown(targetPath, w)
	}
	if strings.EqualFold(suffix, ".lua") {
		return callLuaHandler(targetPath, req, w)
	}
	return fmt.Errorf("%s: not support suffix", suffix)
}

func (this *Handler) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	if err := this.serveHttp(w, req); err != nil {
		this.notFound.ServeHTTP(w, req)
		log.Printf("%s\n", err.Error())
	}
}

func mains(args []string) error {
	var handler Handler
	for _, configFname := range args {
		fd, err := os.Open(configFname)
		if err != nil {
			return err
		}
		err = handler.Config.Read(fd)
		fd.Close()
		if err != nil {
			return err
		}
	}
	enableHtmlInMarkdown(handler.Config.Markdown.Html)
	handler.notFound = http.NotFoundHandler()
	var err error
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
