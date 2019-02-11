// This module exports a function that copies all the static assets into the
// appropriate location in the build output directory.

'use strict'

const path = require('path')
const fs = require('fs-extra')
const CONFIG = require('../config')
const glob = require('glob')
const includePathInPackagedApp = require('./include-path-in-packaged-app')

module.exports = async function () {
  console.log(`Copying assets to ${CONFIG.intermediateAppPath}`)
  let srcPaths = [
    path.join(CONFIG.repositoryRootPath, 'benchmarks', 'benchmark-runner.js'),
    path.join(CONFIG.repositoryRootPath, 'dot-atom'),
    path.join(CONFIG.repositoryRootPath, 'exports'),
    path.join(CONFIG.repositoryRootPath, 'package.json'),
    path.join(CONFIG.repositoryRootPath, 'static'),
    path.join(CONFIG.repositoryRootPath, 'src/main-process'),
  ]

  await Promise.all(
    srcPaths.map(srcPath => fs.copy(srcPath, computeDestinationPath(srcPath), {filter: includePathInPackagedApp}))
  )

  // Run a copy pass to dereference symlinked directories under node_modules.
  // We do this to ensure that symlinked repo-local bundled packages get
  // copied to the output folder correctly.  We dereference only the top-level
  // symlinks and not nested symlinks to avoid issues where symlinked binaries
  // are duplicated in Atom's installation packages (see atom/atom#18490).
  // const nodeModulesPath = path.join(CONFIG.repositoryRootPath, 'node_modules')
  // await Promise.all(
  //   glob.sync(path.join(nodeModulesPath, '*')).map(async p => {
  //     const stat = await fs.lstat(p)
  //     const modulePath = stat.isSymbolicLink() ? path.resolve(nodeModulesPath, await fs.readlink(p)) : p
  //     const destPath = path.join(CONFIG.intermediateAppPath, 'node_modules', path.basename(modulePath))
  //     await fs.copy(modulePath, destPath, { filter: includePathInPackagedApp })
  //   })
  // )

  await fs.copy(
    path.join(CONFIG.repositoryRootPath, 'resources', 'app-icons', CONFIG.channel, 'png', '1024.png'),
    path.join(CONFIG.intermediateAppPath, 'resources', 'atom.png')
  )
}

function computeDestinationPath (srcPath) {
  const relativePath = path.relative(CONFIG.repositoryRootPath, srcPath)
  return path.join(CONFIG.intermediateAppPath, relativePath)
}
