# Windows

## Requirements

* Node.js 4.4.x or later
* Python v2.7.x
  * The python.exe must be available at `%SystemDrive%\Python27\python.exe`. If it is installed elsewhere, you can create a symbolic link to the directory containing the python.exe using: `mklink /d %SystemDrive%\Python27 D:\elsewhere\Python27`
* Visual Studio, either:
  * [Visual C++ Build Tools 2015](http://landinghub.visualstudio.com/visual-cpp-build-tools)
  * [Visual Studio 2013 Update 5](https://www.visualstudio.com/en-us/downloads/download-visual-studio-vs) (Express Edition or better)
  * [Visual Studio 2015](https://www.visualstudio.com/en-us/downloads/download-visual-studio-vs) (Community Edition or better)

  Whichever version you use, ensure that:
  * The default installation folder is chosen so the build tools can find it
  * If using Visual Studio make sure Visual C++ support is selected/installed
  * If using Visual C++ Build Tools make sure Windows 8 SDK is selected/installed
  * A `git` command is in your path
  * Set the `GYP_MSVS_VERSION` environment variable to the Visual Studio/Build Tools version (`2013` or `2015`) e.g. ``[Environment]::SetEnvironmentVariable("GYP_MSVS_VERSION", "2015", "User")`` in PowerShell or set it in Windows advanced system settings control panel.

## Instructions

You can run these commands using Command Prompt, PowerShell or Git Shell via [GitHub Desktop](https://desktop.github.com/). These instructions will assume the use of Command Prompt.

```
cd C:\
git clone https://github.com/atom/atom.git
cd atom
script\build
```

To also install the newly built application, use `script\build --create-windows-installer` and launch the generated installers.

### `script\build` Options
* `--code-sign`: signs the application with the GitHub certificate specified in `$WIN_P12KEY_URL`.
* `--compress-artifacts`: zips the generated application as `out/atom-windows.zip` (requires 7-zip).
* `--create-windows-installer`: creates an `.msi`, an `.exe` and a `.nupkg` installer in the `out/` directory.
* `--install`: installs the application in `%LOCALAPPDATA%\Atom\app-dev\`.

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

* `msbuild.exe failed with exit code: 1`
   * Ensure you have Visual C++ support installed. Go into Add/Remove Programs, select Visual Studio and press Modify and then check the Visual C++ box.

* `script\build` stop with no error or warning shortly after displaying the versions of node, npm and Python
  * Make sure that the path where you have checked out Atom does not include a space. e.g. use `c:\atom` and not `c:\my stuff\atom`

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
  * Try setting the `GYP_MSVS_VERSION` environment variable to 2013 or 2015 depending on what version of Visual Studio you are running and then `script\clean` followed by `script\build` (re-open your command prompt or Powershell window if you set it using the GUI)

* `'node-gyp' is not recognized as an internal or external command, operable program or batch file.`
  * Try running `npm install -g node-gyp`, and run `script\build` again.

* Other `node-gyp` errors on first build attempt, even though the right Node.js and Python versions are installed.
  * Do try the build command one more time, as experience shows it often works on second try in many of these cases.

### Windows build error reports in atom/atom
* If all fails, use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Awindows&type=Issues) to get a list of reports about build errors on Windows, and see if yours has already been reported.
* If it hasn't, please open a new issue with your Windows version, architecture (x86 or amd64), and a screenshot of your build output, including the Node.js and Python versions.
