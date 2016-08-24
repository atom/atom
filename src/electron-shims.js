const electron = require('electron')

electron.ipcRenderer.sendChannel = function () {
  const Grim = require('grim')
  Grim.deprecate('Use `ipcRenderer.send` instead of `ipcRenderer.sendChannel`')
  return this.send.apply(this, arguments)
}
