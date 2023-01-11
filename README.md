xnhttpd
=======

xnhttpd is

- Markdown viewer
- CGI Server
- Lua Application Server (experimental)

```
xnhttpd
```

or

```
xnhttpd sample.json
```
which starts service on localhost:8000
and calls CGI scripts on the current directory.

`sample.json` is a configuration file like below

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

To use sample [wiki-engine](https://github.com/zetamatta/markdowned_wifky/), open http://127.0.0.1:8000/wiki.pl with web-browser.

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
