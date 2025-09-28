- 見出し文字のうち、英数字ではないシングルバイト文字が ID に入っていて、GitHub 非互換になっていた問題を修正
- 見出しに ID として使える文字が一文字もない時、`heading` ではなく、調査用に仮に設定していた`xheading` が ID として使われていた問題を修正

v0.10.0
=======
Sep 28, 2025

- markdown を HTML へ変換する時、見出しに日本語が含まれている場合でも、GitHub 互換の ID を生成するようにした

v0.9.0
=======
May 30, 2025

- MIME型を `application/octet-stream` とすべき拡張子を指定するオプション `-octet` を追加
- 可能であれば、カレントディレクトリの最後の部分をウインドウタイトルにセットするようにした
- ログ出力中のリクエストされた URL を二重引用符で囲むようにした
- 拡張子の照合は英大文字・小文字を区別しないようにした
- CGIリクエストで環境変数 `PATH_INFO` の実験的なサポートを追加
- markdown パーサーが何らかのエラーを返した時にヘッダが二重に更新されてエラーになる不具合を修正
- localhost からのリクエストの時、レスポンス中でエラーメッセージを詳細に表示するようにした

v0.8.0
=======
Nov 10, 2024

- markdown 向けのスタイルシートを https://github.com/sindresorhus/generate-github-markdown-css のものへ変更

v0.7.4
=======
Jan 5, 2024

- markdown: GitHub拡張の[タスクリスト][task list] を有効にした。

[task list]: https://github.github.com/gfm/#task-list-items-extension-

v0.7.3
=======
May 7, 2023

- 指定した拡張子をプレーンテキストとして出力するオプションを追加（例： `-plaintext .cpp.h` ）

v0.7.2
=======
May 4, 2023

- 引数 `-` を与えれば、設定用JSONテキストを標準入力から読み取れるようにした

v0.7.1
=======
May 3, 2023

- Enable parser.WithAutoHeadingID() on [goldmark]

[goldmark]: https://github.com/yuin/goldmark

v0.7.0
=======
Feb 23, 2023

- markdown で脚注をサポート
    - [goldmark] の extension.Footnote を有効化
    - CSS を最小限に修正 (font-size: .9em)

[goldmark]: https://github.com/yuin/goldmark

v0.6.0
=======
Jan 28, 2023

- Add options: `-html` , `-hardwrap` , `-index` , `-perl` , and `-p`


v0.5.0
=======
Jan 11, 2023

- マークダウンテキストでは http: や https: で始まるテキストは自動的にリンクするようにした。

v0.4.0
=======
Aug 13, 2022

- JSON の設定にソースの改行を &lt;BR /&gt; に置換する、"markdown" &gt; "hardwrap" を追加する
-  [CVE-2022-29804](https://pkg.go.dev/vuln/GO-2022-0533)  対応のため、Go のバージョンを 1.19 へ更新  
  ( https://twitter.com/mattn_jp/status/1557173238106443777 も参照のこと）
- ビルド用バッチファイル (make.cmd) の代わりに Makefile を用意

v0.3.0
=======
May 2, 2021

- GitHub風のスタイルシートを使用するようにした ( https://gist.github.com/andyferra/2554919 のものを改造 )
- URLのエスケープがされてなくて、日本語ファイル名がリクエストできない問題を修正

v0.2.0 (20200607)
=======
Jun 7, 2020

Add feature: Lua Application Server

v0.1.0 (20200518)
=======
May 18, 2020

First release ! ( Please see [the top page](https://github.com/zetamatta/xnhttpd/) to know how to use. )
