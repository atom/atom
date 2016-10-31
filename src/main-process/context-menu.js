/** @babel */

import {Menu} from 'electron'

export default class ContextMenu {
  constructor (template, atomWindow) {
    this.atomWindow = atomWindow
    template = this.createClickHandlers(template)
    const menu = Menu.buildFromTemplate(template)
    menu.popup(this.atomWindow.browserWindow)
  }

  // It's necessary to build the event handlers in this process, otherwise
  // closures are dragged across processes and failed to be garbage collected
  // appropriately.
  createClickHandlers (template) {
    let wiredTemplate = []

    for (let item of template) {
      if (item.command) {
        item.commandDetail = item.commandDetail || {}
        item.commandDetail.contextCommand = true
        item.commandDetail.atomWindow = this.atomWindow
        item.click = () => global.atomApplication.sendCommandToWindow(item.command, @atomWindow, item.commandDetail)
      } else if (item.submenu) {
        this.createClickHandlers(item.submenu)
      }

      wiredTemplate.push(item)
    }

    return wiredTemplate
  }
}
