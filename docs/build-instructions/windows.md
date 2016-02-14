# Windows

## Requirements

### General
 * [Node.js](http://nodejs.org/en/download/) v4.x
 * [Python](https://www.python.org/downloads/) v2.7.x
    * The python.exe must be available at `%SystemDrive%\Python27\python.exe`.
      If it is installed elsewhere, you can create a symbolic link to the
      directory containing the python.exe using:
      `mklink /d %SystemDrive%\Python27 D:\elsewhere\Python27`

### Visual Studio

You can use either:

 * [Visual Studio 2013 Update 5](http://www.visualstudio.com/en-us/downloads/download-visual-studio-vs) (Express or better) on Windows 7, 8 or 10
 * [Visual Studio 2015](http://www.visualstudio.com/en-us/downloads/download-visual-studio-vs) (Community or better) with Windows 8 or 10

Whichever version you use, ensure that:

 * The default installation folder is chosen so the build tools can find it
 * Visual C++ support is installed
 * You set the `GYP_MSVS_VERSION` environment variable to the Visual Studio version (`2013` or `2015`), e.g. , e.g. ``[Environment]::SetEnvironmentVariable("GYP_MSVS_VERSION", "2015", "User")`` in PowerShell or set it in Windows advanced system settings control panel.
 * The git command is in your path

## Instructions

You can run these commands using Command Prompt, PowerShell or Git Shell via [GitHub Desktop](https://desktop.github.com/). These instructions will assume the use of Bash from Git Shell - if you are using Command Prompt use a backslash instead: i.e. `script\build`.

**VS2015 + Git Shell users** should note that the default path supplied with Git Shell includes reference to an older version of msbuild that will fail. It is recommended you use a PowerShell window that has git in the path at this time.

```bash
cd C:\
git clone https://github.com/atom/atom/
cd atom
script/build
```
This will create the Atom application in the `Program Files` folder.

### `script/build` Options
  * `--install-dir` - Creates the final built application in this directory. Example (trailing slash is optional):
```bash
./script/build --install-dir Z:\Some\Destination\Directory\
```
  * `--build-dir` - Build the application in this directory. Example (trailing slash is optional):
```bash
./script/build --build-dir Z:\Some\Temporary\Directory\
```
  * `--verbose` - Verbose mode. A lot more information output.

## Do I have to use GitHub Desktop?

No, you can use your existing Git! GitHub Desktop's Git Shell is just easier to set up.

If you _prefer_ using your existing Git installation, make sure git's cmd directory is in your PATH env variable (e.g. `C:\Program Files (x86)\Git\cmd`) before you open your PowerShell or Command Prompt.

It is also recommended you open your Command Prompt or PowerShell as Administrator.

If none of this works, do install Github Desktop and use its Git Shell as it makes life easier.

## Troubleshooting

### Common Errors
* `node is not recognized`

  * If you just installed Node.js, you'll need to restart your PowerShell/Command Prompt/Git Shell before the node
  command is available on your Path.

* `script/build` outputs only the Node.js and Python versions before returning

  * Try moving the repository to `C:\atom`. Most likely, the path is too long.
    See [issue #2200](https://github.com/atom/atom/issues/2200).

* `error MSB4025: The project file could not be loaded. Invalid character in the given encoding.`

  * This can occur because your home directory (`%USERPROFILE%`) has non-ASCII
    characters in it. This is a bug in [gyp](https://code.google.com/p/gyp/)
    which is used to build native Node.js modules and there is no known workaround.
    * https://github.com/TooTallNate/node-gyp/issues/297
    * https://code.google.com/p/gyp/issues/detail?id=393

* `script/build` stops at installing runas with `Failed at the runas@x.y.z install script.`

  * See the next item.

* `error MSB8020: The build tools for Visual Studio 201? (Platform Toolset = 'v1?0') cannot be found.`

  * If you're building Atom with Visual Studio 2013 or above make sure the `GYP_MSVS_VERSION` environment variable is set, and then re-run `script/build` after a clean:

    ```bash
    $env:GYP_MSVS_VERSION='2013' # '2015' if using Visual Studio 2015, and so on
    script/clean
    script/build
    ```
  * If you are using Visual Studio 2013 or above and the build fails with some other error message this environment variable might still be required and ensure you have Visual C++ language support installed.

* Other `node-gyp` errors on first build attempt, even though the right Node.js and Python versions are installed.
  * Do try the build command one more time, as experience shows it often works on second try in many of these cases.

### Windows build error reports in atom/atom
* If all fails, use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Awindows&type=Issues) to get a list of reports about build errors on Windows, and see if yours has already been reported.
    * If it hasn't, please open a new issue with your Windows version, architecture (x86 or amd64), and a screenshot of your build output, including the Node.js and Python versions.
