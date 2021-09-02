const { EventEmitter } = require('events');
const SquirrelUpdate = require('./squirrel-update');

class AutoUpdater extends EventEmitter {
  setFeedURL(updateUrl) {
    this.updateUrl = updateUrl;
  }

  quitAndInstall() {
    if (SquirrelUpdate.existsSync()) {
      SquirrelUpdate.restartAtom();
    } else {
      require('electron').autoUpdater.quitAndInstall();
    }
  }

  downloadUpdate(callback) {
    SquirrelUpdate.spawn(['--download', this.updateUrl], function(
      error,
      stdout
    ) {
      let update;
      if (error != null) return callback(error);

      try {
        // Last line of output is the JSON details about the releases
        const json = stdout
          .trim()
          .split('\n')
          .pop();
        const data = JSON.parse(json);
        const releasesToApply = data && data.releasesToApply;
        if (releasesToApply.pop) update = releasesToApply.pop();
      } catch (error) {
        error.stdout = stdout;
        return callback(error);
      }

      callback(null, update);
    });
  }

  installUpdate(callback) {
    SquirrelUpdate.spawn(['--update', this.updateUrl], callback);
  }

  supportsUpdates() {
    return SquirrelUpdate.existsSync();
  }

  checkForUpdates() {
    if (!this.updateUrl) throw new Error('Update URL is not set');

    this.emit('checking-for-update');

    if (!SquirrelUpdate.existsSync()) {
      this.emit('update-not-available');
      return;
    }

    this.downloadUpdate((error, update) => {
      if (error != null) {
        this.emit('update-not-available');
        return;
      }

      if (update == null) {
        this.emit('update-not-available');
        return;
      }

      this.emit('update-available');

      this.installUpdate(error => {
        if (error != null) {
          this.emit('update-not-available');
          return;
        }

        this.emit(
          'update-downloaded',
          {},
          update.releaseNotes,
          update.version,
          new Date(),
          'https://atom.io',
          () => this.quitAndInstall()
        );
      });
    });
  }
}

module.exports = new AutoUpdater();
