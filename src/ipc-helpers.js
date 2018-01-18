const Disposable = require('event-kit').Disposable
let ipcRenderer = null
let ipcMain = null
let BrowserWindow = null

exports.on = function (emitter, eventName, callback) {
  emitter.on(eventName, callback)
  return new Disposable(() => emitter.removeListener(eventName, callback))
}

exports.call = function (channel, ...args) {
  if (!ipcRenderer) {
    ipcRenderer = require('electron').ipcRenderer
    ipcRenderer.setMaxListeners(20)
  }

  const responseChannel = getResponseChannel(channel)

  return new Promise(resolve => {
    ipcRenderer.on(responseChannel, (event, result) => {
      ipcRenderer.removeAllListeners(responseChannel)
      resolve(result)
    })

    ipcRenderer.send(channel, ...args)
  })
}

exports.respondTo = function (channel, callback) {
  if (!ipcMain) {
    const electron = require('electron')
    ipcMain = electron.ipcMain
    BrowserWindow = electron.BrowserWindow
  }

  const responseChannel = getResponseChannel(channel)

  return exports.on(ipcMain, channel, async (event, ...args) => {
    const browserWindow = BrowserWindow.fromWebContents(event.sender)
    const result = await callback(browserWindow, ...args)
    event.sender.send(responseChannel, result)
  })
}

function getResponseChannel (channel) {
  return 'ipc-helpers-' + channel + '-response'
}
