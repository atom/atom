const GrammarListView = require('./grammar-list-view');
const GrammarStatusView = require('./grammar-status-view');

let commandDisposable = null;
let grammarListView = null;
let grammarStatusView = null;

module.exports = {
  activate() {
    commandDisposable = atom.commands.add(
      'atom-text-editor',
      'grammar-selector:show',
      () => {
        if (!grammarListView) grammarListView = new GrammarListView();
        grammarListView.toggle();
      }
    );
  },

  deactivate() {
    if (commandDisposable) commandDisposable.dispose();
    commandDisposable = null;

    if (grammarStatusView) grammarStatusView.destroy();
    grammarStatusView = null;

    if (grammarListView) grammarListView.destroy();
    grammarListView = null;
  },

  consumeStatusBar(statusBar) {
    grammarStatusView = new GrammarStatusView(statusBar);
    grammarStatusView.attach();
  }
};
