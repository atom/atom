const fs = require('fs-plus');

const Watcher = require('./watcher');

module.exports = class PackageWatcher extends Watcher {
  static supportsPackage(pack, type) {
    if (pack.getType() === type && pack.getStylesheetPaths().length)
      return true;
    return false;
  }

  constructor(pack) {
    super();
    this.pack = pack;
    this.watch();
  }

  watch() {
    const watchedPaths = [];
    const watchPath = stylesheet => {
      if (!watchedPaths.includes(stylesheet)) this.watchFile(stylesheet);
      watchedPaths.push(stylesheet);
    };

    const stylesheetsPath = this.pack.getStylesheetsPath();

    if (fs.isDirectorySync(stylesheetsPath)) {
      this.watchDirectory(stylesheetsPath);
    }

    const stylesheetPaths = new Set(this.pack.getStylesheetPaths());
    const onFile = stylesheetPath => stylesheetPaths.add(stylesheetPath);
    const onFolder = () => true;
    fs.traverseTreeSync(stylesheetsPath, onFile, onFolder);

    for (let stylesheet of stylesheetPaths) {
      watchPath(stylesheet);
    }
  }

  loadStylesheet(pathName) {
    if (pathName.includes('variables')) this.emitGlobalsChanged();
    this.loadAllStylesheets();
  }

  loadAllStylesheets() {
    console.log('Reloading package', this.pack.name);
    this.pack.reloadStylesheets();
  }
};
