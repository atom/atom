/** @babel */

import { SelectListView } from 'atom-space-pen-views'

export default class ReopenProjectListView extends SelectListView {
  initialize (callback) {
    this.callback = callback
    super.initialize()
    this.addClass('reopen-project')
    this.list.addClass('mark-active')
  }

  getFilterKey () {
    return 'name'
  }

  destroy () {
    this.cancel()
  }

  viewForItem (project) {
    let element = document.createElement('li')
    if (project.name === this.currentProjectName)
      element.classList.add('active')
    element.textContent = project.name
    return element
  }

  cancelled () {
    if (this.panel != null)
      this.panel.destroy()
    this.panel = null
    this.currentProjectName = null
  }

  confirmed (project) {
    this.cancel()
    this.callback(project.value)
  }

  attach () {
    this.storeFocusedElement()
    if (this.panel == null)
      this.panel = atom.workspace.addModalPanel({item: this})
    this.focusFilterEditor()
  }

  toggle() {
    if (this.panel != null) {
      this.cancel()
    }
    else {
      this.currentProjectName = atom.project != null ? this.makeName(atom.project.getPaths()) : null
      this.setItems(atom.history.getProjects().map(p => ({ name: this.makeName(p.paths), value: p.paths })))
      this.attach()
    }
  }

  makeName(paths) {
    return paths.join(', ')
  }
}
