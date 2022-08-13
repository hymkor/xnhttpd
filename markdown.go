package main

import (
	_ "embed"
	"fmt"
	"io/ioutil"
	"net/http"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark-meta"
	"github.com/yuin/goldmark/extension"
	goldmarkHtml "github.com/yuin/goldmark/renderer/html"
)

//go:embed github.css
var gitHubCss string

const htmlHeader = `<html>
<head>
<style type="text/css"><!--
%s
// -->
</style>
</head><body>`

const htmlFooter = `<hr />
Generated by <a href="https://github.com/hymkor/xnhttpd">xnhttpd</a>
Powered by <a href="https://github.com/yuin/goldmark">goldmark</a>
and <a href="https://gist.github.com/andyferra/2554919">github.css</a>
</body></html>`

var markdownReader goldmark.Markdown

var markdownOptions = []goldmark.Option{
	goldmark.WithExtensions(extension.Table),
	goldmark.WithExtensions(meta.New(meta.WithTable())),
}

func setMarkdownOptions(enableHtml bool, hardwrap bool) {
	if enableHtml {
		markdownOptions = append(markdownOptions,
			goldmark.WithRendererOptions(goldmarkHtml.WithUnsafe()))
	}
	if hardwrap {
		markdownOptions = append(markdownOptions,
			goldmark.WithRendererOptions(goldmarkHtml.WithHardWraps()))
	}
	markdownReader = goldmark.New(markdownOptions...)
}

func catAsMarkdown(path string, w http.ResponseWriter) error {
	source, err := ioutil.ReadFile(path)
	if err != nil {
		return err
	}
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, htmlHeader, gitHubCss)
	if markdownReader == nil {
		setMarkdownOptions(false, false)
	}
	err = markdownReader.Convert(source, w)

	fmt.Fprintln(w, htmlFooter)
	return err
}
