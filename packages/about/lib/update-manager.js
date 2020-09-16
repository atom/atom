const { Emitter, CompositeDisposable } = require('atom');

const Unsupported = 'unsupported';
const Idle = 'idle';
const CheckingForUpdate = 'checking';
const DownloadingUpdate = 'downloading';
const UpdateAvailableToInstall = 'update-available';
const UpToDate = 'no-update-available';
const ErrorState = 'error';

let UpdateManager = class UpdateManager {
  constructor() {
    this.emitter = new Emitter();
    this.currentVersion = atom.getVersion();
    this.availableVersion = atom.getVersion();
    this.resetState();
    this.listenForAtomEvents();
  }

  listenForAtomEvents() {
    this.subscriptions = new CompositeDisposable();

    this.subscriptions.add(
      atom.autoUpdater.onDidBeginCheckingForUpdate(() => {
        this.setState(CheckingForUpdate);
      }),
      atom.autoUpdater.onDidBeginDownloadingUpdate(() => {
        this.setState(DownloadingUpdate);
      }),
      atom.autoUpdater.onDidCompleteDownloadingUpdate(({ releaseVersion }) => {
        this.setAvailableVersion(releaseVersion);
      }),
      atom.autoUpdater.onUpdateNotAvailable(() => {
        this.setState(UpToDate);
      }),
      atom.autoUpdater.onUpdateError(() => {
        this.setState(ErrorState);
      }),
      atom.config.observe('core.automaticallyUpdate', value => {
        this.autoUpdatesEnabled = value;
        this.emitDidChange();
      })
    );

    // TODO: When https://github.com/atom/electron/issues/4587 is closed we can add this support.
    // atom.autoUpdater.onUpdateAvailable =>
    //   @find('.about-updates-item').removeClass('is-shown')
    //   @updateAvailable.addClass('is-shown')
  }

  dispose() {
    this.subscriptions.dispose();
  }

  onDidChange(callback) {
    return this.emitter.on('did-change', callback);
  }

  emitDidChange() {
    this.emitter.emit('did-change');
  }

  getAutoUpdatesEnabled() {
    return (
      this.autoUpdatesEnabled && this.state !== UpdateManager.State.Unsupported
    );
  }

  setAutoUpdatesEnabled(enabled) {
    return atom.config.set('core.automaticallyUpdate', enabled);
  }

  getErrorMessage() {
    return atom.autoUpdater.getErrorMessage();
  }

  getState() {
    return this.state;
  }

  setState(state) {
    this.state = state;
    this.emitDidChange();
  }

  resetState() {
    this.state = atom.autoUpdater.platformSupportsUpdates()
      ? atom.autoUpdater.getState()
      : Unsupported;
    this.emitDidChange();
  }

  getAvailableVersion() {
    return this.availableVersion;
  }

  setAvailableVersion(version) {
    this.availableVersion = version;

    if (this.availableVersion !== this.currentVersion) {
      this.state = UpdateAvailableToInstall;
    } else {
      this.state = UpToDate;
    }

    this.emitDidChange();
  }

  checkForUpdate() {
    atom.autoUpdater.checkForUpdate();
  }

  restartAndInstallUpdate() {
    atom.autoUpdater.restartAndInstallUpdate();
  }

  getReleaseNotesURLForCurrentVersion() {
    return this.getReleaseNotesURLForVersion(this.currentVersion);
  }

  getReleaseNotesURLForAvailableVersion() {
    return this.getReleaseNotesURLForVersion(this.availableVersion);
  }

  getReleaseNotesURLForVersion(appVersion) {
    // Dev versions will not have a releases page
    if (appVersion.indexOf('dev') > -1) {
      return 'https://atom.io/releases';
    }

    if (!appVersion.startsWith('v')) {
      appVersion = `v${appVersion}`;
    }

    const releaseRepo =
      appVersion.indexOf('nightly') > -1 ? 'atom-nightly-releases' : 'atom';
    return `https://github.com/atom/${releaseRepo}/releases/tag/${appVersion}`;
  }
};

UpdateManager.State = {
  Unsupported: Unsupported,
  Idle: Idle,
  CheckingForUpdate: CheckingForUpdate,
  DownloadingUpdate: DownloadingUpdate,
  UpdateAvailableToInstall: UpdateAvailableToInstall,
  UpToDate: UpToDate,
  Error: ErrorState
};

module.exports = UpdateManager;
