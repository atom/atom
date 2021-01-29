const { Emitter, CompositeDisposable } = require('event-kit');

// Extended: History manager for remembering which projects have been opened.
//
// An instance of this class is always available as the `atom.history` global.
//
// The project history is used to enable the 'Reopen Project' menu.
class HistoryManager {
  constructor({ project, commands, stateStore }) {
    this.stateStore = stateStore;
    this.emitter = new Emitter();
    this.projects = [];
    this.disposables = new CompositeDisposable();
    this.disposables.add(
      commands.add(
        'atom-workspace',
        { 'application:clear-project-history': this.clearProjects.bind(this) },
        false
      )
    );
    this.disposables.add(
      project.onDidChangePaths(projectPaths => this.addProject(projectPaths))
    );
  }

  destroy() {
    this.disposables.dispose();
  }

  // Public: Obtain a list of previously opened projects.
  //
  // Returns an {Array} of {HistoryProject} objects, most recent first.
  getProjects() {
    return this.projects.map(p => new HistoryProject(p.paths, p.lastOpened));
  }

  // Public: Clear all projects from the history.
  //
  // Note: This is not a privacy function - other traces will still exist,
  // e.g. window state.
  //
  // Return a {Promise} that resolves when the history has been successfully
  // cleared.
  async clearProjects() {
    this.projects = [];
    await this.saveState();
    this.didChangeProjects();
  }

  // Public: Invoke the given callback when the list of projects changes.
  //
  // * `callback` {Function}
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeProjects(callback) {
    return this.emitter.on('did-change-projects', callback);
  }

  didChangeProjects(args = { reloaded: false }) {
    this.emitter.emit('did-change-projects', args);
  }

  async addProject(paths, lastOpened) {
    if (paths.length === 0) return;

    let project = this.getProject(paths);
    if (!project) {
      project = new HistoryProject(paths);
      this.projects.push(project);
    }
    project.lastOpened = lastOpened || new Date();
    this.projects.sort((a, b) => b.lastOpened - a.lastOpened);

    await this.saveState();
    this.didChangeProjects();
  }

  async removeProject(paths) {
    if (paths.length === 0) return;

    let project = this.getProject(paths);
    if (!project) return;

    let index = this.projects.indexOf(project);
    this.projects.splice(index, 1);

    await this.saveState();
    this.didChangeProjects();
  }

  getProject(paths) {
    for (var i = 0; i < this.projects.length; i++) {
      if (arrayEquivalent(paths, this.projects[i].paths)) {
        return this.projects[i];
      }
    }

    return null;
  }

  async loadState() {
    const history = await this.stateStore.load('history-manager');
    if (history && history.projects) {
      this.projects = history.projects
        .filter(p => Array.isArray(p.paths) && p.paths.length > 0)
        .map(p => new HistoryProject(p.paths, new Date(p.lastOpened)));
      this.didChangeProjects({ reloaded: true });
    } else {
      this.projects = [];
    }
  }

  async saveState() {
    const projects = this.projects.map(p => ({
      paths: p.paths,
      lastOpened: p.lastOpened
    }));
    await this.stateStore.save('history-manager', { projects });
  }
}

function arrayEquivalent(a, b) {
  if (a.length !== b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

class HistoryProject {
  constructor(paths, lastOpened) {
    this.paths = paths;
    this.lastOpened = lastOpened || new Date();
  }

  set paths(paths) {
    this._paths = paths;
  }
  get paths() {
    return this._paths;
  }

  set lastOpened(lastOpened) {
    this._lastOpened = lastOpened;
  }
  get lastOpened() {
    return this._lastOpened;
  }
}

module.exports = { HistoryManager, HistoryProject };
