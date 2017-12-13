'use strict'

const fs = require('fs')
const glob = require('glob')
const path = require('path')

const UglifyJS = require('uglify-es')

const CONFIG = require('../config')

module.exports = function () {
  console.log(`Transpiling Uglifyjs paths in ${CONFIG.intermediateAppPath}`)
  for (let path of getPathsToTranspile()) {
    transpileUglifyjsPath(path)
  }
}

function getPathsToTranspile () {
  let paths = []
  paths = paths.concat(glob.sync(path.join(CONFIG.intermediateAppPath, 'benchmarks', '**', '*.js'), {nodir: true}))
  paths = paths.concat(glob.sync(path.join(CONFIG.intermediateAppPath, 'exports', '**', '*.js'), {nodir: true}))
  paths = paths.concat(glob.sync(path.join(CONFIG.intermediateAppPath, 'src', '**', '*.js'), {nodir: true}))

  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    paths = paths.concat(glob.sync(
      path.join(CONFIG.intermediateAppPath, 'node_modules', packageName, '**', '*.js'),
      {ignore: path.join(CONFIG.intermediateAppPath, 'node_modules', packageName, 'spec', '**', '*.js'), nodir: true}
    ))
  }
  return paths
}

function transpileUglifyjsPath (filePath) {
  var sourceCode = fs.readFileSync(filePath, 'utf8')
  var compiledResult = UglifyJS.minify(sourceCode, { mangle: true,
    compress: {
      sequences: true,
      dead_code: true,
      conditionals: true,
      booleans: true,
      unused: true,
      if_return: true,
      join_vars: true,
      drop_console: true
    } })
  if(compiledResult.code){
    fs.writeFileSync(filePath, compiledResult.code)
  }
}
