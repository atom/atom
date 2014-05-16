# Windows

## Requirements

  * Windows 7 or later
  * [Visual C++ 2010 SP1 Express](http://www.visualstudio.com/en-us/downloads/download-visual-studio-vs#DownloadFamilies_4)
  * [node.js - 32bit](http://nodejs.org/download/) v0.10.x
  * [Python 2.7.x](http://www.python.org/download/)
  * [GitHub for Windows](http://windows.github.com/)
  * Log in to the GitHub for Windows GUI App
  * Open the `Git Shell` app which was installed by GitHub for Windows.

## Instructions

  ```bat
  git clone https://github.com/atom/atom/
  cd atom
  script\build
  ```

## Why do I have to use GitHub for Windows? Can't I just use my existing Git?

You totally can! GitHub for Windows's Git Shell just takes less work to set up.
You need to have Posix tools in your `%PATH%` (i.e. `grep`, `sed`, et al.),
which isn't the default configuration when you install Git. To fix this, you
probably need to fiddle with your system PATH.

## Troubleshooting

### Common Errors
* `node is not recognized`

  * If you just installed node you need to restart your computer before node is
  available on your Path.

* `Running "download-atom-shell" task aborts due to warnings`
  
  * Run script/build again
