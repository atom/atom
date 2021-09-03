const { CompositeDisposable } = require('event-kit');
const path = require('path');

module.exports = class ReopenProjectMenuManager {
  constructor({ menu, commands, history, config, open }) {
    this.menuManager = menu;
    this.historyManager = history;
    this.config = config;
    this.open = open;
    this.projects = [];

    this.subscriptions = new CompositeDisposable();
    this.subscriptions.add(
      history.onDidChangeProjects(this.update.bind(this)),
      config.onDidChange(
        'core.reopenProjectMenuCount',
        ({ oldValue, newValue }) => {
          this.update();
        }
      ),
      commands.add('atom-workspace', {
        'application:reopen-project': this.reopenProjectCommand.bind(this)
      })
    );

    this.applyWindowsJumpListRemovals();
  }

  reopenProjectCommand(e) {
    if (e.detail != null && e.detail.index != null) {
      this.open(this.projects[e.detail.index].paths);
    } else {
      this.createReopenProjectListView();
    }
  }

  createReopenProjectListView() {
    if (this.reopenProjectListView == null) {
      const ReopenProjectListView = require('./reopen-project-list-view');
      this.reopenProjectListView = new ReopenProjectListView(paths => {
        if (paths != null) {
          this.open(paths);
        }
      });
    }
    this.reopenProjectListView.toggle();
  }

  update() {
    this.disposeProjectMenu();
    this.projects = this.historyManager
      .getProjects()
      .slice(0, this.config.get('core.reopenProjectMenuCount'));
    const newMenu = ReopenProjectMenuManager.createProjectsMenu(this.projects);
    this.lastProjectMenu = this.menuManager.add([newMenu]);
    this.updateWindowsJumpList();
  }

  static taskDescription(paths) {
    return paths
      .map(path => `${ReopenProjectMenuManager.betterBaseName(path)} (${path})`)
      .join(' ');
  }

  // Windows users can right-click Atom taskbar and remove project from the jump list.
  // We have to honor that or the group stops working. As we only get a partial list
  // each time we remove them from history entirely.
  async applyWindowsJumpListRemovals() {
    if (process.platform !== 'win32') return;
    if (this.app === undefined) {
      this.app = require('electron').remote.app;
    }

    const removed = this.app
      .getJumpListSettings()
      .removedItems.map(i => i.description);
    if (removed.length === 0) return;
    for (let project of this.historyManager.getProjects()) {
      if (
        removed.includes(
          ReopenProjectMenuManager.taskDescription(project.paths)
        )
      ) {
        await this.historyManager.removeProject(project.paths);
      }
    }
  }

  updateWindowsJumpList() {
    if (process.platform !== 'win32') return;
    if (this.app === undefined) {
      this.app = require('electron').remote.app;
    }

    this.app.setJumpList([
      {
        type: 'custom',
        name: 'Recent Projects',
        items: this.projects.map(project => ({
          type: 'task',
          title: project.paths
            .map(ReopenProjectMenuManager.betterBaseName)
            .join(', '),
          description: ReopenProjectMenuManager.taskDescription(project.paths),
          program: process.execPath,
          args: project.paths.map(path => `"${path}"`).join(' '),
          iconPath: path.join(
            path.dirname(process.execPath),
            'resources',
            'cli',
            'folder.ico'
          ),
          iconIndex: 0
        }))
      },
      { type: 'recent' },
      {
        items: [
          {
            type: 'task',
            title: 'New Window',
            program: process.execPath,
            args: '--new-window',
            description: 'Opens a new Atom window'
          }
        ]
      }
    ]);
  }

  dispose() {
    this.subscriptions.dispose();
    this.disposeProjectMenu();
    if (this.reopenProjectListView != null) {
      this.reopenProjectListView.dispose();
    }
  }

  disposeProjectMenu() {
    if (this.lastProjectMenu) {
      this.lastProjectMenu.dispose();
      this.lastProjectMenu = null;
    }
  }

  static createProjectsMenu(projects) {
    return {
      label: 'File',
      id: 'File',
      submenu: [
        {
          label: 'Reopen Project',
          id: 'Reopen Project',
          submenu: projects.map((project, index) => ({
            label: this.createLabel(project),
            command: 'application:reopen-project',
            commandDetail: { index: index, paths: project.paths }
          }))
        }
      ]
    };
  }

  static createLabel(project) {
    return project.paths.length === 1
      ? project.paths[0]
      : project.paths.map(this.betterBaseName).join(', ');
  }

  static betterBaseName(directory) {
    // Handles Windows roots better than path.basename which returns '' for 'd:' and 'd:\'
    const match = directory.match(/^([a-z]:)[\\]?$/i);
    return match ? match[1] + '\\' : path.basename(directory);
  }
};
