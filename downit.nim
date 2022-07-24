## The `Downloader` object holds all the downloads data, `initDownloader` takes the root directory for all the downloads (or `""` if none) and the poll timeout (by default 0 ms).  
## After initializing it, downloading something it's just as easy as calling `download`, procedure that takes the url, path and an optional name, if not given the path will be the name. Setting a name is useful to identify a download and makes changing the path a lot easier.  
## You can also make a GET request using the `request` procedure, passing the url and optionally a name.
## After making a download/request you can use the `downloading`, `downloaded`, `finished` and `failed` procedures to check wheter a download/request finished, is still in progress or failed.
## ```nim
# Documentation downloader
## var downloader = initDownloader("./docs")
## downloader.download("https://nim-lang.org/docs/os.html", "os.html", "os")
## downloader.request("https://nim-lang.org/docs/strformat.html", "strformat")
## 
## while true:
##   downloader.update() # Poll events and check if downloads are complete
## 
##   if downloader.succeed("os") and downloader.succeed("strformat"):
##     echo readFile(downloader.getPath("os").get())
##     echo downloader.getBody("strformat").get()
##     break
## 
##   elif downloader.getError("os").isSome: # You can also do downloader.getState("os").get() == DownloadError
##     raise downloader.getError("os").get()
## ```

import std/[asyncdispatch, httpclient, options, tables, os]

export httpclient, options

type
  DownloadState* = enum
    Downloading, Downloaded, DownloadError
  
  Download* = object
    url*, path*: string
    state*: DownloadState
    error*: ref Exception
    downFuture*: Future[void]
    requestFuture*: Future[AsyncResponse]

  Downloader* = object
    dir*: string ## Root directory for all downloads
    timeout*: int ## Poll events timeout
    downTable: Table[string, Download]

proc initDownload(url, path: string, state: DownloadState, error: ref Exception = nil, requestFuture: Future[AsyncResponse] = nil, downFuture: Future[void] = nil): Download = 
  Download(url: url, path: path, state: state, error: error, requestFuture: requestFuture, downFuture: downFuture)

proc initDownloader*(dir: string, timeout: int = 0): Downloader = 
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

proc isDownload*(self: Downloader, name: string): bool = 
  result = self.exists(name) and self.downTable[name].path.len > 0

proc isRequest*(self: Downloader, name: string): bool = 
  result = self.exists(name) and self.downTable[name].path.len == 0

proc getPath*(self: Downloader, name: string, joinDir = true): Option[string] = 
  ## Returns the path of `name` if it exists, joined with the downloader's root dir if `joinDir` is true otherwise returns the raw path.  
  ## Returns none for requests.
  if self.exists(name) and self.isDownload(name):
    if joinDir:
      result = some(self.dir / self.downTable[name].path)
    else:
      result = self.downTable[name].path.some()

proc getURL*(self: Downloader, name: string): Option[string] = 
  ## Returns the url of `name` if it exists.
  if self.exists(name):
    result = self.downTable[name].url.some()

proc getState*(self: Downloader, name: string): Option[DownloadState] = 
  ## Returns the state of `name` if it exists.
  if self.exists(name):
    result = self.downTable[name].state.some()

proc getResponse*(self: Downloader, name: string): Option[AsyncResponse] = 
  ## Returns the AsyncRespones of `name` if it finished.  
  ## Returns none for downloads.
  if self.exists(name) and self.isRequest(name) and self.downTable[name].state == Downloaded:
    result = self.downTable[name].requestFuture.read().some()

proc getBody*(self: Downloader, name: string): Option[string] = 
  ## Returns the body of `name` if it finished.  
  ## Returns none for downloads.
  if (let response = self.getResponse(name); response.isSome and response.get().body.finished):
    result = response.get().body.read().some() # body is procedure that returns a Future[string]

proc get*(self: Downloader, name: string): Option[tuple[url: string, state: DownloadState, error: ref Exception]] = 
  ## Returns the url, state and error of `name` if it exists.
  if self.exists(name):
    result = (self.getURL(name).get(), self.getState(name).get(), self.getError(name).get()).some()

proc remove*(self: var Downloader, name: string) = 
  ## Removes `name`'s file if it exists.
  if self.exists(name) and self.isDownload(name):
    if self.getPath(name).get().fileExists(): self.getPath(name).get().removeFile()

proc succeed*(self: Downloader, name: string): bool = 
  ## Returns true if `name` was downloaded/requested successfully, the path must exist if it is a download.
  result = self.exists(name) and self.getState(name).get() == Downloaded and (self.isRequest(name) or self.getPath(name).get().fileExists())

proc finished*(self: Downloader, name: string): bool = 
  ## Returns true if `name` succeed or failed.
  result = self.exists(name) and self.getState(name).get() in {Downloaded, DownloadError}

proc failed*(self: Downloader, name: string): bool = 
  ## Returns true if `name` had a DownloadError.
  result = self.exists(name) and self.getState(name).get() == DownloadError

proc running*(self: Downloader, name: string): bool = 
  ## Returns true if `name` is being downloaded/requested.
  result = self.exists(name) and self.getState(name).get() == Downloading

proc downloadImpl*(url, path: string): Future[void] {.async.} = 
  let client = newAsyncHttpClient()
  await client.downloadFile(url, path)
  client.close()

proc download*(self: var Downloader, url, path: string, name = "", replace = false) = 
  ## Starts an asynchronous download of `url` to `path`. 
  ## `path` will be used as the name if `name` is empty.  
  ## If `replace` is set to true and the file is downloaded overwrite it, otherwise if the file is downloaded and `replace` is false do nothing. 
  let name = if name.len > 0: name else: path
  if not replace and self.succeed(name): return
  
  path.splitPath.head.createDir()
  self.downTable[name] = initDownload(url, path, Downloading, downFuture = downloadImpl(url, self.dir / path))

proc requestImpl*(url: string): Future[AsyncResponse] {.async.} = 
  let client = newAsyncHttpClient()
  result = await client.get(url)
  yield result.body

  client.close()

proc request*(self: var Downloader, url: string, name = "") = 
  ## Starts an asynchronous GET request of `url`. 
  ## `url` will be used as the name if `name` is empty.  
  let name = if name.len > 0: name else: url

  self.downTable[name] = initDownload(url, "", Downloading, requestFuture = requestImpl(url))

proc downloadAgain*(self: var Downloader, name: string) = 
  ## Downloads `name` again if it exists, does nothing otherwise.
  if self.exists(name) and self.isDownload(name):
      self.download(self.getURL(name).get(), self.getPath(name, joinDir = false).get(), name, replace = true)

proc requestAgain*(self: var Downloader, name: string) = 
  ## Requests `name` again if it exists, does nothing otherwise.
  if self.exists(name) and self.isRequest(name):
    self.request(self.getURL(name).get(), name)

proc update*(self: var Downloader) = 
  ## Poll for any outstanding events and check if any download/request is complete.
  waitFor sleepAsync(self.timeout)

  for name, data in self.downTable:

    if data.state == Downloading:
      if not data.downFuture.isNil and data.downFuture.finished:
        if data.downFuture.failed:
          self.remove(name)
          self.downTable[name].state = DownloadError
          self.downTable[name].error = data.downFuture.readError()
        elif self.getPath(name).get().fileExists():
            self.downTable[name].state = Downloaded

      elif not data.requestFuture.isNil and data.requestFuture.finished:
        if data.requestFuture.failed:
          self.downTable[name].state = DownloadError
          self.downTable[name].error = data.requestFuture.readError()
        else:
          self.downTable[name].state = Downloaded
