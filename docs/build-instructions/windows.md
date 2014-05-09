# Windows

## Requirements

  * Windows 7 or later
  * [Visual C++ 2010 SP1 Express](http://www.visualstudio.com/en-us/downloads/download-visual-studio-vs#DownloadFamilies_4)
  * [node.js - 32bit](http://nodejs.org/download/) v0.10.x
  * [Python 2.7.x](http://www.python.org/download/)
  * [GitHub for Windows](http://windows.github.com/)
    to your PATH
  * Open the Windows GitHub shell (NOT the Standard PowerShell, the shortcut labeled 'Git Shell' - make sure you have logged in at least once to the GitHub for Windows GUI App)
  * `$env:Path = $env:Path + ";C:\path\to\atom\repo\node_modules"`

## Instructions

  ```bat
  cd C:\Users\<user>\github
  git clone https://github.com/atom/atom/
  cd atom
  script\build
  ```

## Troubleshooting
