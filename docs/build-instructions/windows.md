# Windows

## Requirements

* Node.js 6.x (the architecture of node available to the build system will determine whether you build 32-bit or 64-bit Atom)
* Python v2.7.x
  * The python.exe must be available at `%SystemDrive%\Python27\python.exe`. If it is installed elsewhere create a symbolic link to the directory containing the python.exe using: `mklink /d %SystemDrive%\Python27 D:\elsewhere\Python27`
* 7zip (7z.exe available from the command line) - for creating distribution zip files
* Visual Studio, either:
  * [Visual C++ Build Tools 2015](http://landinghub.visualstudio.com/visual-cpp-build-tools)
  * [Visual Studio 2013 Update 5](https://www.visualstudio.com/en-us/downloads/download-visual-studio-vs) (Express Edition or better)
  * [Visual Studio 2015](https://www.visualstudio.com/en-us/downloads/download-visual-studio-vs) (Community Edition or better)

  Also ensure that:
  * The default installation folder is chosen so the build tools can find it
  * If using Visual Studio make sure Visual C++ support is selected/installed
  * If using Visual C++ Build Tools make sure Windows 8 SDK is selected/installed
  * A `git` command is in your path
  * Set the `GYP_MSVS_VERSION` environment variable to the Visual Studio/Build Tools version (`2013` or `2015`) e.g. ``[Environment]::SetEnvironmentVariable("GYP_MSVS_VERSION", "2015", "User")`` in PowerShell (or set it in Windows advanced system settings).

## Instructions

You can run these commands using Command Prompt, PowerShell, Git Shell, or any other terminal. These instructions will assume the use of Command Prompt.

```
cd C:\
git clone https://github.com/atom/atom.git
cd atom
script\build
```

To also install the newly built application, use `script\build --create-windows-installer` and launch the generated installers.

### `script\build` Options
* `--code-sign`: signs the application with the GitHub certificate specified in `$WIN_P12KEY_URL`.
* `--compress-artifacts`: zips the generated application as `out\atom-windows.zip` (requires [7-Zip](http://www.7-zip.org)).
* `--create-windows-installer`: creates an `.msi`, an `.exe` and two `.nupkg` packages in the `out` directory.
* `--install[=dir]`: installs the application in `${dir}\Atom\app-dev`; `${dir}` defaults to `%LOCALAPPDATA%`.

### Running tests

In order to run tests from command line you need `apm`, available after you install Atom or after you build from source. If you installed it, run the following commands (assuming `C:\atom` is the root of your Atom repository):

```bash
cd C:\atom
apm test
```

When building Atom from source, the `apm` command is not added to the system path by default. In this case, you can either add it yourself or explicitly list the complete path in previous commands. The default install location is `%LOCALAPPDATA%\Atom\app-dev\resources\cli\`.

**NOTE**: Please keep in mind that there are still some tests that don't pass on Windows.

## Troubleshooting

### Common Errors
* `node is not recognized`
  * If you just installed Node.js, you'll need to restart Command Prompt before the `node` command is available on your path.

* `msbuild.exe failed with exit code: 1`
   * If using **Visual Studio**, ensure you have the **Visual C++** component installed. Go into Add/Remove Programs, select Visual Studio, press Modify, and then check the Visual C++ box.
   * If using **Visual C++ Build Tools**, ensure you have the **Windows 8 SDK** component installed. Go into Add/Remove Programs, select Visual C++ Build Tools, press Modify and then check the Windows 8 SDK box.

* `script\build` stops with no error or warning shortly after displaying the versions of node, npm and Python
  * Make sure that the path where you have checked out Atom does not include a space. For example, use `C:\atom` instead of `C:\my stuff\atom`.
  * Try moving the repository to `C:\atom`. Most likely, the path is too long. See [issue #2200](https://github.com/atom/atom/issues/2200).

* `error MSB4025: The project file could not be loaded. Invalid character in the given encoding.`
  * This can occur because your home directory (`%USERPROFILE%`) has non-ASCII characters in it. This is a bug in [gyp](https://code.google.com/p/gyp/)
    which is used to build native Node.js modules and there is no known workaround.
    * https://github.com/TooTallNate/node-gyp/issues/297
    * https://code.google.com/p/gyp/issues/detail?id=393

* `'node_modules\.bin\npm' is not recognized as an internal or external command, operable program or batch file.`
   * This occurs if the previous build left things in a bad state. Run `script\clean` and then `script\build` again.

* `script\build` stops at installing runas with `Failed at the runas@x.y.z install script.`
  * See the next item.

* `error MSB8020: The build tools for Visual Studio 201? (Platform Toolset = 'v1?0') cannot be found.`
  * Try setting the `GYP_MSVS_VERSION` environment variable to **2013** or **2015** depending on what version of Visual Studio/Build Tools is installed and then `script\clean` followed by `script\build` (re-open the Command Prompt if you set the variable using the GUI).

* `'node-gyp' is not recognized as an internal or external command, operable program or batch file.`
  * Try running `npm install -g node-gyp`, and run `script\build` again.

* Other `node-gyp` errors on first build attempt, even though the right Node.js and Python versions are installed.
  * Do try the build command one more time as experience shows it often works on second try in many cases.

### Windows build error reports in atom/atom
* If all fails, use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Awindows&type=Issues) to get a list of reports about build errors on Windows, and see if yours has already been reported.
* If it hasn't, please open a new issue with your Windows version, architecture (x86 or x64), and a screenshot of your build output, including the Node.js and Python versions.
