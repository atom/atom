const fs = require('fs-plus');
const path = require('path');
const Watcher = require('./watcher');

module.exports = class BaseThemeWatcher extends Watcher {
  constructor() {
    super();
    this.stylesheetsPath = path.dirname(
      atom.themes.resolveStylesheet('../static/atom.less')
    );
    this.watch();
  }

  watch() {
    const filePaths = fs
      .readdirSync(this.stylesheetsPath)
      .filter(filePath => path.extname(filePath).includes('less'));

    for (const filePath of filePaths) {
      this.watchFile(path.join(this.stylesheetsPath, filePath));
    }
  }

  loadStylesheet() {
    this.loadAllStylesheets();
  }

  loadAllStylesheets() {
    atom.themes.reloadBaseStylesheets();
  }
};
