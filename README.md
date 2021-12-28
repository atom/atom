# Atom

[![Build status](https://dev.azure.com/github/Atom/_apis/build/status/Atom%20Production%20Branches?branchName=master)](https://dev.azure.com/github/Atom/_build/latest?definitionId=32&branchName=master)

Atom is a hackable text editor for the 21st century, built on [Electron](https://github.com/electron/electron), and based on everything we love about our favorite editors. We designed it to be deeply customizable, but still approachable using the default configuration.

![Atom](https://user-images.githubusercontent.com/378023/49132477-f4b77680-f31f-11e8-8357-ac6491761c6c.png)

![Atom Screenshot](https://user-images.githubusercontent.com/378023/49132478-f4b77680-f31f-11e8-9e10-e8454d8d9b7e.png)

Visit [atom.io](https://atom.io) to learn more or visit the [Atom forum](https://github.com/atom/atom/discussions).

Follow [@AtomEditor](https://twitter.com/atomeditor) on Twitter for important
announcements.

This project adheres to the Contributor Covenant [code of conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report unacceptable behavior to atom@github.com.

## Documentation

If you want to read about using Atom or developing packages in Atom, the [Atom Flight Manual](https://flight-manual.atom.io) is free and available online. You can find the source to the manual in [atom/flight-manual.atom.io](https://github.com/atom/flight-manual.atom.io).

The [API reference](https://atom.io/docs/api) for developing packages is also documented on Atom.io.

## Installing

### Prerequisites
- [Git](https://git-scm.com)

### macOS

Download the latest [Atom release](https://github.com/atom/atom/releases/latest).

Atom will automatically update when a new release is available.

### Windows

Download the latest [Atom installer](https://github.com/atom/atom/releases/latest). `AtomSetup.exe` is 32-bit. For 64-bit systems, download `AtomSetup-x64.exe`.

Atom will automatically update when a new release is available.

You can also download `atom-windows.zip` (32-bit) or `atom-x64-windows.zip` (64-bit) from the [releases page](https://github.com/atom/atom/releases/latest).
The `.zip` version will not automatically update.

Using [Chocolatey](https://chocolatey.org)? Run `cinst Atom` to install the latest version of Atom.

### Linux

Atom is only available for 64-bit Linux systems.

Configure your distribution's package manager to install and update Atom by following the [Linux installation instructions](https://flight-manual.atom.io/getting-started/sections/installing-atom/#platform-linux) in the Flight Manual.  You will also find instructions on how to install Atom's official Linux packages without using a package repository, though you will not get automatic updates after installing Atom this way.

#### Archive extraction

An archive is available for people who don't want to install `atom` as root.

This version enables you to install multiple Atom versions in parallel. It has been built on Ubuntu 64-bit,
but should be compatible with other Linux distributions.

1. Install dependencies (on Ubuntu):
```sh
sudo apt install git libasound2 libcurl4 libgbm1 libgcrypt20 libgtk-3-0 libnotify4 libnss3 libglib2.0-bin xdg-utils libx11-xcb1 libxcb-dri3-0 libxss1 libxtst6 libxkbfile1
```
2. Download `atom-amd64.tar.gz` from the [Atom releases page](https://github.com/atom/atom/releases/latest).
3. Run `tar xf atom-amd64.tar.gz` in the directory where you want to extract the Atom folder.
4. Launch Atom using the installed `atom` command from the newly extracted directory.

The Linux version does not currently automatically update so you will need to
repeat these steps to upgrade to future releases.

## Building

* [Linux](https://flight-manual.atom.io/hacking-atom/sections/hacking-on-atom-core/#platform-linux)
* [macOS](https://flight-manual.atom.io/hacking-atom/sections/hacking-on-atom-core/#platform-mac)
* [Windows](https://flight-manual.atom.io/hacking-atom/sections/hacking-on-atom-core/#platform-windows)

## Discussion

* Discuss Atom on [GitHub Discussions](https://github.com/atom/atom/discussions)

## License

[MIT](https://github.com/atom/atom/blob/master/LICENSE.md)

When using the Atom or other GitHub logos, be sure to follow the [GitHub logo guidelines](https://github.com/logos).
compiler.cpp:1:1: warning: missing terminating ' character
    1 | '
      | ^
compiler.cpp:1:1: error: missing terminating ' character
compiler.cpp:2:1: error: stray '\357' in program
    2 | ￼￼￼￼￼
      | ^
compiler.cpp:2:2: error: stray '\277' in program
    2 | ￼￼￼￼￼
      |  ^
compiler.cpp:2:3: error: stray '\274' in program
    2 | ￼￼￼￼￼
      |   ^
compiler.cpp:2:4: error: stray '\357' in program
    2 | ￼￼￼￼￼
      |    ^
compiler.cpp:2:5: error: stray '\277' in program
    2 | ￼￼￼￼￼
      |     ^
compiler.cpp:2:6: error: stray '\274' in program
    2 | ￼￼￼￼￼
      |      ^
compiler.cpp:2:7: error: stray '\357' in program
    2 | ￼￼￼￼￼
      |       ^
compiler.cpp:2:8: error: stray '\277' in program
    2 | ￼￼￼￼￼
      |        ^
compiler.cpp:2:9: error: stray '\274' in program
    2 | ￼￼￼￼￼
      |         ^
compiler.cpp:2:10: error: stray '\357' in program
    2 | ￼￼￼￼￼
      |          ^
compiler.cpp:2:11: error: stray '\277' in program
    2 | ￼￼￼￼￼
      |           ^
compiler.cpp:2:12: error: stray '\274' in program
    2 | ￼￼￼￼￼
      |            ^
compiler.cpp:2:13: error: stray '\357' in program
    2 | ￼￼￼￼￼
      |             ^
compiler.cpp:2:14: error: stray '\277' in program
    2 | ￼￼￼￼￼
      |              ^
compiler.cpp:2:15: error: stray '\274' in program
    2 | ￼￼￼￼￼
      |               ^
compiler.cpp:4:49: warning: multi-character character constant [-Wmultichar]
    4 | source_file.java:322: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:5:1: error: stray '\357' in program
    5 | ￼￼￼￼￼
      | ^
compiler.cpp:5:2: error: stray '\277' in program
    5 | ￼￼￼￼￼
      |  ^
compiler.cpp:5:3: error: stray '\274' in program
    5 | ￼￼￼￼￼
      |   ^
compiler.cpp:5:4: error: stray '\357' in program
    5 | ￼￼￼￼￼
      |    ^
compiler.cpp:5:5: error: stray '\277' in program
    5 | ￼￼￼￼￼
      |     ^
compiler.cpp:5:6: error: stray '\274' in program
    5 | ￼￼￼￼￼
      |      ^
compiler.cpp:5:7: error: stray '\357' in program
    5 | ￼￼￼￼￼
      |       ^
compiler.cpp:5:8: error: stray '\277' in program
    5 | ￼￼￼￼￼
      |        ^
compiler.cpp:5:9: error: stray '\274' in program
    5 | ￼￼￼￼￼
      |         ^
compiler.cpp:5:10: error: stray '\357' in program
    5 | ￼￼￼￼￼
      |          ^
compiler.cpp:5:11: error: stray '\277' in program
    5 | ￼￼￼￼￼
      |           ^
compiler.cpp:5:12: error: stray '\274' in program
    5 | ￼￼￼￼￼
      |            ^
compiler.cpp:5:13: error: stray '\357' in program
    5 | ￼￼￼￼￼
      |             ^
compiler.cpp:5:14: error: stray '\277' in program
    5 | ￼￼￼￼￼
      |              ^
compiler.cpp:5:15: error: stray '\274' in program
    5 | ￼￼￼￼￼
      |               ^
compiler.cpp:7:49: warning: multi-character character constant [-Wmultichar]
    7 | source_file.java:322: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:8:1: error: stray '\357' in program
    8 | ￼￼￼￼￼
      | ^
compiler.cpp:8:2: error: stray '\277' in program
    8 | ￼￼￼￼￼
      |  ^
compiler.cpp:8:3: error: stray '\274' in program
    8 | ￼￼￼￼￼
      |   ^
compiler.cpp:8:4: error: stray '\357' in program
    8 | ￼￼￼￼￼
      |    ^
compiler.cpp:8:5: error: stray '\277' in program
    8 | ￼￼￼￼￼
      |     ^
compiler.cpp:8:6: error: stray '\274' in program
    8 | ￼￼￼￼￼
      |      ^
compiler.cpp:8:7: error: stray '\357' in program
    8 | ￼￼￼￼￼
      |       ^
compiler.cpp:8:8: error: stray '\277' in program
    8 | ￼￼￼￼￼
      |        ^
compiler.cpp:8:9: error: stray '\274' in program
    8 | ￼￼￼￼￼
      |         ^
compiler.cpp:8:10: error: stray '\357' in program
    8 | ￼￼￼￼￼
      |          ^
compiler.cpp:8:11: error: stray '\277' in program
    8 | ￼￼￼￼￼
      |           ^
compiler.cpp:8:12: error: stray '\274' in program
    8 | ￼￼￼￼￼
      |            ^
compiler.cpp:8:13: error: stray '\357' in program
    8 | ￼￼￼￼￼
      |             ^
compiler.cpp:8:14: error: stray '\277' in program
    8 | ￼￼￼￼￼
      |              ^
compiler.cpp:8:15: error: stray '\274' in program
    8 | ￼￼￼￼￼
      |               ^
compiler.cpp:10:49: warning: multi-character character constant [-Wmultichar]
   10 | source_file.java:322: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:11:1: error: stray '\357' in program
   11 | ￼￼￼￼￼
      | ^
compiler.cpp:11:2: error: stray '\277' in program
   11 | ￼￼￼￼￼
      |  ^
compiler.cpp:11:3: error: stray '\274' in program
   11 | ￼￼￼￼￼
      |   ^
compiler.cpp:11:4: error: stray '\357' in program
   11 | ￼￼￼￼￼
      |    ^
compiler.cpp:11:5: error: stray '\277' in program
   11 | ￼￼￼￼￼
      |     ^
compiler.cpp:11:6: error: stray '\274' in program
   11 | ￼￼￼￼￼
      |      ^
compiler.cpp:11:7: error: stray '\357' in program
   11 | ￼￼￼￼￼
      |       ^
compiler.cpp:11:8: error: stray '\277' in program
   11 | ￼￼￼￼￼
      |        ^
compiler.cpp:11:9: error: stray '\274' in program
   11 | ￼￼￼￼￼
      |         ^
compiler.cpp:11:10: error: stray '\357' in program
   11 | ￼￼￼￼￼
      |          ^
compiler.cpp:11:11: error: stray '\277' in program
   11 | ￼￼￼￼￼
      |           ^
compiler.cpp:11:12: error: stray '\274' in program
   11 | ￼￼￼￼￼
      |            ^
compiler.cpp:11:13: error: stray '\357' in program
   11 | ￼￼￼￼￼
      |             ^
compiler.cpp:11:14: error: stray '\277' in program
   11 | ￼￼￼￼￼
      |              ^
compiler.cpp:11:15: error: stray '\274' in program
   11 | ￼￼￼￼￼
      |               ^
compiler.cpp:13:49: warning: multi-character character constant [-Wmultichar]
   13 | source_file.java:322: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:14:1: error: stray '\357' in program
   14 | ￼￼￼￼￼
      | ^
compiler.cpp:14:2: error: stray '\277' in program
   14 | ￼￼￼￼￼
      |  ^
compiler.cpp:14:3: error: stray '\274' in program
   14 | ￼￼￼￼￼
      |   ^
compiler.cpp:14:4: error: stray '\357' in program
   14 | ￼￼￼￼￼
      |    ^
compiler.cpp:14:5: error: stray '\277' in program
   14 | ￼￼￼￼￼
      |     ^
compiler.cpp:14:6: error: stray '\274' in program
   14 | ￼￼￼￼￼
      |      ^
compiler.cpp:14:7: error: stray '\357' in program
   14 | ￼￼￼￼￼
      |       ^
compiler.cpp:14:8: error: stray '\277' in program
   14 | ￼￼￼￼￼
      |        ^
compiler.cpp:14:9: error: stray '\274' in program
   14 | ￼￼￼￼￼
      |         ^
compiler.cpp:14:10: error: stray '\357' in program
   14 | ￼￼￼￼￼
      |          ^
compiler.cpp:14:11: error: stray '\277' in program
   14 | ￼￼￼￼￼
      |           ^
compiler.cpp:14:12: error: stray '\274' in program
   14 | ￼￼￼￼￼
      |            ^
compiler.cpp:14:13: error: stray '\357' in program
   14 | ￼￼￼￼￼
      |             ^
compiler.cpp:14:14: error: stray '\277' in program
   14 | ￼￼￼￼￼
      |              ^
compiler.cpp:14:15: error: stray '\274' in program
   14 | ￼￼￼￼￼
      |               ^
compiler.cpp:17:5: warning: missing terminating ' character
   17 | What's New in Development for iOS 13
      |     ^
compiler.cpp:17:5: error: missing terminating ' character
   17 | What's New in Development for iOS 13
      |     ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
compiler.cpp:23:18: warning: missing terminating ' character
   23 | Absolute Beginner's Guide to Logic Pro
      |                  ^
compiler.cpp:23:18: error: missing terminating ' character
   23 | Absolute Beginner's Guide to Logic Pro
      |                  ^~~~~~~~~~~~~~~~~~~~~
compiler.cpp:25:49: warning: multi-character character constant [-Wmultichar]
   25 | source_file.java:339: error: illegal character: '\u201c'
      |                                                 ^~~~~~~~
compiler.cpp:26:6: error: stray '\342' in program
   26 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |      ^
compiler.cpp:26:7: error: stray '\200' in program
   26 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |       ^
compiler.cpp:26:8: error: stray '\234' in program
   26 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |        ^
compiler.cpp:26:46: error: stray '\342' in program
   26 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |                                              ^
compiler.cpp:26:47: error: stray '\200' in program
   26 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |                                               ^
compiler.cpp:26:48: error: stray '\235' in program
   26 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |                                                ^
compiler.cpp:28:49: warning: multi-character character constant [-Wmultichar]
   28 | source_file.java:339: error: illegal character: '\u201d'
      |                                                 ^~~~~~~~
compiler.cpp:29:6: error: stray '\342' in program
   29 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |      ^
compiler.cpp:29:7: error: stray '\200' in program
   29 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |       ^
compiler.cpp:29:8: error: stray '\234' in program
   29 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |        ^
compiler.cpp:29:46: error: stray '\342' in program
   29 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |                                              ^
compiler.cpp:29:47: error: stray '\200' in program
   29 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |                                               ^
compiler.cpp:29:48: error: stray '\235' in program
   29 | This “Absolute Beginners Guide to Logic Pro” course is designed to provide students with basic foundational knowledge of . . .
      |                                                ^
compiler.cpp:31:49: warning: multi-character character constant [-Wmultichar]
   31 | source_file.java:348: error: illegal character: '\u201c'
      |                                                 ^~~~~~~~
compiler.cpp:32:6: error: stray '\342' in program
   32 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |      ^
compiler.cpp:32:7: error: stray '\200' in program
   32 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |       ^
compiler.cpp:32:8: error: stray '\234' in program
   32 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |        ^
compiler.cpp:32:22: error: stray '\342' in program
   32 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |                      ^
compiler.cpp:32:23: error: stray '\200' in program
   32 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |                       ^
compiler.cpp:32:24: error: stray '\235' in program
   32 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |                        ^
compiler.cpp:34:49: warning: multi-character character constant [-Wmultichar]
   34 | source_file.java:348: error: illegal character: '\u201d'
      |                                                 ^~~~~~~~
compiler.cpp:35:6: error: stray '\342' in program
   35 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |      ^
compiler.cpp:35:7: error: stray '\200' in program
   35 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |       ^
compiler.cpp:35:8: error: stray '\234' in program
   35 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |        ^
compiler.cpp:35:22: error: stray '\342' in program
   35 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |                      ^
compiler.cpp:35:23: error: stray '\200' in program
   35 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |                       ^
compiler.cpp:35:24: error: stray '\235' in program
   35 | This “Logic Pro 101” course is designed to provide students with the knowledge and skills to navigate Logic Pro like a studio . . .
      |                        ^
compiler.cpp:37:49: warning: multi-character character constant [-Wmultichar]
   37 | source_file.java:351: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:38:1: error: stray '\357' in program
   38 | ￼￼￼￼￼
      | ^
compiler.cpp:38:2: error: stray '\277' in program
   38 | ￼￼￼￼￼
      |  ^
compiler.cpp:38:3: error: stray '\274' in program
   38 | ￼￼￼￼￼
      |   ^
compiler.cpp:38:4: error: stray '\357' in program
   38 | ￼￼￼￼￼
      |    ^
compiler.cpp:38:5: error: stray '\277' in program
   38 | ￼￼￼￼￼
      |     ^
compiler.cpp:38:6: error: stray '\274' in program
   38 | ￼￼￼￼￼
      |      ^
compiler.cpp:38:7: error: stray '\357' in program
   38 | ￼￼￼￼￼
      |       ^
compiler.cpp:38:8: error: stray '\277' in program
   38 | ￼￼￼￼￼
      |        ^
compiler.cpp:38:9: error: stray '\274' in program
   38 | ￼￼￼￼￼
      |         ^
compiler.cpp:38:10: error: stray '\357' in program
   38 | ￼￼￼￼￼
      |          ^
compiler.cpp:38:11: error: stray '\277' in program
   38 | ￼￼￼￼￼
      |           ^
compiler.cpp:38:12: error: stray '\274' in program
   38 | ￼￼￼￼￼
      |            ^
compiler.cpp:38:13: error: stray '\357' in program
   38 | ￼￼￼￼￼
      |             ^
compiler.cpp:38:14: error: stray '\277' in program
   38 | ￼￼￼￼￼
      |              ^
compiler.cpp:38:15: error: stray '\274' in program
   38 | ￼￼￼￼￼
      |               ^
compiler.cpp:40:49: warning: multi-character character constant [-Wmultichar]
   40 | source_file.java:351: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:41:1: error: stray '\357' in program
   41 | ￼￼￼￼￼
      | ^
compiler.cpp:41:2: error: stray '\277' in program
   41 | ￼￼￼￼￼
      |  ^
compiler.cpp:41:3: error: stray '\274' in program
   41 | ￼￼￼￼￼
      |   ^
compiler.cpp:41:4: error: stray '\357' in program
   41 | ￼￼￼￼￼
      |    ^
compiler.cpp:41:5: error: stray '\277' in program
   41 | ￼￼￼￼￼
      |     ^
compiler.cpp:41:6: error: stray '\274' in program
   41 | ￼￼￼￼￼
      |      ^
compiler.cpp:41:7: error: stray '\357' in program
   41 | ￼￼￼￼￼
      |       ^
compiler.cpp:41:8: error: stray '\277' in program
   41 | ￼￼￼￼￼
      |        ^
compiler.cpp:41:9: error: stray '\274' in program
   41 | ￼￼￼￼￼
      |         ^
compiler.cpp:41:10: error: stray '\357' in program
   41 | ￼￼￼￼￼
      |          ^
compiler.cpp:41:11: error: stray '\277' in program
   41 | ￼￼￼￼￼
      |           ^
compiler.cpp:41:12: error: stray '\274' in program
   41 | ￼￼￼￼￼
      |            ^
compiler.cpp:41:13: error: stray '\357' in program
   41 | ￼￼￼￼￼
      |             ^
compiler.cpp:41:14: error: stray '\277' in program
   41 | ￼￼￼￼￼
      |              ^
compiler.cpp:41:15: error: stray '\274' in program
   41 | ￼￼￼￼￼
      |               ^
compiler.cpp:43:49: warning: multi-character character constant [-Wmultichar]
   43 | source_file.java:351: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:44:1: error: stray '\357' in program
   44 | ￼￼￼￼￼
      | ^
compiler.cpp:44:2: error: stray '\277' in program
   44 | ￼￼￼￼￼
      |  ^
compiler.cpp:44:3: error: stray '\274' in program
   44 | ￼￼￼￼￼
      |   ^
compiler.cpp:44:4: error: stray '\357' in program
   44 | ￼￼￼￼￼
      |    ^
compiler.cpp:44:5: error: stray '\277' in program
   44 | ￼￼￼￼￼
      |     ^
compiler.cpp:44:6: error: stray '\274' in program
   44 | ￼￼￼￼￼
      |      ^
compiler.cpp:44:7: error: stray '\357' in program
   44 | ￼￼￼￼￼
      |       ^
compiler.cpp:44:8: error: stray '\277' in program
   44 | ￼￼￼￼￼
      |        ^
compiler.cpp:44:9: error: stray '\274' in program
   44 | ￼￼￼￼￼
      |         ^
compiler.cpp:44:10: error: stray '\357' in program
   44 | ￼￼￼￼￼
      |          ^
compiler.cpp:44:11: error: stray '\277' in program
   44 | ￼￼￼￼￼
      |           ^
compiler.cpp:44:12: error: stray '\274' in program
   44 | ￼￼￼￼￼
      |            ^
compiler.cpp:44:13: error: stray '\357' in program
   44 | ￼￼￼￼￼
      |             ^
compiler.cpp:44:14: error: stray '\277' in program
   44 | ￼￼￼￼￼
      |              ^
compiler.cpp:44:15: error: stray '\274' in program
   44 | ￼￼￼￼￼
      |               ^
compiler.cpp:46:49: warning: multi-character character constant [-Wmultichar]
   46 | source_file.java:351: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:47:1: error: stray '\357' in program
   47 | ￼￼￼￼￼
      | ^
compiler.cpp:47:2: error: stray '\277' in program
   47 | ￼￼￼￼￼
      |  ^
compiler.cpp:47:3: error: stray '\274' in program
   47 | ￼￼￼￼￼
      |   ^
compiler.cpp:47:4: error: stray '\357' in program
   47 | ￼￼￼￼￼
      |    ^
compiler.cpp:47:5: error: stray '\277' in program
   47 | ￼￼￼￼￼
      |     ^
compiler.cpp:47:6: error: stray '\274' in program
   47 | ￼￼￼￼￼
      |      ^
compiler.cpp:47:7: error: stray '\357' in program
   47 | ￼￼￼￼￼
      |       ^
compiler.cpp:47:8: error: stray '\277' in program
   47 | ￼￼￼￼￼
      |        ^
compiler.cpp:47:9: error: stray '\274' in program
   47 | ￼￼￼￼￼
      |         ^
compiler.cpp:47:10: error: stray '\357' in program
   47 | ￼￼￼￼￼
      |          ^
compiler.cpp:47:11: error: stray '\277' in program
   47 | ￼￼￼￼￼
      |           ^
compiler.cpp:47:12: error: stray '\274' in program
   47 | ￼￼￼￼￼
      |            ^
compiler.cpp:47:13: error: stray '\357' in program
   47 | ￼￼￼￼￼
      |             ^
compiler.cpp:47:14: error: stray '\277' in program
   47 | ￼￼￼￼￼
      |              ^
compiler.cpp:47:15: error: stray '\274' in program
   47 | ￼￼￼￼￼
      |               ^
compiler.cpp:49:49: warning: multi-character character constant [-Wmultichar]
   49 | source_file.java:351: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:50:1: error: stray '\357' in program
   50 | ￼￼￼￼￼
      | ^
compiler.cpp:50:2: error: stray '\277' in program
   50 | ￼￼￼￼￼
      |  ^
compiler.cpp:50:3: error: stray '\274' in program
   50 | ￼￼￼￼￼
      |   ^
compiler.cpp:50:4: error: stray '\357' in program
   50 | ￼￼￼￼￼
      |    ^
compiler.cpp:50:5: error: stray '\277' in program
   50 | ￼￼￼￼￼
      |     ^
compiler.cpp:50:6: error: stray '\274' in program
   50 | ￼￼￼￼￼
      |      ^
compiler.cpp:50:7: error: stray '\357' in program
   50 | ￼￼￼￼￼
      |       ^
compiler.cpp:50:8: error: stray '\277' in program
   50 | ￼￼￼￼￼
      |        ^
compiler.cpp:50:9: error: stray '\274' in program
   50 | ￼￼￼￼￼
      |         ^
compiler.cpp:50:10: error: stray '\357' in program
   50 | ￼￼￼￼￼
      |          ^
compiler.cpp:50:11: error: stray '\277' in program
   50 | ￼￼￼￼￼
      |           ^
compiler.cpp:50:12: error: stray '\274' in program
   50 | ￼￼￼￼￼
      |            ^
compiler.cpp:50:13: error: stray '\357' in program
   50 | ￼￼￼￼￼
      |             ^
compiler.cpp:50:14: error: stray '\277' in program
   50 | ￼￼￼￼￼
      |              ^
compiler.cpp:50:15: error: stray '\274' in program
   50 | ￼￼￼￼￼
      |               ^
compiler.cpp:52:49: warning: multi-character character constant [-Wmultichar]
   52 | source_file.java:388: error: illegal character: '\u2019'
      |                                                 ^~~~~~~~
compiler.cpp:53:118: error: stray '\342' in program
   53 | iOS 14 and iPadOS 14 come with many new features and improvements: from new Home Screen and widgets to upgraded Apple’s apps, . . .
      |                                                                                                                      ^
compiler.cpp:53:119: error: stray '\200' in program
   53 | iOS 14 and iPadOS 14 come with many new features and improvements: from new Home Screen and widgets to upgraded Apple’s apps, . . .
      |                                                                                                                       ^
compiler.cpp:53:120: error: stray '\231' in program
   53 | iOS 14 and iPadOS 14 come with many new features and improvements: from new Home Screen and widgets to upgraded Apple’s apps, . . .
      |                                                                                                                        ^
compiler.cpp:55:49: warning: multi-character character constant [-Wmultichar]
   55 | source_file.java:400: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:56:1: error: stray '\357' in program
   56 | ￼￼￼￼￼
      | ^
compiler.cpp:56:2: error: stray '\277' in program
   56 | ￼￼￼￼￼
      |  ^
compiler.cpp:56:3: error: stray '\274' in program
   56 | ￼￼￼￼￼
      |   ^
compiler.cpp:56:4: error: stray '\357' in program
   56 | ￼￼￼￼￼
      |    ^
compiler.cpp:56:5: error: stray '\277' in program
   56 | ￼￼￼￼￼
      |     ^
compiler.cpp:56:6: error: stray '\274' in program
   56 | ￼￼￼￼￼
      |      ^
compiler.cpp:56:7: error: stray '\357' in program
   56 | ￼￼￼￼￼
      |       ^
compiler.cpp:56:8: error: stray '\277' in program
   56 | ￼￼￼￼￼
      |        ^
compiler.cpp:56:9: error: stray '\274' in program
   56 | ￼￼￼￼￼
      |         ^
compiler.cpp:56:10: error: stray '\357' in program
   56 | ￼￼￼￼￼
      |          ^
compiler.cpp:56:11: error: stray '\277' in program
   56 | ￼￼￼￼￼
      |           ^
compiler.cpp:56:12: error: stray '\274' in program
   56 | ￼￼￼￼￼
      |            ^
compiler.cpp:56:13: error: stray '\357' in program
   56 | ￼￼￼￼￼
      |             ^
compiler.cpp:56:14: error: stray '\277' in program
   56 | ￼￼￼￼￼
      |              ^
compiler.cpp:56:15: error: stray '\274' in program
   56 | ￼￼￼￼￼
      |               ^
compiler.cpp:58:49: warning: multi-character character constant [-Wmultichar]
   58 | source_file.java:400: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:59:1: error: stray '\357' in program
   59 | ￼￼￼￼￼
      | ^
compiler.cpp:59:2: error: stray '\277' in program
   59 | ￼￼￼￼￼
      |  ^
compiler.cpp:59:3: error: stray '\274' in program
   59 | ￼￼￼￼￼
      |   ^
compiler.cpp:59:4: error: stray '\357' in program
   59 | ￼￼￼￼￼
      |    ^
compiler.cpp:59:5: error: stray '\277' in program
   59 | ￼￼￼￼￼
      |     ^
compiler.cpp:59:6: error: stray '\274' in program
   59 | ￼￼￼￼￼
      |      ^
compiler.cpp:59:7: error: stray '\357' in program
   59 | ￼￼￼￼￼
      |       ^
compiler.cpp:59:8: error: stray '\277' in program
   59 | ￼￼￼￼￼
      |        ^
compiler.cpp:59:9: error: stray '\274' in program
   59 | ￼￼￼￼￼
      |         ^
compiler.cpp:59:10: error: stray '\357' in program
   59 | ￼￼￼￼￼
      |          ^
compiler.cpp:59:11: error: stray '\277' in program
   59 | ￼￼￼￼￼
      |           ^
compiler.cpp:59:12: error: stray '\274' in program
   59 | ￼￼￼￼￼
      |            ^
compiler.cpp:59:13: error: stray '\357' in program
   59 | ￼￼￼￼￼
      |             ^
compiler.cpp:59:14: error: stray '\277' in program
   59 | ￼￼￼￼￼
      |              ^
compiler.cpp:59:15: error: stray '\274' in program
   59 | ￼￼￼￼￼
      |               ^
compiler.cpp:61:49: warning: multi-character character constant [-Wmultichar]
   61 | source_file.java:400: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:62:1: error: stray '\357' in program
   62 | ￼￼￼￼￼
      | ^
compiler.cpp:62:2: error: stray '\277' in program
   62 | ￼￼￼￼￼
      |  ^
compiler.cpp:62:3: error: stray '\274' in program
   62 | ￼￼￼￼￼
      |   ^
compiler.cpp:62:4: error: stray '\357' in program
   62 | ￼￼￼￼￼
      |    ^
compiler.cpp:62:5: error: stray '\277' in program
   62 | ￼￼￼￼￼
      |     ^
compiler.cpp:62:6: error: stray '\274' in program
   62 | ￼￼￼￼￼
      |      ^
compiler.cpp:62:7: error: stray '\357' in program
   62 | ￼￼￼￼￼
      |       ^
compiler.cpp:62:8: error: stray '\277' in program
   62 | ￼￼￼￼￼
      |        ^
compiler.cpp:62:9: error: stray '\274' in program
   62 | ￼￼￼￼￼
      |         ^
compiler.cpp:62:10: error: stray '\357' in program
   62 | ￼￼￼￼￼
      |          ^
compiler.cpp:62:11: error: stray '\277' in program
   62 | ￼￼￼￼￼
      |           ^
compiler.cpp:62:12: error: stray '\274' in program
   62 | ￼￼￼￼￼
      |            ^
compiler.cpp:62:13: error: stray '\357' in program
   62 | ￼￼￼￼￼
      |             ^
compiler.cpp:62:14: error: stray '\277' in program
   62 | ￼￼￼￼￼
      |              ^
compiler.cpp:62:15: error: stray '\274' in program
   62 | ￼￼￼￼￼
      |               ^
compiler.cpp:64:49: warning: multi-character character constant [-Wmultichar]
   64 | source_file.java:400: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:65:1: error: stray '\357' in program
   65 | ￼￼￼￼￼
      | ^
compiler.cpp:65:2: error: stray '\277' in program
   65 | ￼￼￼￼￼
      |  ^
compiler.cpp:65:3: error: stray '\274' in program
   65 | ￼￼￼￼￼
      |   ^
compiler.cpp:65:4: error: stray '\357' in program
   65 | ￼￼￼￼￼
      |    ^
compiler.cpp:65:5: error: stray '\277' in program
   65 | ￼￼￼￼￼
      |     ^
compiler.cpp:65:6: error: stray '\274' in program
   65 | ￼￼￼￼￼
      |      ^
compiler.cpp:65:7: error: stray '\357' in program
   65 | ￼￼￼￼￼
      |       ^
compiler.cpp:65:8: error: stray '\277' in program
   65 | ￼￼￼￼￼
      |        ^
compiler.cpp:65:9: error: stray '\274' in program
   65 | ￼￼￼￼￼
      |         ^
compiler.cpp:65:10: error: stray '\357' in program
   65 | ￼￼￼￼￼
      |          ^
compiler.cpp:65:11: error: stray '\277' in program
   65 | ￼￼￼￼￼
      |           ^
compiler.cpp:65:12: error: stray '\274' in program
   65 | ￼￼￼￼￼
      |            ^
compiler.cpp:65:13: error: stray '\357' in program
   65 | ￼￼￼￼￼
      |             ^
compiler.cpp:65:14: error: stray '\277' in program
   65 | ￼￼￼￼￼
      |              ^
compiler.cpp:65:15: error: stray '\274' in program
   65 | ￼￼￼￼￼
      |               ^
compiler.cpp:67:49: warning: multi-character character constant [-Wmultichar]
   67 | source_file.java:400: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:68:1: error: stray '\357' in program
   68 | ￼￼￼￼￼
      | ^
compiler.cpp:68:2: error: stray '\277' in program
   68 | ￼￼￼￼￼
      |  ^
compiler.cpp:68:3: error: stray '\274' in program
   68 | ￼￼￼￼￼
      |   ^
compiler.cpp:68:4: error: stray '\357' in program
   68 | ￼￼￼￼￼
      |    ^
compiler.cpp:68:5: error: stray '\277' in program
   68 | ￼￼￼￼￼
      |     ^
compiler.cpp:68:6: error: stray '\274' in program
   68 | ￼￼￼￼￼
      |      ^
compiler.cpp:68:7: error: stray '\357' in program
   68 | ￼￼￼￼￼
      |       ^
compiler.cpp:68:8: error: stray '\277' in program
   68 | ￼￼￼￼￼
      |        ^
compiler.cpp:68:9: error: stray '\274' in program
   68 | ￼￼￼￼￼
      |         ^
compiler.cpp:68:10: error: stray '\357' in program
   68 | ￼￼￼￼￼
      |          ^
compiler.cpp:68:11: error: stray '\277' in program
   68 | ￼￼￼￼￼
      |           ^
compiler.cpp:68:12: error: stray '\274' in program
   68 | ￼￼￼￼￼
      |            ^
compiler.cpp:68:13: error: stray '\357' in program
   68 | ￼￼￼￼￼
      |             ^
compiler.cpp:68:14: error: stray '\277' in program
   68 | ￼￼￼￼￼
      |              ^
compiler.cpp:68:15: error: stray '\274' in program
   68 | ￼￼￼￼￼
      |               ^
compiler.cpp:70:49: warning: multi-character character constant [-Wmultichar]
   70 | source_file.java:413: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:71:1: error: stray '\357' in program
   71 | ￼￼￼￼￼
      | ^
compiler.cpp:71:2: error: stray '\277' in program
   71 | ￼￼￼￼￼
      |  ^
compiler.cpp:71:3: error: stray '\274' in program
   71 | ￼￼￼￼￼
      |   ^
compiler.cpp:71:4: error: stray '\357' in program
   71 | ￼￼￼￼￼
      |    ^
compiler.cpp:71:5: error: stray '\277' in program
   71 | ￼￼￼￼￼
      |     ^
compiler.cpp:71:6: error: stray '\274' in program
   71 | ￼￼￼￼￼
      |      ^
compiler.cpp:71:7: error: stray '\357' in program
   71 | ￼￼￼￼￼
      |       ^
compiler.cpp:71:8: error: stray '\277' in program
   71 | ￼￼￼￼￼
      |        ^
compiler.cpp:71:9: error: stray '\274' in program
   71 | ￼￼￼￼￼
      |         ^
compiler.cpp:71:10: error: stray '\357' in program
   71 | ￼￼￼￼￼
      |          ^
compiler.cpp:71:11: error: stray '\277' in program
   71 | ￼￼￼￼￼
      |           ^
compiler.cpp:71:12: error: stray '\274' in program
   71 | ￼￼￼￼￼
      |            ^
compiler.cpp:71:13: error: stray '\357' in program
   71 | ￼￼￼￼￼
      |             ^
compiler.cpp:71:14: error: stray '\277' in program
   71 | ￼￼￼￼￼
      |              ^
compiler.cpp:71:15: error: stray '\274' in program
   71 | ￼￼￼￼￼
      |               ^
compiler.cpp:73:49: warning: multi-character character constant [-Wmultichar]
   73 | source_file.java:413: error: illegal character: '\ufffc'
      |                                                 ^~~~~~~~
compiler.cpp:74:1: error: stray '\357' in program
   74 | ￼￼￼￼￼
      | ^
compiler.cpp:74:2: error: stray '\277' in program
   74 | ￼￼￼￼￼
      |  ^
compiler.cpp:74:3: error: stray '\274' in program
   74 | ￼￼￼￼￼
      |   ^
compiler.cpp:74:4: error: stray '\357' in program
   74 | ￼￼￼￼￼
      |    ^
compiler.cpp:74:5: error: stray '\277' in program
   74 | ￼￼￼￼￼
      |     ^
compiler.cpp:74:6: error: stray '\274' in program
   74 | ￼￼￼￼￼
      |      ^
compiler.cpp:74:7: error: stray '\357' in program
   74 | ￼￼￼￼￼
      |       ^
compiler.cpp:74:8: error: stray '\277' in program
   74 | ￼￼￼￼￼
      |        ^
compiler.cpp:74:9: error: stray '\274' in program
   74 | ￼￼￼￼￼
      |         ^
compiler.cpp:74:10: error: stray '\357' in program
   74 | ￼￼￼￼￼
      |          ^
compiler.cpp:74:11: error: stray '\277' in program
   74 | ￼￼￼￼￼
      |           ^
compiler.cpp:74:12: error: stray '\274' in program
   74 | ￼￼￼￼￼
      |            ^
compiler.cpp:74:13: error: stray '\357' in program
   74 | ￼￼￼￼￼
      |             ^
compiler.cpp:74:14: error: stray '\277' in program
   74 | ￼￼￼￼￼
      |              ^
compiler.cpp:74:15: error: stray '\274' in program
   74 | ￼￼￼￼￼
      |               ^
compiler.cpp:3:1: error: expected unqualified-id before '^' token
    3 | ^
      | ^
