'use babel'

import { protocol } from 'electron'
import fs from 'fs'
import path from 'path'

// Handles requests with 'atom' protocol.
//
// It's created by {AtomApplication} upon instantiation and is used to create a
// custom resource loader for 'atom://' URLs.
//
// The following directories are searched in order:
//   * ~/.atom/assets
//   * ~/.atom/dev/packages (unless in safe mode)
//   * ~/.atom/packages
//   * RESOURCE_PATH/node_modules
//
export default class AtomProtocolHandler {
  constructor (resourcePath, safeMode) {
    this.loadPaths = []

    if (!safeMode) {
      this.loadPaths.push(path.join(process.env.ATOM_HOME, 'dev', 'packages'))
    }

    this.loadPaths.push(path.join(process.env.ATOM_HOME, 'packages'))
    this.loadPaths.push(path.join(resourcePath, 'node_modules'))

    this.registerAtomProtocol()
  }

  // Creates the 'atom' custom protocol handler.
  registerAtomProtocol () {
    return protocol.registerFileProtocol('atom', (request, callback) => {
      let filePath
      let relativePath = path.normalize(request.url.substr(7))

      if (relativePath.indexOf('assets/') === 0) {
        let assetsPath = path.join(process.env.ATOM_HOME, relativePath)
        if (__guardMethod__(fs.statSyncNoException(assetsPath), 'isFile', o => o.isFile())) { filePath = assetsPath }
      }

      if (!filePath) {
        for (let loadPath of Array.from(this.loadPaths)) {
          filePath = path.join(loadPath, relativePath)
          if (__guardMethod__(fs.statSyncNoException(filePath), 'isFile', o1 => o1.isFile())) { break }
        }
      }

      return callback(filePath)
    })
  }
}

function __guardMethod__ (obj, methodName, transform) {
  if (typeof obj !== 'undefined' && obj !== null && typeof obj[methodName] === 'function') {
    return transform(obj, methodName)
  } else {
    return undefined
  }
}
