## Atom
Atom and all repositories under Atom will be archived on December 15, 2022. Learn more in our official announcement

Atom is a hackable text editor for the 21st century, built on Electron, and based on everything we love about our favorite editors. We designed it to be deeply customizable, but still approachable using the default configuration.
![image](https://user-images.githubusercontent.com/114422566/194810811-b68cad5b-ebdd-4617-b766-8b2455df2759.png)
Visit atom.io to learn more or visit the Atom forum.

Follow @AtomEditor on Twitter for important announcements.

This project adheres to the Contributor Covenant code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to atom@github.com.
## Documentation
If you want to read about using Atom or developing packages in Atom, the Atom Flight Manual is free and available online. You can find the source to the manual in atom/flight-manual.atom.io.

The API reference for developing packages is also documented on Atom.io.

## Installing
![image](https://user-images.githubusercontent.com/114422566/194811307-197259f0-243b-4497-aac6-31c1bf8619a3.png)
![image](https://user-images.githubusercontent.com/114422566/194811409-1b1bf2db-ab6e-48f7-add2-e0202c86689b.png)

## Prerequisites
Git
# macOS
Download the latest Atom release.

Atom will automatically update when a new release is available.

## Windows
Download the latest Atom installer. AtomSetup.exe is 32-bit. For 64-bit systems, download AtomSetup-x64.exe.

Atom will automatically update when a new release is available.

You can also download atom-windows.zip (32-bit) or atom-x64-windows.zip (64-bit) from the releases page. The .zip version will not automatically update.

Using Chocolatey? Run cinst Atom to install the latest version of Atom.
## Linux
Atom is only available for 64-bit Linux systems.

Configure your distribution's package manager to install and update Atom by following the Linux installation instructions in the Flight Manual. You will also find instructions on how to install Atom's official Linux packages without using a package repository, though you will not get automatic updates after installing Atom this way.

Archive extraction
An archive is available for people who don't want to install atom as root.

This version enables you to install multiple Atom versions in parallel. It has been built on Ubuntu 64-bit, but should be compatible with other Linux distributions.

Install dependencies (on Ubuntu):
sudo apt install git libasound2 libcurl4 libgbm1 libgcrypt20 libgtk-3-0 libnotify4 libnss3 libglib2.0-bin xdg-utils libx11-xcb1 libxcb-dri3-0 libxss1 libxtst6 libxkbfile1
Download atom-amd64.tar.gz from the Atom releases page.
Run tar xf atom-amd64.tar.gz in the directory where you want to extract the Atom folder.
Launch Atom using the installed atom command from the newly extracted directory.
The Linux version does not currently automatically update so you will need to repeat these steps to upgrade to future releases.

## Building
Linux
macOS
Windows
## Discussion
Discuss Atom on GitHub Discussions
## License
MIT

When using the Atom or other GitHub logos, be sure to follow the GitHub logo guidelines.
