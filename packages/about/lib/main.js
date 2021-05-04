const { CompositeDisposable } = require('atom');
const semver = require('semver');
const UpdateManager = require('./update-manager');
const About = require('./about');
const StatusBarView = require('./components/about-status-bar');
let updateManager;

// The local storage key for the available update version.
const AvailableUpdateVersion = 'about:version-available';
const AboutURI = 'atom://about';

module.exports = {
  activate() {
    this.subscriptions = new CompositeDisposable();

    this.createModel();

    let availableVersion = window.localStorage.getItem(AvailableUpdateVersion);
    if (
      atom.getReleaseChannel() === 'dev' ||
      (availableVersion && semver.lte(availableVersion, atom.getVersion()))
    ) {
      this.clearUpdateState();
    }

    this.subscriptions.add(
      updateManager.onDidChange(() => {
        if (
          updateManager.getState() ===
          UpdateManager.State.UpdateAvailableToInstall
        ) {
          window.localStorage.setItem(
            AvailableUpdateVersion,
            updateManager.getAvailableVersion()
          );
          this.showStatusBarIfNeeded();
        }
      })
    );

    this.subscriptions.add(
      atom.commands.add('atom-workspace', 'about:clear-update-state', () => {
        this.clearUpdateState();
      })
    );
  },

  deactivate() {
    this.model.destroy();
    if (this.statusBarTile) this.statusBarTile.destroy();

    if (updateManager) {
      updateManager.dispose();
      updateManager = undefined;
    }
  },

  clearUpdateState() {
    window.localStorage.removeItem(AvailableUpdateVersion);
  },

  consumeStatusBar(statusBar) {
    this.statusBar = statusBar;
    this.showStatusBarIfNeeded();
  },

  deserializeAboutView(state) {
    if (!this.model) {
      this.createModel();
    }

    return this.model.deserialize(state);
  },

  createModel() {
    updateManager = updateManager || new UpdateManager();

    this.model = new About({
      uri: AboutURI,
      currentAtomVersion: atom.getVersion(),
      currentElectronVersion: process.versions.electron,
      currentChromeVersion: process.versions.chrome,
      currentNodeVersion: process.version,
      updateManager: updateManager
    });
  },

  isUpdateAvailable() {
    let availableVersion = window.localStorage.getItem(AvailableUpdateVersion);
    return availableVersion && semver.gt(availableVersion, atom.getVersion());
  },

  showStatusBarIfNeeded() {
    if (this.isUpdateAvailable() && this.statusBar) {
      let statusBarView = new StatusBarView();

      if (this.statusBarTile) {
        this.statusBarTile.destroy();
      }

      this.statusBarTile = this.statusBar.addRightTile({
        item: statusBarView,
        priority: -100
      });

      return this.statusBarTile;
    }
  }
};
