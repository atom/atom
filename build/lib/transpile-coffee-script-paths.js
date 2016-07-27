'use strict'

const coffee = require('coffee-script')
const fs = require('fs')
const glob = require('glob')
const path = require('path')

const CONFIG = require('../config')

module.exports = function () {
  console.log('Transpiling CoffeeScript paths...');
  for (let path of getPathsToTranspile()) {
    transpileCoffeeScriptPath(path)
  }
}

function getPathsToTranspile () {
  let paths = []
  paths = paths.concat(glob.sync(path.join(CONFIG.electronAppPath, 'src', '**', '*.coffee')))
  paths = paths.concat(glob.sync(path.join(CONFIG.electronAppPath, 'spec', '*.coffee')))
  paths = paths.concat(glob.sync(path.join(CONFIG.electronAppPath, 'exports', '**', '*.coffee')))
  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    paths = paths.concat(glob.sync(
      path.join(CONFIG.electronAppPath, 'node_modules', packageName, '**', '*.coffee'),
      {ignore: path.join(CONFIG.electronAppPath, 'node_modules', packageName, 'spec', '**', '*.coffee')}
    ))
  }
  return paths
}

function transpileCoffeeScriptPath (coffeePath) {
  const inputCode = fs.readFileSync(coffeePath, 'utf8')
  const jsPath = coffeePath.replace(/coffee$/g, 'js')
  fs.writeFileSync(jsPath, coffee.compile(inputCode))
  fs.unlinkSync(coffeePath)
}
