const { Menu } = require('electron');

module.exports = class ContextMenu {
  constructor(template, atomWindow) {
    this.atomWindow = atomWindow;
    this.createClickHandlers(template);
    const menu = Menu.buildFromTemplate(template);
    menu.popup(this.atomWindow.browserWindow, { async: true });
  }

  // It's necessary to build the event handlers in this process, otherwise
  // closures are dragged across processes and failed to be garbage collected
  // appropriately.
  createClickHandlers(template) {
    template.forEach(item => {
      if (item.command) {
        if (!item.commandDetail) item.commandDetail = {};
        item.commandDetail.contextCommand = true;
        item.click = () => {
          global.atomApplication.sendCommandToWindow(
            item.command,
            this.atomWindow,
            item.commandDetail
          );
        };
      } else if (item.submenu) {
        this.createClickHandlers(item.submenu);
      }
    });
  }
};
