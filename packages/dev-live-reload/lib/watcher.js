const { CompositeDisposable, File, Directory, Emitter } = require('atom');
const path = require('path');

module.exports = class Watcher {
  constructor() {
    this.destroy = this.destroy.bind(this);
    this.emitter = new Emitter();
    this.disposables = new CompositeDisposable();
    this.entities = []; // Used for specs
  }

  onDidDestroy(callback) {
    this.emitter.on('did-destroy', callback);
  }

  onDidChangeGlobals(callback) {
    this.emitter.on('did-change-globals', callback);
  }

  destroy() {
    this.disposables.dispose();
    this.entities = null;
    this.emitter.emit('did-destroy');
    this.emitter.dispose();
  }

  watch() {
    // override me
  }

  loadStylesheet(stylesheetPath) {
    // override me
  }

  loadAllStylesheets() {
    // override me
  }

  emitGlobalsChanged() {
    this.emitter.emit('did-change-globals');
  }

  watchDirectory(directoryPath) {
    if (this.isInAsarArchive(directoryPath)) return;
    const entity = new Directory(directoryPath);
    this.disposables.add(entity.onDidChange(() => this.loadAllStylesheets()));
    this.entities.push(entity);
  }

  watchGlobalFile(filePath) {
    const entity = new File(filePath);
    this.disposables.add(entity.onDidChange(() => this.emitGlobalsChanged()));
    this.entities.push(entity);
  }

  watchFile(filePath) {
    if (this.isInAsarArchive(filePath)) return;
    const reloadFn = () => this.loadStylesheet(entity.getPath());

    const entity = new File(filePath);
    this.disposables.add(entity.onDidChange(reloadFn));
    this.disposables.add(entity.onDidDelete(reloadFn));
    this.disposables.add(entity.onDidRename(reloadFn));
    this.entities.push(entity);
  }

  isInAsarArchive(pathToCheck) {
    const { resourcePath } = atom.getLoadSettings();
    return (
      pathToCheck.startsWith(`${resourcePath}${path.sep}`) &&
      path.extname(resourcePath) === '.asar'
    );
  }
};
