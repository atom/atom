const path = require('path')
const electron = require('electron')

const dirname = path.dirname
path.dirname = function (path) {
  if (typeof path !== 'string') {
    path = '' + path
    const Grim = require('grim')
    Grim.deprecate('Argument to `path.dirname` must be a string')
  }

  return dirname(path)
}

const extname = path.extname
path.extname = function (path) {
  if (typeof path !== 'string') {
    path = '' + path
    const Grim = require('grim')
    Grim.deprecate('Argument to `path.extname` must be a string')
  }

  return extname(path)
}

const basename = path.basename
path.basename = function (path, ext) {
  if (typeof path !== 'string' || (ext !== undefined && typeof ext !== 'string')) {
    path = '' + path
    const Grim = require('grim')
    Grim.deprecate('Arguments to `path.basename` must be strings')
  }

  return basename(path, ext)
}

electron.ipcRenderer.sendChannel = function () {
  const Grim = require('grim')
  Grim.deprecate('Use `ipcRenderer.send` instead of `ipcRenderer.sendChannel`')
  return this.send.apply(this, arguments)
}
