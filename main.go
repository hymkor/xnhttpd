package main

import (
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
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
	Config Config
}

func (this *Handler) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	notFound := http.NotFoundHandler()
	notFound.ServeHTTP(w, req)
}

func mains(args []string) error {
	var handler Handler
	err := handler.Config.Read(os.Stdin)
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
