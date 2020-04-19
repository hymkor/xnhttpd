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
