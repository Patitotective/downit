## The `Downloader` object holds all the downloads data, `initDownloader` takes the root directory for all the downloads (or `""` if none) and the poll timeout (by default 1 ms).  
## After initializing it, downloadint something it's just as easy as calling `download`, procedure that takes the url, path and an optional name, if not given the path will be the name. Setting a name is useful to identify a download and makes changing the path a lot easier.  
## After requesting a download you may want to use the `downloading` and `downloaded` procedures to check wheter a download is complete, and if it finished with an error you should use `getError` or `getErrorMsg`.  
## ```nim
## # Documentation downloader
## var downloader = initDownloader("./docs")
## downloader.download("https://nim-lang.org/docs/os.html", "os.html", "os")
## downloader.download("https://nim-lang.org/docs/strutils.html", "strutils.html", "strutils")
## downloader.download("https://nim-lang.org/docs/strformat.html", "strformat.html", "strformat")
## 
## while true:
##   downloader.update() # Poll events and check if downloads are complete
## 
##   if downloader.downloaded("os") and downloader.downloaded("strutils") and downloader.downloaded("strformat"):
##     echo readFile(downloader.getPath("os").get())
##     echo readFile(downloader.getPath("strutils").get())
##     echo readFile(downloader.getPath("strformat").get())
##     break
##   elif downloader.getError("os").isSome:
##     raise downloader.getError("os").get
## ```

import std/[asyncdispatch, httpclient, options, tables, os]

export options

type
  DownState* = enum
    NotDownloaded, Downloading, Downloaded, DownloadError
  
  Downloader* = object
    dir*: string ## Root directory for all downloads
    timeout*: int ## Poll events timeout
    downTable: Table[string, tuple[url, path: string, error: ref Exception, state: DownState, fut: Future[void]]]

proc initDownloader*(dir: string, timeout: int = 1): Downloader = 
  ## Initializes a Downloader object and creates `dir`.
  dir.createDir()
  Downloader(dir: dir, timeout: timeout)

proc exists*(self: Downloader, name: string): bool = 
  ## Returns true if a download with `name` exists.
  name in self.downTable

proc getError*(self: Downloader, name: string): Option[ref Exception] = 
  ## Returns the exception of `name` if it had a `DownloadError`.
  if self.exists(name) and self.downTable[name].state == DownloadError:
    result = self.downTable[name].error.some()

proc getErrorMsg*(self: Downloader, name: string): Option[string] = 
  ## Returns the error message of `name` if it had a `DownloadError`.
  let error = self.getError(name)
  if error.isSome:
    result = error.get().msg.some()

proc getPath*(self: Downloader, name: string, joinDir = true): Option[string] = 
  ## Returns the path of `name` if exists, joined with the downloader's root dir if `joinDir` is true otherwise returns the raw path.
  if self.exists(name):
    if joinDir:
      result = some(self.dir / self.downTable[name].path)
    else:
      result = self.downTable[name].path.some()

proc getURL*(self: Downloader, name: string): Option[string] = 
  ## Returns the url of `name` if exists.
  if self.exists(name):
    result = self.downTable[name].url.some()

proc getState*(self: Downloader, name: string): Option[DownState] = 
  ## Returns the state of `name` if exists.
  if self.exists(name):
    result = self.downTable[name].state.some()

proc remove*(self: var Downloader, name: string) = 
  ## Removes `name`'s path if it exists and set the state to `NotDownloaded`.
  if self.exists(name):
    if self.getPath(name).get().fileExists(): self.getPath(name).get().removeFile()
    self.downTable[name].state = NotDownloaded

proc downloaded*(self: Downloader, name: string): bool = 
  ## Returns true if `name` is downloaded AND the path exists.
  if self.exists(name) and self.getState(name).get() == Downloaded and self.getPath(name).get().fileExists():
    result = true

proc downloading*(self: Downloader, name: string): bool = 
  ## Returns true if `name` is being downloaded.
  if self.exists(name) and self.getState(name).get() == Downloading:
    result = true

proc download*(self: var Downloader, url, path: string, name = "", replace = false) = 
  ## Starts an asynchronous download of `url` to `path`. 
  ## `path` will be used as the name if `name` is empty.  
  ## If `replace` is set to true and the file is downloaded overwrite it, otherwise if the file is downloaded and `replace` is false do nothing. 
  if not replace and self.downloaded(if name.len > 0: name else: path): return
  
  path.splitPath.head.createDir()
  
  self.downTable[if name.len > 0: name else: path] = (url, path, nil, Downloading, newAsyncHttpClient().downloadFile(url, self.dir / path))

proc downloadAgain*(self: var Downloader, name: string) = 
  ## Downloads `name` again if exists, does nothing otherwise.
  if self.exists(name):
    self.download(self.getURL(name).get(), self.getPath(name, joinDir = false).get(), name, replace = true)

proc update*(self: var Downloader) = 
  ## Poll for any outstanding events and check if any download is complete.
  waitFor sleepAsync(self.timeout)

  for name, data in self.downTable:
    if data.fut.finished and data.state == Downloading:
      if data.fut.failed:
        self.remove(name)
        self.downTable[name].state = DownloadError
        self.downTable[name].error = data.fut.readError()
      elif self.getPath(name).get().fileExists():
        self.downTable[name].state = Downloaded
