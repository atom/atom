'use strict'

const Disposable = require('event-kit').Disposable
let ipcRenderer = null
let ipcMain = null
let BrowserWindow = null

exports.on = function (emitter, eventName, callback) {
  emitter.on(eventName, callback)
  return new Disposable(function () {
    emitter.removeListener(eventName, callback)
  })
}

exports.call = function (channel, ...args) {
  if (!ipcRenderer) {
    ipcRenderer = require('electron').ipcRenderer
    ipcRenderer.setMaxListeners(20)
  }

  var responseChannel = getResponseChannel(channel)

  return new Promise(function (resolve) {
    ipcRenderer.on(responseChannel, function (event, result) {
      ipcRenderer.removeAllListeners(responseChannel)
      resolve(result)
    })

    ipcRenderer.send(channel, ...args)
  })
}

exports.respondTo = function (channel, callback) {
  if (!ipcMain) {
    var electron = require('electron')
    ipcMain = electron.ipcMain
    BrowserWindow = electron.BrowserWindow
  }

  var responseChannel = getResponseChannel(channel)

  return exports.on(ipcMain, channel, function (event, ...args) {
    var browserWindow = BrowserWindow.fromWebContents(event.sender)
    var result = callback(browserWindow, ...args)
    event.sender.send(responseChannel, result)
  })
}

function getResponseChannel (channel) {
  return 'ipc-helpers-' + channel + '-response'
}
