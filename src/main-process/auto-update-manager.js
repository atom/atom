const { EventEmitter } = require('events');
const os = require('os');
const path = require('path');

const IdleState = 'idle';
const CheckingState = 'checking';
const DownloadingState = 'downloading';
const UpdateAvailableState = 'update-available';
const NoUpdateAvailableState = 'no-update-available';
const UnsupportedState = 'unsupported';
const ErrorState = 'error';

let autoUpdater = null;

module.exports = class AutoUpdateManager extends EventEmitter {
  constructor(version, testMode, config) {
    super();
    this.onUpdateNotAvailable = this.onUpdateNotAvailable.bind(this);
    this.onUpdateError = this.onUpdateError.bind(this);
    this.version = version;
    this.testMode = testMode;
    this.config = config;
    this.state = IdleState;
    this.iconPath = path.resolve(
      __dirname,
      '..',
      '..',
      'resources',
      'atom.png'
    );
    this.updateUrlPrefix =
      process.env.ATOM_UPDATE_URL_PREFIX || 'https://atom.io';
  }

  initialize() {
    if (process.platform === 'win32') {
      const archSuffix = process.arch === 'ia32' ? '' : `-${process.arch}`;
      this.feedUrl =
        this.updateUrlPrefix +
        `/api/updates${archSuffix}?version=${this.version}&os_version=${
          os.release
        }`;
      autoUpdater = require('./auto-updater-win32');
    } else {
      this.feedUrl =
        this.updateUrlPrefix +
        `/api/updates?version=${this.version}&os_version=${os.release}`;
      ({ autoUpdater } = require('electron'));
    }

    autoUpdater.on('error', (event, message) => {
      this.setState(ErrorState, message);
      this.emitWindowEvent('update-error');
      console.error(`Error Downloading Update: ${message}`);
    });

    autoUpdater.setFeedURL(this.feedUrl);

    autoUpdater.on('checking-for-update', () => {
      this.setState(CheckingState);
      this.emitWindowEvent('checking-for-update');
    });

    autoUpdater.on('update-not-available', () => {
      this.setState(NoUpdateAvailableState);
      this.emitWindowEvent('update-not-available');
    });

    autoUpdater.on('update-available', () => {
      this.setState(DownloadingState);
      // We use sendMessage to send an event called 'update-available' in 'update-downloaded'
      // once the update download is complete. This mismatch between the electron
      // autoUpdater events is unfortunate but in the interest of not changing the
      // one existing event handled by applicationDelegate
      this.emitWindowEvent('did-begin-downloading-update');
      this.emit('did-begin-download');
    });

    autoUpdater.on(
      'update-downloaded',
      (event, releaseNotes, releaseVersion) => {
        this.releaseVersion = releaseVersion;
        this.setState(UpdateAvailableState);
        this.emitUpdateAvailableEvent();
      }
    );

    this.config.onDidChange('core.automaticallyUpdate', ({ newValue }) => {
      if (newValue) {
        this.scheduleUpdateCheck();
      } else {
        this.cancelScheduledUpdateCheck();
      }
    });

    if (this.config.get('core.automaticallyUpdate')) this.scheduleUpdateCheck();

    switch (process.platform) {
      case 'win32':
        if (!autoUpdater.supportsUpdates()) {
          this.setState(UnsupportedState);
        }
        break;
      case 'linux':
        this.setState(UnsupportedState);
    }
  }

  emitUpdateAvailableEvent() {
    if (this.releaseVersion == null) return;
    this.emitWindowEvent('update-available', {
      releaseVersion: this.releaseVersion
    });
  }

  emitWindowEvent(eventName, payload) {
    for (let atomWindow of this.getWindows()) {
      atomWindow.sendMessage(eventName, payload);
    }
  }

  setState(state, errorMessage) {
    if (this.state === state) return;
    this.state = state;
    this.errorMessage = errorMessage;
    this.emit('state-changed', this.state);
  }

  getState() {
    return this.state;
  }

  getErrorMessage() {
    return this.errorMessage;
  }

  scheduleUpdateCheck() {
    // Only schedule update check periodically if running in release version and
    // and there is no existing scheduled update check.
    if (!/-dev/.test(this.version) && !this.checkForUpdatesIntervalID) {
      const checkForUpdates = () => this.check({ hidePopups: true });
      const fourHours = 1000 * 60 * 60 * 4;
      this.checkForUpdatesIntervalID = setInterval(checkForUpdates, fourHours);
      checkForUpdates();
    }
  }

  cancelScheduledUpdateCheck() {
    if (this.checkForUpdatesIntervalID) {
      clearInterval(this.checkForUpdatesIntervalID);
      this.checkForUpdatesIntervalID = null;
    }
  }

  check({ hidePopups } = {}) {
    if (!hidePopups) {
      autoUpdater.once('update-not-available', this.onUpdateNotAvailable);
      autoUpdater.once('error', this.onUpdateError);
    }

    if (!this.testMode) autoUpdater.checkForUpdates();
  }

  install() {
    if (!this.testMode) autoUpdater.quitAndInstall();
  }

  onUpdateNotAvailable() {
    autoUpdater.removeListener('error', this.onUpdateError);
    const { dialog } = require('electron');
    dialog.showMessageBox({
      type: 'info',
      buttons: ['OK'],
      icon: this.iconPath,
      message: 'No update available.',
      title: 'No Update Available',
      detail: `Version ${this.version} is the latest version.`
    });
  }

  onUpdateError(event, message) {
    autoUpdater.removeListener(
      'update-not-available',
      this.onUpdateNotAvailable
    );
    const { dialog } = require('electron');
    dialog.showMessageBox({
      type: 'warning',
      buttons: ['OK'],
      icon: this.iconPath,
      message: 'There was an error checking for updates.',
      title: 'Update Error',
      detail: message
    });
  }

  getWindows() {
    return global.atomApplication.getAllWindows();
  }
};
