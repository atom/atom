'use strict'

const fs = require('fs-extra')
const glob = require('glob')
const minidump = require('minidump')
const path = require('path')

const CONFIG = require('../config')
module.exports = function () {
  console.log(`Dumping symbols in ${CONFIG.symbolsPath}...`)
  const binaryPaths = glob.sync(path.join(CONFIG.intermediateAppPath, 'node_modules', '**', '*.node'))
  return Promise.all(binaryPaths.map(dumpSymbol))
}

function dumpSymbol (binaryPath) {
  return new Promise(function (resolve, reject) {
    minidump.dumpSymbol(binaryPath, function (error, content) {
      if (error) {
        console.error(error)
        throw new Error(error)
      } else {
        const moduleLine = /MODULE [^ ]+ [^ ]+ ([0-9A-F]+) (.*)\n/.exec(content)
        if (moduleLine.length !== 3) {
          const errorMessage = `Invalid output when dumping symbol for ${binaryPath}`
          console.error(errorMessage)
          throw new Error(errorMessage)
        } else {
          const filename = moduleLine[2]
          const symbolDirPath = path.join(CONFIG.symbolsPath, filename, moduleLine[1])
          const symbolFilePath = path.join(symbolDirPath, `${filename}.sym`)
          fs.mkdirpSync(symbolDirPath)
          fs.writeFileSync(symbolFilePath)
          resolve()
        }
      }
    })
  })
}
