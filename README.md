xnhttpd
=======

- CGI Server for test uses instead of [AN HTTPD](https://ja.wikipedia.org/wiki/AN_HTTPD)
- Markdown viewer
- Lua Application Server (experimental)

```
xnhttpd {OPTIONS} [SETTING-JSON-PATH]
```

* -C string
    * Working directory
* -hardwrap
    * Enable hard wrap in \*.md
* -html
    * Enable raw htmls in \*.md
* -index string
    * the default page when URL is directory (default "index.html,README.md,INDEX.md")
* -p uint
    * Port number (default 8000)
* -perl
    * Enable Perl as handler for \*.pl

which starts service on localhost:8000
and calls CGI scripts on the current directory.

The JSON for setting is like below.

```json
{
	"handler":{
		".pl":"c:/Program Files/Git/usr/bin/perl.exe"
	},
	"markdown":{
		"html":true,
		"hardwrap":true
	}
}
```

To use sample [wiki-engine](https://github.com/hymkor/markdowned_wifky/), open `http://127.0.0.1:8000/wiki.pl` with web-browser.

Markdown Viewer
---------------

When the requested url's suffix ends with `.md` and the file exists, 
the embedded markdown viewer([goldmark](https://github.com/yuin/goldmark)) runs.

If `{ "markdown":{ "html":true }}` is defined, raw-HTML-tags are available in `*.md`

Lua Application Server
----------------------

When the requested url's suffix ends with `.lua` and the file exists, 
the embedded Lua-interpretor([GopherLua](https://github.com/yuin/gopher-lua)) runs.

```lua
print("<html><body>")
print("<h1>Embedded Lua Test</h1>")

for _,key in pairs{
    "QUERY_STRING",
    "CONTENT_LENGTH",
    "REQUEST_METHOD",
    "HTTP_COOKIE",
    "HTTP_USER_AGENT",
    "SCRIPT_NAME",
    "REMOTE_ADDR",
} do
    print(string.format("<div>%s=%s</div>",esc(key),esc(_G[key])))
end

print("<hr />")

print(string.format("<div>a=%s</div>",esc(get("a"))))

print(string.format([[
<form action="%s" method="post">
<div>New `a` value</div>
<div>
<input type="text" name="a" value="%s" />
<input type="submit" />
</div>
</form>
]],esc(SCRIPT_NAME),esc(get("a"))))

local counter = cookie("counter")
if counter and counter.value then
    counter = { value= tonumber(counter.value)+1 }
else
    counter = { value=1 }
end
setcookie("counter",counter.value)

print("counter=" .. counter.value)

print("</body></html>")
```

Install
-------

Download the binary package from [Releases](https://github.com/hymkor/xnhttpd/releases) and extract the executable.

### go install

```
go install github.com/hymkor/xnhttpd
```

### scoop-installer

```
scoop install https://raw.githubusercontent.com/hymkor/xnhttpd/master/xnhttpd.json
```

or

```
scoop bucket add hymkor https://github.com/hymkor/scoop-bucket
scoop install xnhttpd
```

Author
------

- [hymkor (HAYAMA Kaoru)](https://github.com/hymkor)

LICENSE
-------

- [MIT LICENSE](./LICENSE)
