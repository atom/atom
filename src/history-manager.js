/** @babel */

import {Emitter} from 'event-kit'

// Extended: History manager for remembering which projects have been opened.
//
// An instance of this class is always available as the `atom.history` global.
//
// The project history is used to enable the 'Reopen Project' menu.
export class HistoryManager {
  constructor ({project, commands, localStorage}) {
    this.localStorage = localStorage
    commands.add('atom-workspace', {'application:clear-project-history': this.clearProjects.bind(this)})
    this.emitter = new Emitter()
    this.loadState()
    project.onDidChangePaths((projectPaths) => this.addProject(projectPaths))
  }

  // Public: Obtain a list of previously opened projects.
  //
  // Returns an {Array} of {HistoryProject} objects, most recent first.
  getProjects () {
    return this.projects.map(p => new HistoryProject(p.paths, p.lastOpened))
  }

  // Public: Clear all projects from the history.
  //
  // Note: This is not a privacy function - other traces will still exist,
  // e.g. window state.
  clearProjects () {
    this.projects = []
    this.saveState()
    this.didChangeProjects()
  }

  // Public: Invoke the given callback when the list of projects changes.
  //
  // * `callback` {Function}
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeProjects (callback) {
    return this.emitter.on('did-change-projects', callback)
  }

  didChangeProjects (args) {
    this.emitter.emit('did-change-projects', args || { reloaded: false })
  }

  addProject (paths, lastOpened) {
    if (paths.length == 0) return

    let project = this.getProject(paths)
    if (!project) {
      project = new HistoryProject(paths)
      this.projects.push(project)
    }
    project.lastOpened = lastOpened || new Date()
    this.projects.sort((a, b) => b.lastOpened - a.lastOpened)

    this.saveState()
    this.didChangeProjects()
  }

  getProject (paths) {
    const pathsString = paths.toString()
    for (var i = 0; i < this.projects.length; i++) {
      if (this.projects[i].paths.toString() === pathsString) {
        return this.projects[i]
      }
    }

    return null
  }

  loadState () {
    const state = JSON.parse(this.localStorage.getItem('history'))
    if (state && state.projects) {
      this.projects = state.projects.filter(p => Array.isArray(p.paths) && p.paths.length > 0).map(p => new HistoryProject(p.paths, new Date(p.lastOpened)))
      this.didChangeProjects({ reloaded: true })
    } else {
      this.projects = []
    }
  }

  saveState () {
    const state = JSON.stringify({
      projects: this.projects.map(p => ({
        paths: p.paths, lastOpened: p.lastOpened
      }))
    })
    this.localStorage.setItem('history', state)
  }

  async importProjectHistory () {
    for (let project of await HistoryImporter.getAllProjects()) {
      this.addProject(project.paths, project.lastOpened)
    }
    this.saveState()
    this.didChangeProjects()
  }
}

export class HistoryProject {
  constructor (paths, lastOpened) {
    this.paths = paths
    this.lastOpened = lastOpened || new Date()
  }

  set paths (paths) { this._paths = paths }
  get paths () { return this._paths }

  set lastOpened (lastOpened) { this._lastOpened = lastOpened }
  get lastOpened () { return this._lastOpened }
}

class HistoryImporter {
  static async getStateStoreCursor () {
    const db = await atom.stateStore.dbPromise
    const store = db.transaction(['states']).objectStore('states')
    return store.openCursor()
  }

  static async getAllProjects (stateStore) {
    const request = await HistoryImporter.getStateStoreCursor()
    return new Promise((resolve, reject) => {
      const rows = []
      request.onerror = reject
      request.onsuccess = event => {
        const cursor = event.target.result
        if (cursor) {
          let project = cursor.value.value.project
          let storedAt = cursor.value.storedAt
          if (project && project.paths && storedAt) {
            rows.push(new HistoryProject(project.paths, new Date(Date.parse(storedAt))))
          }
          cursor.continue()
        } else {
          resolve(rows)
        }
      }
    })
  }
}
