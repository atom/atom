# Windows

## Requirements

  * Windows 7 or later
  * [Visual C++ 2010 Express](http://www.visualstudio.com/en-us/downloads/download-visual-studio-vs#DownloadFamilies_4) with [SP1](http://www.microsoft.com/en-us/download/details.aspx?id=23691)
  * [node.js](http://nodejs.org/download/) v0.10.x
  * [Python](http://www.python.org/download/) v2.7.x
  * [GitHub for Windows](http://windows.github.com/)

## Instructions

  ```bat
  # Use the `Git Shell` app which was installed by GitHub for Windows. Also Make
  # sure you have logged into the GitHub for Windows GUI App.
  cd C:\
  git clone https://github.com/atom/atom/
  cd atom
  script\build
  ```

## Why do I have to use GitHub for Windows?

You don't, You can use your existing Git! GitHub for Windows's Git Shell is just
easier to set up. You need to have Posix tools in your `%PATH%` (i.e. `grep`,
`sed`, et al.), which isn't the default configuration when you install Git. To
fix this, you probably need to fiddle with your system PATH.

## Troubleshooting

### Common Errors
* `node is not recognized`

  * If you just installed node you need to restart your computer before node is
  available on your Path.
