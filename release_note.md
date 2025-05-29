* Added the `-octet` option to specify file extensions that should be served with the MIME type `application/octet-stream`.
* Set the window title to the last component of the current directory path, if possible.
* Enclosed the path part of the requested URL in double quotes in the log output.
* Made file extension matching in request paths case-insensitive.
* Added experimental support for the `PATH_INFO` environment variable in CGI requests.
* Fixed: Avoided duplicate `WriteHeader` calls in the HTTP handler, which previously caused runtime warnings and broken connections when markdown rendering failed.

v0.8.0
======
Nov 10, 2024

- Change the stylesheet for markdown to https://github.com/sindresorhus/generate-github-markdown-css

v0.7.4
======
Jan 5, 2024

- markdown: enable [Task list items](https://github.github.com/gfm/#task-list-items-extension-)

v0.7.3
======
May 7, 2023

- Add new option: -plaintext

v0.7.2
======
May 4, 2023

- JSON text for configuration can be read from stdin by giving argument `-`

v0.7.1
======
May 3, 2023

- Enable parser.WithAutoHeadingID() on [goldmark]

v0.7.0
======
Feb 23, 2023

- On markdown, support footnote
  - Enable extension.Footnote of [goldmark] and modify CSS minimum (font-size: .9em)

[goldmark]: https://github.com/yuin/goldmark

v0.6.0
======
Jan 28, 2023

- Add options: -html,-hardwrap,-index,-perl, and -p

v0.5.0
======
Jan 11, 2023

- On markdown, link the text starting with http: and https: automaticcaly

v0.4.0
======
Aug 13, 2022

- Add json-setting "markdown" > "hardwrap" to replace newline of the markdown source to <BR />.
- Update go version to 1.19 for CVE-2022-29804  
  (See also: https://twitter.com/mattn_jp/status/1557173238106443777)
- Create a Makefile instead of the batchfile (make.cmd) to build.

v0.3.0
======
May 2, 2021

- Use github-like stylesheet https://gist.github.com/andyferra/2554919
- Fix that url was not escaped and the Japanese filename could not be requested.

v0.2.0
======
Jun 7,2022

- Add feature: Lua Application Server

v0.1.0
======
May 18, 2020

- The first release
