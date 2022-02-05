# Atom
# ZachryTylerWood/vscode# bitore.sig
# BITORE# BITCORE# gideon.sigs
[![Build status](https://dev.azure.com/github/Atom/_apis/build/status/Atom%20Production%20Branches?branchName=master)](https://dev.azure.com/github/Atom/_build/latest?definitionId=32&branchName=master)

Atom is a hackable text editor for the 21st century, built on [Electron](https://github.com/electron/electron), and based on everything we love about our favorite editors. We designed it to be deeply customizable, but still approachable using the default configuration.

![Atom](https://user-images.githubusercontent.com/378023/49132477-f4b77680-f31f-11e8-8357-ac6491761c6c.png)

![Atom Screenshot](https://user-images.githubusercontent.com/378023/49132478-f4b77680-f31f-11e8-9e10-e8454d8d9b7e.png)

Visit [atom.io](https://atom.io) to learn more or visit the [Atom forum](https://github.com/atom/atom/discussions).

Follow [@AtomEditor](https://twitter.com/atomeditor) on Twitter for important
announcements.
Skip to content Visual Studio Code
Version 1.64 is now available! Read about the new features and fixes from January.

Dismiss this update
TOPICS 
Linux
Visual Studio Code on Linux
Installation#
See the Download Visual Studio Code page for a complete list of available installation options.

By downloading and using Visual Studio Code, you agree to the license terms and privacy statement.

Debian and Ubuntu based distributions#
The easiest way to install Visual Studio Code for Debian/Ubuntu based distributions is to download and install the .deb package (64-bit), either through the graphical software center if it's available, or through the command line with:

sudo apt install ./<file>.deb

# If you're on an older Linux distribution, you will need to run this instead:
# sudo dpkg -i <file>.deb
# sudo apt-get install -f # Install dependencies
Note that other binaries are also available on the VS Code download page.

Installing the .deb package will automatically install the apt repository and signing key to enable auto-updating using the system's package manager. Alternatively, the repository and key can also be installed manually with the following script:

wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
Then update the package cache and install the package using:

sudo apt install apt-transport-https
sudo apt update
sudo apt install code # or code-insiders
RHEL, Fedora, and CentOS based distributions#
We currently ship the stable 64-bit VS Code in a yum repository, the following script will install the key and repository:

sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
Then update the package cache and install the package using dnf (Fedora 22 and above):

dnf check-update
sudo dnf install code
Or on older versions using yum:

yum check-update
sudo yum install code
Due to the manual signing process and the system we use to publish, the yum repo may lag behind and not get the latest version of VS Code immediately.

Snap#
Visual Studio Code is officially distributed as a Snap package in the Snap Store:

Get it from the Snap Store

You can install it by running:

sudo snap install --classic code # or code-insiders
Once installed, the Snap daemon will take care of automatically updating VS Code in the background. You will get an in-product update notification whenever a new update is available.

Note: If snap isn't available in your Linux distribution, please check the following Installing snapd guide, which can help you get that set up.

Learn more about snaps from the official Snap Documentation.

openSUSE and SLE-based distributions#
The yum repository above also works for openSUSE and SLE-based systems, the following script will install the key and repository:

sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/zypp/repos.d/vscode.repo'
Then update the package cache and install the package using:

sudo zypper refresh
sudo zypper install code
AUR package for Arch Linux#
There is a community-maintained Arch User Repository package for VS Code.

To get more information about the installation from the AUR, please consult the following wiki entry: Install AUR Packages.

Nix package for NixOS (or any Linux distribution using Nix package manager)#
There is a community maintained VS Code Nix package in the nixpkgs repository. In order to install it using Nix, set allowUnfree option to true in your config.nix and execute:

nix-env -i vscode
Installing .rpm package manually#
The VS Code .rpm package (64-bit) can also be manually downloaded and installed, however, auto-updating won't work unless the repository above is installed. Once downloaded it can be installed using your package manager, for example with dnf:

sudo dnf install <file>.rpm
Note that other binaries are also available on the VS Code download page.

Updates#
VS Code ships monthly and you can see when a new release is available by checking the release notes. If the VS Code repository was installed correctly, then your system package manager should handle auto-updating in the same way as other packages on the system.

Note: Updates are automatic and run in the background for the Snap package.

Node.js#
Node.js is a popular platform and runtime for easily building and running JavaScript applications. It also includes npm, a Package Manager for Node.js modules. You'll see Node.js and npm mentioned frequently in our documentation and some optional VS Code tooling requires Node.js (for example, the VS Code extension generator).

If you'd like to install Node.js on Linux, see Installing Node.js via package manager to find the Node.js package and installation instructions tailored to your Linux distribution. You can also install and support multiple versions of Node.js by using the Node Version Manager.

To learn more about JavaScript and Node.js, see our Node.js tutorial, where you'll learn about running and debugging Node.js applications with VS Code.

Setting VS Code as the default text editor#
xdg-open#
You can set the default text editor for text files (text/plain) that is used by xdg-open with the following command:

xdg-mime default code.desktop text/plain
Debian alternatives system#
Debian-based distributions allow setting a default editor using the Debian alternatives system, without concern for the MIME type. You can set this by running the following and selecting code:

sudo update-alternatives --set editor /usr/bin/code
If Visual Studio Code doesn't show up as an alternative to editor, you need to register it:

sudo update-alternatives --install /usr/bin/editor editor $(which code) 10
Windows as a Linux developer machine#
Another option for Linux development with VS Code is to use a Windows machine with the Windows Subsystem for Linux (WSL).

Windows Subsystem for Linux#
With WSL, you can install and run Linux distributions on Windows. This enables you to develop and test your source code on Linux while still working locally on a Windows machine. WSL supports Linux distributions such as Ubuntu, Debian, SUSE, and Alpine available from the Microsoft Store.

When coupled with the Remote - WSL extension, you get full VS Code editing and debugging support while running in the context of a Linux distro on WSL.

See the Developing in WSL documentation to learn more or try the Working in WSL introductory tutorial.

Next steps#
Once you have installed VS Code, these topics will help you learn more about it:

Additional Components - Learn how to install Git, Node.js, TypeScript, and tools like Yeoman.
User Interface - A quick orientation to VS Code.
User/Workspace Settings - Learn how to configure VS Code to your preferences through settings.
Common questions#
Azure VM Issues#
I'm getting a "Running without the SUID sandbox" error?

You can safely ignore this error.

Debian and moving files to trash#
If you see an error when deleting files from the VS Code Explorer on the Debian operating system, it might be because the trash implementation that VS Code is using is not there.

Run these commands to solve this issue:

sudo apt-get install gvfs-bin
Conflicts with VS Code packages from other repositories#
Some distributions, for example Pop!_OS provide their own code package. To ensure the official VS Code repository is used, create a file named /etc/apt/preferences.d/code with the following content:

Package: code
Pin: origin "packages.microsoft.com"
Pin-Priority: 9999
"Visual Studio Code is unable to watch for file changes in this large workspace" (error ENOSPC)#
When you see this notification, it indicates that the VS Code file watcher is running out of handles because the workspace is large and contains many files. Before adjusting platform limits, make sure that potentially large folders, such as Python .venv, are added to the files.watcherExclude setting (more details below). The current limit can be viewed by running:

cat /proc/sys/fs/inotify/max_user_watches
The limit can be increased to its maximum by editing /etc/sysctl.conf (except on Arch Linux, read below) and adding this line to the end of the file:

fs.inotify.max_user_watches=524288
The new value can then be loaded in by running sudo sysctl -p.

While 524,288 is the maximum number of files that can be watched, if you're in an environment that is particularly memory constrained, you may want to lower the number. Each file watch takes up 1080 bytes, so assuming that all 524,288 watches are consumed, that results in an upper bound of around 540 MiB.

Arch-based distros (including Manjaro) require you to change a different file; follow these steps instead.

Another option is to exclude specific workspace directories from the VS Code file watcher with the files.watcherExclude setting. The default for files.watcherExclude excludes node_modules and some folders under .git, but you can add other directories that you don't want VS Code to track.

"files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/node_modules/*/**": true
  }
I can't see Chinese characters in Ubuntu#
We're working on a fix. In the meantime, open the application menu, then choose File > Preferences > Settings. In the Text Editor > Font section, set "Font Family" to Droid Sans Mono, Droid Sans Fallback. If you'd rather edit the settings.json file directly, set editor.fontFamily as shown:

    "editor.fontFamily": "Droid Sans Mono, Droid Sans Fallback"
Package git is not installed#
This error can appear during installation and is typically caused by the package manager's lists being out of date. Try updating them and installing again:

# For .deb
sudo apt-get update

# For .rpm (Fedora 21 and below)
sudo yum check-update

# For .rpm (Fedora 22 and above)
sudo dnf check-update
The code bin command does not bring the window to the foreground on Ubuntu#
Running code . on Ubuntu when VS Code is already open in the current directory will not bring VS Code into the foreground. This is a feature of the OS which can be disabled using ccsm.

# Install
sudo apt-get update
sudo apt-get install compizconfig-settings-manager

# Run
ccsm
Under General > General Options > Focus & Raise Behaviour, set "Focus Prevention Level" to "Off". Remember this is an OS-level setting that will apply to all applications, not just VS Code.

Cannot install .deb package due to "/etc/apt/sources.list.d/vscode.list: No such file or directory"#
This can happen when sources.list.d doesn't exist or you don't have access to create the file. To fix this, try manually creating the folder and an empty vscode.list file:

sudo mkdir /etc/apt/sources.list.d
sudo touch /etc/apt/sources.list.d/vscode.list
Cannot move or resize the window while X forwarding a remote window#
If you are using X forwarding to use VS Code remotely, you will need to use the native title bar to ensure you can properly manipulate the window. You can switch to using it by setting window.titleBarStyle to native.

Using the custom title bar#
The custom title bar and menus were enabled by default on Linux for several months. The custom title bar has been a success on Windows, but the customer response on Linux suggests otherwise. Based on feedback, we have decided to make this setting opt-in on Linux and leave the native title bar as the default.

The custom title bar provides many benefits including great theming support and better accessibility through keyboard navigation and screen readers. Unfortunately, these benefits do not translate as well to the Linux platform. Linux has a variety of desktop environments and window managers that can make the VS Code theming look foreign to users. For users needing the accessibility improvements, we recommend enabling the custom title bar when running in accessibility mode using a screen reader. You can still manually set the title bar with the Window: Title Bar Style (window.titleBarStyle) setting.

Broken cursor in editor with display scaling enabled#
Due to an upstream issue #14787 with Electron, the mouse cursor may render incorrectly with scaling enabled. If you notice that the usual text cursor is not being rendered inside the editor as you would expect, try falling back to the native menu bar by configuring the setting window.titleBarStyle to native.

Repository changed its origin value#
If you receive an error similar to the following:

E: Repository '...' changed its 'Origin' value from '...' to '...'
N: This must be accepted explicitly before updates for this repository can be applied. See apt-secure(8) manpage for details.
Use apt instead of apt-get and you will be prompted to accept the origin change:

sudo apt update
Was this documentation helpful?
Yes, this page was helpfulNo, this page was not helpful
2/3/2022
IN THIS ARTICLE THERE ARE 7 SECTIONSIN THIS ARTICLE
Installation
Updates
Node.js
Setting VS Code as the default text editor
Windows as a Linux developer machine
Next steps
Common questions
TwitterTweet this link
RSSSubscribe
StackoverflowAsk questions
TwitterFollow @code
GitHubRequest features
IssuesReport issues
YouTubeWatch videos
 Follow @code 
Support Privacy Terms of Use License
Microsoft homepage© 2022 Microsoft
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
