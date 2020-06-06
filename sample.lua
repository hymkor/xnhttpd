print("<html><body>")
print("<h1>Embbed Lua TEST</h1>")

function decode(s)
    return string.gsub(s,"%%[0-9A-Fa-f][0-9A-Fa-f]",function(p)
        return string.char(tonumber("0x"..string.sub(p,2)))
    end)
end

function esc(s)
    s = string.gsub(s,"&","&amp;")
    s = string.gsub(s,"<","&lt;")
    s = string.gsub(s,">","&gt;")
    return s
end

for _,key in pairs{
    "QUERY_STRING",
    "CONTENT_LENGTH",
    "REQUEST_METHOD",
    "HTTP_COOKIE",
    "HTTP_USER_AGENT",
    "SCRIPT_NAME",
    "REMOTE_ADDR",
} do
    print(string.format("<div>%s=%s</div>",esc(key),esc(decode(_G[key]))))
end
print("</body></html>")
