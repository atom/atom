'use strict'

const spawnSync = require('./spawn-sync')
const path = require('path')

const CONFIG = require('../config')

module.exports = function () {
  console.log('Installing script dependencies')
  childProcess.execFileSync(
    CONFIG.npmBinPath,
    ['--loglevel=error', 'install'],
    {env: process.env, cwd: CONFIG.scriptRootPath}
  )
}
