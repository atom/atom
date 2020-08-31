module.exports = {
  updateError() {
    atom.autoUpdater.emitter.emit('update-error');
  },

  checkForUpdate() {
    atom.autoUpdater.emitter.emit('did-begin-checking-for-update');
  },

  updateNotAvailable() {
    atom.autoUpdater.emitter.emit('update-not-available');
  },

  downloadUpdate() {
    atom.autoUpdater.emitter.emit('did-begin-downloading-update');
  },

  finishDownloadingUpdate(releaseVersion) {
    atom.autoUpdater.emitter.emit('did-complete-downloading-update', {
      releaseVersion
    });
  }
};
