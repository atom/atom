# Windows

## Requirements

### General
 * [Node.js](https://nodejs.org/en/download/) v4.x
 * [Python](https://www.python.org/downloads/) v2.7.x
    * The python.exe must be available at `%SystemDrive%\Python27\python.exe`.
      If it is installed elsewhere, you can create a symbolic link to the
      directory containing the python.exe using:
      `mklink /d %SystemDrive%\Python27 D:\elsewhere\Python27`

### Visual Studio

You can use any of the following:

 * [Visual C++ Build Tools 2015](http://landinghub.visualstudio.com/visual-cpp-build-tools)
 * [Visual Studio 2013 Update 5](https://www.visualstudio.com/en-us/downloads/download-visual-studio-vs) (Express Edition or better)
 * [Visual Studio 2015](https://www.visualstudio.com/en-us/downloads/download-visual-studio-vs) (Community Edition or better)

Whichever version you use, ensure that:

 * The default installation folder is chosen so the build tools can find it
 * Visual C++ support is selected/installed if using Visual Studio
 * Windows 8 SDK is selected/installed if using Visual C++ Build Tools
 * A `git` command is in your path
 * The `GYP_MSVS_VERSION` environment variable is set to the corresponding Visual Studio/Build Tools version (`2013` or `2015`)

## Instructions

You can run these commands using Command Prompt, PowerShell, Git Shell, or any other terminal. These instructions will assume the use of Command Prompt.

```cmd
cd C:\
git clone https://github.com/atom/atom/
cd atom
script\build
```
This will create the Atom application in the `out\Atom` folder as well as copy it to `%LOCALAPPDATA%\Atom\app-dev`.

### `script\build` Options
  * `--install-dir` - Creates the final built application in this directory. Example:
```cmd
script\build --install-dir Z:\Some\Destination\Directory
```
  * `--build-dir` - Build the application in this directory. Example:
```cmd
script\build --build-dir Z:\Some\Temporary\Directory
```
  * `--no-install` - Skips the installation task after building.
  * `--verbose` - Verbose mode. A lot more information output.

## Troubleshooting

### Common Errors
* `node is not recognized`
  * If you just installed Node.js, you'll need to restart Command Prompt before the node command is available.

* `msbuild.exe failed with exit code: 1`
   * If you installed Visual Studio, ensure you have Visual C++ support installed. Go into Add/Remove Programs, select Visual Studio, press Modify, and then check the Visual C++ box.
   * If you installed Visual C++ Build Tools, ensure you have Windows 8 SDK support installed.  Go into Add/Remove Programs, select Visual Studio, press Modify and then check the Windows 8 SDK box.

* `script\build` stops with no error or warning shortly after displaying the versions of node, npm and Python
  * Make sure that the path where you have checked out Atom does not include a space (use `C:\atom` and not `C:\my stuff\atom`).

* `script\build` outputs only the Node.js and Python versions before returning
  * Try moving the repository to `C:\atom`. Most likely, the path is too long.
    See [issue #2200](https://github.com/atom/atom/issues/2200).

* `error MSB4025: The project file could not be loaded. Invalid character in the given encoding.`
  * This can occur because your home directory (`%USERPROFILE%`) has non-ASCII
    characters in it. This is a bug in [gyp](https://code.google.com/p/gyp/)
    which is used to build native Node.js modules and there is no known workaround.
    * https://github.com/TooTallNate/node-gyp/issues/297
    * https://code.google.com/p/gyp/issues/detail?id=393

* `'node_modules\.bin\npm' is not recognized as an internal or external command, operable program or batch file.`
   * This occurs if the previous build left things in a bad state. Run `script\clean` and then `script\build` again.

* `script\build` stops at installing runas with `Failed at the runas@x.y.z install script.`
  * See the next item.

* `error MSB8020: The build tools for Visual Studio 201? (Platform Toolset = 'v1?0') cannot be found.`
  * Try setting the `GYP_MSVS_VERSION` environment variable to 2013 or 2015 depending on what version of Visual Studio/Build Tools is isntalled and then `script\clean` followed by `script\build` (re-open the Command Prompt if you set the variable using the GUI)

* `'node-gyp' is not recognized as an internal or external command, operable program or batch file.`
  * Try running `npm install -g node-gyp`, and run `script/build` again.

* Other `node-gyp` errors on first build attempt, even though the right Node.js and Python versions are installed.
  * Do try the build command one more time, as experience shows it often works on second try in many of these cases.

### Windows build error reports in atom/atom
* If all fails, use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Awindows&type=Issues) to get a list of reports about build errors on Windows, and see if yours has already been reported.
    * If it hasn't, please open a new issue with your Windows version, architecture (x86 or amd64), and a screenshot of your build output, including the Node.js and Python versions.
