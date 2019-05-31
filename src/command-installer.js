const path = require('path');
const fs = require('fs-plus');

module.exports = class CommandInstaller {
  constructor(applicationDelegate) {
    this.applicationDelegate = applicationDelegate;
  }

  initialize(appVersion) {
    this.appVersion = appVersion;
  }

  getInstallDirectory() {
    return '/usr/local/bin';
  }

  getResourcesDirectory() {
    return process.resourcesPath;
  }

  installShellCommandsInteractively() {
    const showErrorDialog = error => {
      this.applicationDelegate.confirm(
        {
          message: 'Failed to install shell commands',
          detail: error.message
        },
        () => {}
      );
    };

    this.installAtomCommand(true, (error, atomCommandName) => {
      if (error) return showErrorDialog(error);
      this.installApmCommand(true, (error, apmCommandName) => {
        if (error) return showErrorDialog(error);
        this.applicationDelegate.confirm(
          {
            message: 'Commands installed.',
            detail: `The shell commands \`${atomCommandName}\` and \`${apmCommandName}\` are installed.`
          },
          () => {}
        );
      });
    });
  }

  getCommandNameForChannel(commandName) {
    let channelMatch = this.appVersion.match(/beta|nightly/);
    let channel = channelMatch ? channelMatch[0] : '';

    switch (channel) {
      case 'beta':
        return `${commandName}-beta`;
      case 'nightly':
        return `${commandName}-nightly`;
      default:
        return commandName;
    }
  }

  installAtomCommand(askForPrivilege, callback) {
    this.installCommand(
      path.join(this.getResourcesDirectory(), 'app', 'atom.sh'),
      this.getCommandNameForChannel('atom'),
      askForPrivilege,
      callback
    );
  }

  installApmCommand(askForPrivilege, callback) {
    this.installCommand(
      path.join(
        this.getResourcesDirectory(),
        'app',
        'apm',
        'node_modules',
        '.bin',
        'apm'
      ),
      this.getCommandNameForChannel('apm'),
      askForPrivilege,
      callback
    );
  }

  installCommand(commandPath, commandName, askForPrivilege, callback) {
    if (process.platform !== 'darwin') return callback();

    const destinationPath = path.join(this.getInstallDirectory(), commandName);

    fs.readlink(destinationPath, (error, realpath) => {
      if (error && error.code !== 'ENOENT') return callback(error);
      if (realpath === commandPath) return callback(null, commandName);
      this.createSymlink(fs, commandPath, destinationPath, error => {
        if (error && error.code === 'EACCES' && askForPrivilege) {
          const fsAdmin = require('fs-admin');
          this.createSymlink(fsAdmin, commandPath, destinationPath, error => {
            callback(error, commandName);
          });
        } else {
          callback(error);
        }
      });
    });
  }

  createSymlink(fs, sourcePath, destinationPath, callback) {
    fs.unlink(destinationPath, error => {
      if (error && error.code !== 'ENOENT') return callback(error);
      fs.makeTree(path.dirname(destinationPath), error => {
        if (error) return callback(error);
        fs.symlink(sourcePath, destinationPath, callback);
      });
    });
  }
};
