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

func (this *Handler) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	suffix := path.Ext(req.URL.Path)
	interpreter, ok := this.Config.Handler[suffix]
	if !ok {
		this.notFound.ServeHTTP(w, req)
		return
	}
	script := filepath.Join(this.workDir, filepath.FromSlash(req.URL.Path))
	if _, err := os.Stat(script); err != nil {
		log.Printf("%s\n", err.Error())
		this.notFound.ServeHTTP(w, req)
		return
	}
	interpreter = filepath.FromSlash(interpreter)
	log.Printf("\"%s\" \"%s\"\n", interpreter, script)
	if err := callCgi(interpreter, script, w, req, os.Stderr, os.Stderr); err != nil {
		log.Fatal(err.Error())
	}
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
