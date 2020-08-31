const { CompositeDisposable, Emitter } = require('atom');
const AboutView = require('./components/about-view');

// Deferred requires
let shell;

module.exports = class About {
  constructor(initialState) {
    this.subscriptions = new CompositeDisposable();
    this.emitter = new Emitter();

    this.state = initialState;
    this.views = {
      aboutView: null
    };

    this.subscriptions.add(
      atom.workspace.addOpener(uriToOpen => {
        if (uriToOpen === this.state.uri) {
          return this.deserialize();
        }
      })
    );

    this.subscriptions.add(
      atom.commands.add('atom-workspace', 'about:view-release-notes', () => {
        shell = shell || require('electron').shell;
        shell.openExternal(
          this.state.updateManager.getReleaseNotesURLForCurrentVersion()
        );
      })
    );
  }

  destroy() {
    if (this.views.aboutView) this.views.aboutView.destroy();
    this.views.aboutView = null;

    if (this.state.updateManager) this.state.updateManager.dispose();
    this.setState({ updateManager: null });

    this.subscriptions.dispose();
  }

  setState(newState) {
    if (newState && typeof newState === 'object') {
      let { state } = this;
      this.state = Object.assign({}, state, newState);

      this.didChange();
    }
  }

  didChange() {
    this.emitter.emit('did-change');
  }

  onDidChange(callback) {
    this.emitter.on('did-change', callback);
  }

  deserialize(state) {
    if (!this.views.aboutView) {
      this.setState(state);

      this.views.aboutView = new AboutView({
        uri: this.state.uri,
        updateManager: this.state.updateManager,
        currentAtomVersion: this.state.currentAtomVersion,
        currentElectronVersion: this.state.currentElectronVersion,
        currentChromeVersion: this.state.currentChromeVersion,
        currentNodeVersion: this.state.currentNodeVersion,
        availableVersion: this.state.updateManager.getAvailableVersion()
      });
      this.handleStateChanges();
    }

    return this.views.aboutView;
  }

  handleStateChanges() {
    this.onDidChange(() => {
      if (this.views.aboutView) {
        this.views.aboutView.update({
          updateManager: this.state.updateManager,
          currentAtomVersion: this.state.currentAtomVersion,
          currentElectronVersion: this.state.currentElectronVersion,
          currentChromeVersion: this.state.currentChromeVersion,
          currentNodeVersion: this.state.currentNodeVersion,
          availableVersion: this.state.updateManager.getAvailableVersion()
        });
      }
    });

    this.state.updateManager.onDidChange(() => {
      this.didChange();
    });
  }
};
