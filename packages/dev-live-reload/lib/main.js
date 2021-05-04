module.exports = {
  activate(state) {
    if (!atom.inDevMode() || atom.inSpecMode()) return;

    if (atom.packages.hasActivatedInitialPackages()) {
      this.startWatching();
    } else {
      this.activatedDisposable = atom.packages.onDidActivateInitialPackages(
        () => this.startWatching()
      );
    }
  },

  deactivate() {
    if (this.activatedDisposable) this.activatedDisposable.dispose();
    if (this.commandDisposable) this.commandDisposable.dispose();
    if (this.uiWatcher) this.uiWatcher.destroy();
  },

  startWatching() {
    const UIWatcher = require('./ui-watcher');
    this.uiWatcher = new UIWatcher({ themeManager: atom.themes });
    this.commandDisposable = atom.commands.add(
      'atom-workspace',
      'dev-live-reload:reload-all',
      () => this.uiWatcher.reloadAll()
    );
    if (this.activatedDisposable) this.activatedDisposable.dispose();
  }
};
