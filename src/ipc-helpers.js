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

exports.call = function (methodName, ...args) {
  if (!ipcRenderer) {
    ipcRenderer = require('electron').ipcRenderer
  }

  var responseChannel = getResponseChannel(methodName)

  return new Promise(function (resolve) {
    ipcRenderer.on(responseChannel, function (event, result) {
      ipcRenderer.removeAllListeners(responseChannel)
      resolve(result)
    })

    ipcRenderer.send(methodName, ...args)
  })
}

exports.respondTo = function (methodName, callback) {
  if (!ipcMain) {
    var electron = require('electron')
    ipcMain = electron.ipcMain
    BrowserWindow = electron.BrowserWindow
  }

  var responseChannel = getResponseChannel(methodName)

  return exports.on(ipcMain, methodName, function (event, ...args) {
    var browserWindow = BrowserWindow.fromWebContents(event.sender)
    var result = callback(browserWindow, ...args)
    event.sender.send(responseChannel, result)
  })
}

function getResponseChannel (methodName) {
  return 'ipc-helpers-' + methodName + '-response'
}
