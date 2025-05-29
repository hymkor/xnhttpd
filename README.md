xnhttpd
=======

- A simple CGI server for testing, as an alternative to [AN HTTPD](https://ja.wikipedia.org/wiki/AN_HTTPD)
- Markdown viewer
- Experimental Lua application server

```
xnhttpd {OPTIONS} [SETTING-JSON-PATH]
```

Options
-------

- `-C string`
  Working directory

- `-hardwrap`
  Enable hard wrap in `*.md`

- `-html`
  Enable raw HTML in `*.md`

- `-index string`
  Default page when the URL points to a directory (default: `"index.html,README.md,INDEX.md"`)

- `-p uint`
  Port number (default: `8000`)

- `-perl`
  Enable Perl as a handler for `*.pl`

This starts a local server on `localhost:8000` and allows CGI scripts to run from the current directory.

## Example Setting JSON

```json
{
  "handler": {
    ".pl": "c:/Program Files/Git/usr/bin/perl.exe"
  },
  "markdown": {
    "html": true,
    "hardwrap": true
  }
}
```

To try the sample [wiki engine](https://github.com/hymkor/markdowned_wifky/), open [`http://127.0.0.1:8000/wiki.pl`](http://127.0.0.1:8000/wiki.pl) in your browser.

---

## Markdown Viewer

When a requested URL ends with `.md` and the file exists, the embedded Markdown viewer ([goldmark](https://github.com/yuin/goldmark)) renders it.

If `"html": true` is set in the JSON config, raw HTML tags are allowed in Markdown files.

---

## Lua Application Server (Experimental)

When a requested URL ends with `.lua` and the file exists, the embedded Lua interpreter ([GopherLua](https://github.com/yuin/gopher-lua)) runs the script.

Example:

```lua
print("<html><body>")
print("<h1>Embedded Lua Test</h1>")

for _, key in pairs{
  "QUERY_STRING", "CONTENT_LENGTH", "REQUEST_METHOD",
  "HTTP_COOKIE", "HTTP_USER_AGENT", "SCRIPT_NAME", "REMOTE_ADDR"
} do
  print(string.format("<div>%s=%s</div>", esc(key), esc(_G[key])))
end

print("<hr />")

print(string.format("<div>a=%s</div>", esc(get("a"))))

print(string.format([[
<form action="%s" method="post">
  <div>New `a` value</div>
  <div>
    <input type="text" name="a" value="%s" />
    <input type="submit" />
  </div>
</form>
]], esc(SCRIPT_NAME), esc(get("a"))))

local counter = cookie("counter")
if counter and counter.value then
  counter = { value = tonumber(counter.value) + 1 }
else
  counter = { value = 1 }
end
setcookie("counter", counter.value)

print("counter=" .. counter.value)
print("</body></html>")
```

## Installation

### Download

Download a binary from the [Releases](https://github.com/hymkor/xnhttpd/releases) page and extract the executable.

### Via `go install`

```
go install github.com/hymkor/xnhttpd@latest
```

### Via Scoop

```
scoop install https://raw.githubusercontent.com/hymkor/xnhttpd/master/xnhttpd.json
```

or:

```
scoop bucket add hymkor https://github.com/hymkor/scoop-bucket
scoop install xnhttpd
```

Author
------

- [hymkor (HAYAMA Kaoru)](https://github.com/hymkor)

License
-------

- [MIT License](./LICENSE)
