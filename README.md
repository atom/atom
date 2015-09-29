![Atom](https://cloud.githubusercontent.com/assets/72919/2874231/3af1db48-d3dd-11e3-98dc-6066f8bc766f.png)

[![Build Status](https://travis-ci.org/atom/atom.svg?branch=master)](https://travis-ci.org/atom/atom)
[![Dependency Status](https://david-dm.org/atom/atom.svg)](https://david-dm.org/atom/atom)
[![Join the Atom Community on Slack](http://atom-slack.herokuapp.com/badge.svg)](http://atom-slack.herokuapp.com/)

Atom是21世纪超好用的文本编辑器,由[Electron](https://github.com/atom/electron)编写,并且是基于所有我们喜欢的编辑器. 我们深度定制它,但是仍然使用简单的默认配置.

访问[atom.io](https://atom.io)学习更多或者访问[Atom forum](https://discuss.atom.io).

按照[@AtomEditor](https://twitter.com/atomeditor)在Twitter上的重要公告.

该项目遵循[Contributor Covenant 1.2](http://contributor-covenant.org/version/1/2/0)协议.
通过参与,我们希望你可以坚持更新代码.请向atom@github.com提交BUG.

## 文件

如果你想了解如何使用Atom或者开发插件,请参考在线免费文档[Atom Flight Manual](https://atom.io/docs/latest/),或者下载ePub, PDF或者mobi版本.你可以在 [atom/docs](https://github.com/atom/docs)上找到源代码.

该[API文档](https://atom.io/docs/api)开发包也被记录在Atom.io.

##安装

### OS X

下载最新版[Atom 正式版](https://github.com/atom/atom/releases/latest).

当一个新版本可用时Atom会自动更新.

### Windows

下载最新版[AtomSetup.exe installer](https://github.com/atom/atom/releases/latest).

当一个新版本可用时Atom会自动更新.

你也可以从[版本历史页面](https://github.com/atom/atom/releases/latest)下载一个`atom-windows.zip`文件.
`.zip`历史版不会自动更新.

使用[chocolatey](https://chocolatey.org/)? 运行 `cinst Atom`安装最新版Atom.

### Debian Linux (Ubuntu)

Currently only a 64-bit version is available.

1.下载`atom-amd64.deb` from the [Atom releases page](https://github.com/atom/atom/releases/latest).
2.运行`sudo dpkg --install atom-amd64.deb` on the downloaded package.
3. Launch Atom using the installed `atom` command.

The Linux version does not currently automatically update so you will need to
repeat these steps to upgrade to future releases.

### Red Hat Linux (Fedora 21 and under, CentOS, Red Hat)

Currently only a 64-bit version is available.

1. Download `atom.x86_64.rpm` from the [Atom releases page](https://github.com/atom/atom/releases/latest).
2. Run `sudo yum localinstall atom.x86_64.rpm` on the downloaded package.
3. Launch Atom using the installed `atom` command.

The Linux version does not currently automatically update so you will need to
repeat these steps to upgrade to future releases.

### Fedora 22+

Currently only a 64-bit version is available.

1. Download `atom.x86_64.rpm` from the [Atom releases page](https://github.com/atom/atom/releases/latest).
2. Run `sudo dnf install atom.x86_64.rpm` on the downloaded package.
3. Launch Atom using the installed `atom` command.

The Linux version does not currently automatically update so you will need to
repeat these steps to upgrade to future releases.

## 编译

* [Linux](docs/build-instructions/linux.md)
* [OS X](docs/build-instructions/os-x.md)
* [FreeBSD](docs/build-instructions/freebsd.md)
* [Windows](docs/build-instructions/windows.md)
