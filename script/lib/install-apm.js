'use strict'

const childProcess = require('child_process')

const CONFIG = require('../config')

module.exports = function (ci) {
  console.log('Installing apm')
  // npm ci leaves apm with a bunch of unmet dependencies
  console.log(childProcess.execFileSync(
    CONFIG.getNpmBinPath(),
    ['--global-style', '--loglevel=silly', 'install'],
    {env: process.env, cwd: CONFIG.apmRootPath}
  ).toString())
}
