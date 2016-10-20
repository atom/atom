/** @babel */

import {Disposable, CompositeDisposable} from 'event-kit'
import path from 'path'

export default class ReopenProjectMenuManager {
  constructor ({menu, commands, history, config, open}) {
    this.menuManager = menu
    this.historyManager = history
    this.config = config
    this.open = open
    this.projects = []

    this.subscriptions = new CompositeDisposable()
    this.subscriptions.add(
      history.onDidChangeProjects(this.update.bind(this)),
      config.onDidChange('core.reopenProjectMenuCount', ({oldValue, newValue}) => {
        this.update()
      }),
      commands.add('atom-workspace', { 'application:reopen-project': this.reopenProjectCommand.bind(this) })
    )
  }

  reopenProjectCommand(e) {
    if (e.detail && e.detail.index)
      this.open(this.projects[e.detail.index].paths)
    else
      this.createReopenProjectListView()
  }

  createReopenProjectListView () {
    if (this.reopenProjectListView == null) {
      const ReopenProjectListView = require('./reopen-project-list-view')
      this.reopenProjectListView = new ReopenProjectListView((paths) => {
        if (paths != null)
          this.open(paths)
      })
    }
    this.reopenProjectListView.toggle()
  }

  update () {
    this.disposeProjectMenu()
    this.projects = this.historyManager.getProjects().slice(0, this.config.get('core.reopenProjectMenuCount'))
    newMenu = ReopenProjectMenuManager.createProjectsMenu(this.projects)
    this.lastProjectMenu = this.menuManager.add([newMenu])
  }

  dispose () {
    this.subscriptions.dispose()
    this.disposeProjectMenu()
    if (this.reopenProjectListView != null)
      this.reopenProjectListView.dispose()
  }

  disposeProjectMenu () {
    if (this.lastProjectMenu) {
      this.lastProjectMenu.dispose()
      this.lastProjectMenu = null
    }
  }

  static createProjectsMenu (projects) {
    return {
      label: 'File',
      submenu: [
        {
          label: 'Reopen Project',
          submenu: projects.map((project, index) => ({
            label: this.createLabel(project),
            command: 'application:reopen-project',
            commandDetail: {index: index}
          }))
        }
      ]
    }
  }

  static createLabel (project) {
    return project.paths.length === 1
      ? project.paths[0]
      : project.paths.map(this.betterBaseName).join(', ')
  }

  static betterBaseName (directory) {
    // Handles Windows roots better than path.basename which returns '' for 'd:' and 'd:\'
    const match = directory.match(/^([a-z]\:)[\\]?$/i)
    return match ? match[1] + '\\' : path.basename(directory)
  }
}
