'use babel'

import { Menu } from 'electron'

export default class ContextMenu {
  constructor (template, atomWindow) {
    this.atomWindow = atomWindow
    template = this.createClickHandlers(template)
    let menu = Menu.buildFromTemplate(template)
    menu.popup(this.atomWindow.browserWindow)
  }

  // It's necessary to build the event handlers in this process, otherwise
  // closures are dragged across processes and failed to be garbage collected
  // appropriately.
  createClickHandlers (template) {
    return (() => {
      let result = []
      for (let item of Array.from(template)) {
        if (item.command) {
          if (item.commandDetail == null) { item.commandDetail = {} }
          item.commandDetail.contextCommand = true
          item.commandDetail.atomWindow = this.atomWindow;
          (item => {
            item.click = () => {
              return global.atomApplication.sendCommandToWindow(item.command, this.atomWindow, item.commandDetail)
            }
          })(item)
        } else if (item.submenu) {
          this.createClickHandlers(item.submenu)
        }
        result.push(item)
      }
      return result
    })()
  }
}
