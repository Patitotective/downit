# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import std/[unittest, os]

import downit

var downloader = initDownloader("tests/downloads")

test "can download":
  downloader.download("https://nim-lang.org/docs/os.html", "os.html", "os")
  downloader.download("https://nim-lang.osrg/docs/strutils.html", "strutils.html", "strutils") # Bad URL

  while true:
    downloader.update()

    if downloader.downloaded("os"):
      check downloader.getPath("os").get().fileExists()
      break

  while true:
    downloader.update()

    if downloader.getError("strutils").isSome:
      break
