# DownIt
Asynchronous downloads manager.

## Usage
The `Downloader` object holds all the downloads data, `initDownloader` takes the root directory for all the downloads (or `""` if none) and the poll timeout (by default 1 ms).  
After initializing it, downloadint something it's just as easy as calling `download`, procedure that takes the url, path and an optional name, if not given the path will be the name. Setting a name is useful to identify a download and makes changing the path a lot easier.  
After requesting a download you may want to use the `downloading` and `downloaded` procedures to check wheter a download is complete, and if it finished with an error you should use `getError` or `getErrorMsg`.  
```nim
# Documentation downloader
var downloader = initDownloader("./docs")
downloader.download("https://nim-lang.org/docs/os.html", "os.html", "os")
downloader.download("https://nim-lang.org/docs/strutils.html", "strutils.html", "strutils")
downloader.download("https://nim-lang.org/docs/strformat.html", "strformat.html", "strformat")

while true:
  downloader.update() # Poll events and check if downloads are complete

  if downloader.downloaded("os") and downloader.downloaded("strutils") and downloader.downloaded("strformat"):
    echo readFile(downloader.getPath("os").get())
    echo readFile(downloader.getPath("strutils").get())
    echo readFile(downloader.getPath("strformat").get())
    break
  elif downloader.getError("os").isSome:
    raise downloader.getError("os").get
```
Remember to compile with `-d:ssl`.

Read more at the [docs](https://patitotective.github.io/downit)

## About
- GitHub: https://github.com/Patitotective/ImTemplate.
- Discord: https://discord.gg/as85Q4GnR6.

Contact me:
- Discord: **Patitotective#0127**.
- Twitter: [@patitotective](https://twitter.com/patitotective).
- Email: **cristobalriaga@gmail.com**.
