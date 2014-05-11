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
  
## Why do I have to use GitHub for Windows? Can't I just use my existing Git?

You totally can! GitHub for Windows's Git Shell just takes less work to set up. You need to have Posix tools in your `%PATH%` (i.e. `grep`, `sed`, et al.), which isn't the default configuration when you install Git. To fix this, you probably need to fiddle with your system PATH.

## Troubleshooting

Some of the most common errors include:

    gyp WARN install got an error, rolling back install
and

    >> The system cannot find the path specified.

These two error messages can usually be ignored. The solution to these errors is to re-run `script\build`, possibly several times.

If your Visual Studio is in a non-standard location, and you get the error `You must have Visual Studio 2010 or 2012 installed`, you need to modify `apm\node_modules\atom-package-manager\lib\config.js` around line 90 and replace the variable with your Visual Studio directory plus Common7/IDE.

Example:

    vs2010Path = "H:/VS2010/Common7/IDE"