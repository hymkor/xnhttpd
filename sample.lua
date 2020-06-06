print("<html><body>")
print("<h1>Embbed Lua Test</h1>")

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

print("</body></html>")
