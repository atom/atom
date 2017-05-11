'use strict'

const CompileCache = require('../../src/compile-cache')
const fs = require('fs')
const glob = require('glob')
const path = require('path')

const CONFIG = require('../config')

module.exports = function () {
  console.log(`Transpiling packages with custom transpiler configurations in ${CONFIG.intermediateAppPath}`)
  let pathsToCompile = []
  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    const packagePath = path.join(CONFIG.intermediateAppPath, 'node_modules', packageName)
    const metadataPath = path.join(packagePath, 'package.json')
    const metadata = require(metadataPath)
    if (metadata.atomTranspilers) {
      CompileCache.addTranspilerConfigForPath(packagePath, metadata.name, metadata, metadata.atomTranspilers)
      for (let config of metadata.atomTranspilers) {
        pathsToCompile = pathsToCompile.concat(glob.sync(path.join(packagePath, config.glob), {nodir: true}))
      }
    }
  }

  for (let path of pathsToCompile) {
    transpilePath(path)
  }
}

function transpilePath (path) {
  fs.writeFileSync(path, CompileCache.addPathToCache(path, CONFIG.atomHomeDirPath))
}
