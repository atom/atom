const { Emitter, CompositeDisposable } = require('event-kit');

module.exports = class AutoUpdateManager {
  constructor({ applicationDelegate }) {
    this.applicationDelegate = applicationDelegate;
    this.subscriptions = new CompositeDisposable();
    this.emitter = new Emitter();
  }

  initialize() {
    this.subscriptions.add(
      this.applicationDelegate.onDidBeginCheckingForUpdate(() => {
        this.emitter.emit('did-begin-checking-for-update');
      }),
      this.applicationDelegate.onDidBeginDownloadingUpdate(() => {
        this.emitter.emit('did-begin-downloading-update');
      }),
      this.applicationDelegate.onDidCompleteDownloadingUpdate(details => {
        this.emitter.emit('did-complete-downloading-update', details);
      }),
      this.applicationDelegate.onUpdateNotAvailable(() => {
        this.emitter.emit('update-not-available');
      }),
      this.applicationDelegate.onUpdateError(() => {
        this.emitter.emit('update-error');
      })
    );
  }

  destroy() {
    this.subscriptions.dispose();
    this.emitter.dispose();
  }

  checkForUpdate() {
    this.applicationDelegate.checkForUpdate();
  }

  restartAndInstallUpdate() {
    this.applicationDelegate.restartAndInstallUpdate();
  }

  getState() {
    return this.applicationDelegate.getAutoUpdateManagerState();
  }

  getErrorMessage() {
    return this.applicationDelegate.getAutoUpdateManagerErrorMessage();
  }

  platformSupportsUpdates() {
    return (
      atom.getReleaseChannel() !== 'dev' && this.getState() !== 'unsupported'
    );
  }

  onDidBeginCheckingForUpdate(callback) {
    return this.emitter.on('did-begin-checking-for-update', callback);
  }

  onDidBeginDownloadingUpdate(callback) {
    return this.emitter.on('did-begin-downloading-update', callback);
  }

  onDidCompleteDownloadingUpdate(callback) {
    return this.emitter.on('did-complete-downloading-update', callback);
  }

  // TODO: When https://github.com/atom/electron/issues/4587 is closed, we can
  // add an update-available event.
  // onUpdateAvailable (callback) {
  //   return this.emitter.on('update-available', callback)
  // }

  onUpdateNotAvailable(callback) {
    return this.emitter.on('update-not-available', callback);
  }

  onUpdateError(callback) {
    return this.emitter.on('update-error', callback);
  }

  getPlatform() {
    return process.platform;
  }
};
