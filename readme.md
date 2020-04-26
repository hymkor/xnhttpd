xnhttpd
=======

Tiny Web Server to test CGI on localhost.

```
xnhttpd < sample.json
```

which starts service on localhost:8000
and calls CGI scripts on the current directory.

`sample.json` is a configuration file like below

```
{
	"handler":{
		".pl":"c:/Program Files/Git/usr/bin/perl.exe"
	}
}
```

To use sample [wiki-engine](https://github.com/zetamatta/markdowned_wifky/), open http://127.0.0.1:8000/wiki.pl with web-browser.

By defaults, when the web-browser requests a file whose suffix is `*.md`,
the built-in markdown text viewer by [goldmark](https://github.com/yuin/goldmark) runs.
