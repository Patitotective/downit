# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import std/[unittest, os]

import downit

var downloader = initDownloader("tests/downloads")

test "can download and request":
  downloader.download("https://nim-lang.org/docs/os.html", "os.html", "os")
  downloader.download("https://nim-lang.osrg/docs/strutils.html", "strutils.html", "strutils") # Bad URL
  downloader.request("https://github.com/Patitotective/ImTemplate/blob/main/ImExample.nimble?raw=true", "ImExample")
  downloader.request("https://github.com/nim-lang/packages/blob/master/packages.json?raw=true", "packages")

  var count = 0
  while true:
    if count >= 1000:
      raise newException(ValueError, "Too many iterations")

    downloader.update()

    if downloader.succeed("os") and downloader.failed("strutils") and downloader.succeed("ImExample") and downloader.succeed("packages"):
      break

    inc count

  check downloader.getPath("os").get().fileExists()
  check downloader.getError("strutils").get().name == "OSError"
  check downloader.getResponse("ImExample").get().status == "200 OK"
  check downloader.getResponse("packages").get().status == "200 OK"
