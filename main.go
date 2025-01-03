package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

var (
	flagIndex     = flag.String("index", "index.html,README.md,INDEX.md", "the default page when URL is directory")
	flagPerl      = flag.Bool("perl", false, "Enable Perl as handler for *.pl")
	flagPort      = flag.Uint64("p", 8000, "Port number")
	flagWd        = flag.String("C", "", "Working directory")
	flagHtml      = flag.Bool("html", false, "Enable raw htmls in *.md")
	flagWrap      = flag.Bool("hardwrap", false, "Enable hard wrap in *.md")
	flagPlainText = flag.String("plaintext", "", "output files with specified `suffixes` as plaintext(e.g., -plaintext .cpp.h)")
	flatOctet     = flag.String("octet", "", "output files with specified `suffixes` as application/octet-stream(e.g., `-octet .xlsx.pdf`)")
)

type Config struct {
	Handler  map[string]string `json:"handler"`
	Markdown struct {
		Html     bool `json:"html"`
		HardWrap bool `json:"hardwrap"`
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
	".txt":  "text/plain",
}

func findPathInsteadOfDirectory(dir string) string {
	for _, fname := range strings.Split(*flagIndex, ",") {
		path := filepath.Join(dir, fname)
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}
	return ""
}

func (this *Handler) serveHttp(w http.ResponseWriter, req *http.Request) error {
	log.Printf("%s %s \"%s\"\n", req.RemoteAddr, req.Method, req.URL.Path)
	targetPath, err := url.QueryUnescape(req.URL.Path)
	if err != nil {
		return err
	}
	targetPath = filepath.Join(this.workDir, filepath.FromSlash(targetPath))

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
	if *flagWd != "" {
		os.Chdir(*flagWd)
	}

	var handler Handler
	for _, configFname := range args {
		var fd io.ReadCloser
		var err error
		if configFname == "-" {
			fd = io.NopCloser(os.Stdin)
		} else {
			fd, err = os.Open(configFname)
			if err != nil {
				return err
			}
		}
		err = handler.Config.Read(fd)
		fd.Close()
		if err != nil {
			return err
		}
	}
	if *flagPerl {
		perlFullPath, err := exec.LookPath("perl")
		if err != nil {
			return err
		}
		if handler.Config.Handler == nil {
			handler.Config.Handler = make(map[string]string)
		}
		handler.Config.Handler[".pl"] = perlFullPath
	}
	if *flagHtml {
		handler.Config.Markdown.Html = true
	}
	if *flagWrap {
		handler.Config.Markdown.HardWrap = true
	}
	if t := *flagPlainText; t != "" {
		for {
			first, next, found := strings.Cut(t, ".")
			if first != "" {
				fileServeSuffix["."+first] = "text/plain"
			}
			if !found {
				break
			}
			t = next
		}
	}
	if b := *flatOctet; b != "" {
		for {
			first, next, found := strings.Cut(b, ".")
			if first != "" {
				fileServeSuffix["."+first] = "application/octet-stream"
			}
			if !found {
				break
			}
			b = next
		}
	}

	setMarkdownOptions(handler.Config.Markdown.Html, handler.Config.Markdown.HardWrap)
	handler.notFound = http.NotFoundHandler()
	var err error
	handler.workDir, err = os.Getwd()
	if err != nil {
		return err
	}
	service := &http.Server{
		Addr:           ":" + strconv.FormatUint(*flagPort, 10),
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

var version string

func main() {
	flag.Parse()
	if wd, err := os.Getwd(); err == nil {
		fmt.Printf("\x1B]0;xnhttpd on %s\x1B\\\r",
			filepath.Base(wd))
	}
	fmt.Fprintf(os.Stderr, "%s %s-%s-%s by %s\n",
		filepath.Base(os.Args[0]),
		version,
		runtime.GOOS,
		runtime.GOARCH,
		runtime.Version())
	if err := mains(flag.Args()); err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}
