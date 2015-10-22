# Windows

## Requirements

### General
  * [Node.js](http://nodejs.org/en/download/) v4.x
  * [Python](https://www.python.org/downloads/) v2.7.x
    * The python.exe must be available at `%SystemDrive%\Python27\python.exe`.
      If it is installed elsewhere, you can create a symbolic link to the
      directory containing the python.exe using:
      `mklink /d %SystemDrive%\Python27 D:\elsewhere\Python27`
  * [GitHub Desktop](http://desktop.github.com/)

### On Windows 7
  * [Visual Studio 2013 Update 5](http://www.visualstudio.com/en-us/downloads/download-visual-studio-vs#DownloadFamilies_4)

### On Windows 8 or 10
  * [Visual Studio Express 2013 or 2015 for Windows Desktop](http://www.visualstudio.com/en-us/downloads/download-visual-studio-vs#DownloadFamilies_2)
    * To ensure that node-gyp knows what version of Visual Studio is installed, set the `GYP_MSVS_VERSION` environment variable to the Visual Studio version (e.g. `2013` or `2015`)

## Instructions

```bash
# Use the Git Shell program which was installed by GitHub Desktop
cd C:\
git clone https://github.com/atom/atom/
cd atom
script/build # Creates application in the `Program Files` directory
```
Note: If you use cmd or Powershell instead of Git Shell, use a backslash instead: i.e. `script\build`.
These instructions will assume the use of Git Shell.

### `script/build` Options
  * `--install-dir` - Creates the final built application in this directory.
  * `--build-dir` - Build the application in this directory.
  * `--verbose` - Verbose mode. A lot more information output.

## Why do I have to use GitHub Desktop?

You don't. You can use your existing Git! GitHub Desktop's Git Shell is just easier to set up.

If you _prefer_ using your existing Git installation, make sure git's cmd directory is in your PATH env variable (e.g. `C:\Program Files (x86)\Git\cmd`) before you open your powershell or command window.
Note that you may have to open your command window as administrator. For powershell that doesn't seem to always be the case, though.

If none of this works, do install Github Desktop and use its Git shell. Makes life easier.

## Troubleshooting

### Common Errors
* `node is not recognized`

  * If you just installed node, you'll need to restart your computer before node is
  available on your Path.

* `script/build` outputs only the Node and Python versions before returning

  * Try moving the repository to `C:\atom`. Most likely, the path is too long.
    See [issue #2200](https://github.com/atom/atom/issues/2200).

* `error MSB4025: The project file could not be loaded. Invalid character in the given encoding.`

  * This can occur because your home directory (`%USERPROFILE%`) has non-ASCII
    characters in it. This is a bug in [gyp](https://code.google.com/p/gyp/)
    which is used to build native node modules and there is no known workaround.
    * https://github.com/TooTallNate/node-gyp/issues/297
    * https://code.google.com/p/gyp/issues/detail?id=393

* `script/build` stops at installing runas with `Failed at the runas@x.y.z install script.`

  * See the next item.

* `error MSB8020: The build tools for Visual Studio 2010 (Platform Toolset = 'v100') cannot be found.`

  * If you're building Atom with Visual Studio 2013 or above make sure the `GYP_MSVS_VERSION` environment variable is set, and then re-run `script/build`:

    ```bash
    $env:GYP_MSVS_VERSION='2013' # '2015' if using Visual Studio 2015, and so on
    script/build
    ```
  * If you are using Visual Studio 2013 or above and the build fails with some other error message this environment variable might still be required.

* Other `node-gyp` errors on first build attempt, even though the right node and python versions are installed.
  * Do try the build command one more time, as experience shows it often works on second try in many of these cases.

### Windows build error reports in atom/atom
* If all fails, use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Awindows&type=Issues) to get a list of reports about build errors on Windows, and see if yours has already been reported.
    * If it hasn't, please open a new issue with your Windows version, architecture (x86 or amd64), and a screenshot of your build output, including the Node and Python versions.
