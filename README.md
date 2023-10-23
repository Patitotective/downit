# DownIt
Asynchronous downloads and requests manager library for Nim.

```
nimble install downit
```

## Usage
The `Downloader` object holds all the downloads data, `initDownloader` takes the root directory for all the downloads (or `""` if none) and the poll timeout (by default 1 ms).  
After initializing it, downloading something it's just as easy as calling `download`, procedure that takes the url, path and an optional name, if not given the path will be the name. Setting a name is useful to identify a download and makes changing the path a lot easier.  
You can also make a GET request using the `request` procedure, passing the url and optionally a name.
After making a download/request you can use the `running`, `succeed`, `finished` and `failed` procedures to check wheter a download/request finished, is still in progress or failed.
```nim
# Documentation downloader
var downloader = initDownloader("./docs")
downloader.download("https://nim-lang.org/docs/os.html", "os.html", "os")
downloader.request("https://nim-lang.org/docs/strformat.html", "strformat")

while true:
  downloader.update() # Poll events and check if downloads are complete

  if downloader.succeed("os") and downloader.succeed("strformat"):
    echo readFile(downloader.getPath("os").get())
    echo downloader.getBody("strformat").get()
    break

  elif downloader.getError("os").isSome: # You can also do downloader.getState("os").get() == DownloadError
    raise downloader.getError("os").get()
```
Remember to compile with `-d:ssl`.

Read more at the [docs](https://patitotective.github.io/downit)

## About
- GitHub: https://github.com/Patitotective/downit.
- Discord: https://discord.gg/U23ZQMsvwc.

Contact me:
- Discord: **Patitotective#0127**.
- Twitter: [@patitotective](https://twitter.com/patitotective).
- Email: **cristobalriaga@gmail.com**.
