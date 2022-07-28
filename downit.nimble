# Package

version       = "0.2.1"
author        = "Patitotective"
description   = "An asynchronous donwload system."
license       = "MIT"


# Dependencies

requires "nim >= 1.6.5"

task docs, "Generate documentation":
  exec "nim doc --git.url:https://github.com/Patitotective/downit --git.commit:main --project --outdir:docs downit.nim"
  exec "echo \"<meta http-equiv=\\\"Refresh\\\" content=\\\"0; url='downit.html'\\\" />\" >> docs/index.html"
