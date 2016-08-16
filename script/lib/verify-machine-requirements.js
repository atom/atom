'use strict'

const childProcess = require('child_process')
const fs = require('fs')
const path = require('path')

const CONFIG = require('../config')

module.exports = function () {
  verifyNode()
  verifyNpm()
  if (process.platform === 'win32') {
    verifyPython()
  }
}

function verifyNode () {
  const fullVersion = process.versions.node
  const majorVersion = fullVersion.split('.')[0]
  if (majorVersion >= 4) {
    console.log(`Node:\tv${fullVersion}`)
  } else {
    throw new Error(`node v4+ is required to build Atom. node v${fullVersion} is installed.`)
  }
}

function verifyNpm () {
  const stdout = childProcess.execFileSync(CONFIG.npmBinPath, ['--version'], {env: process.env})
  const fullVersion = stdout.toString().trim()
  const majorVersion = fullVersion.split('.')[0]
  if (majorVersion >= 3) {
    console.log(`Npm:\tv${fullVersion}`)
  } else {
    throw new Error(`npm v3+ is required to build Atom. npm v${fullVersion} was detected.`)
  }
}

function verifyPython () {
  const systemDrive = process.env.SystemDrive || 'C:\\'
  let pythonExecutable
  if (process.env.PYTHON) {
    pythonExecutable = process.env.PYTHON
  } else {
    const pythonBinPath = path.join(systemDrive, 'Python27', 'python.exe')
    if (fs.existsSync(pythonBinPath)) {
      pythonExecutable = pythonBinPath
    } else {
      pythonExecutable = 'python'
    }
  }

  const stdout = childProcess.execFileSync(pythonExecutable, ['-c', 'import platform\nprint(platform.python_version())'], {env: process.env})
  if (stdout.indexOf('+') !== -1) stdout = stdout.replace(/\+/g, '')
  if (stdout.indexOf('rc') !== -1) stdout = stdout.replace(/rc(.*)$/ig, '')
  const fullVersion = stdout.toString().trim()
  const versionComponents = fullVersion.split('.')
  const majorVersion = Number(versionComponents[0])
  const minorVersion = Number(versionComponents[1])
  if (majorVersion === 2 && minorVersion === 7) {
    console.log(`Python:\tv${fullVersion}`)
  } else {
    throw new Error(
      `Python 2.7 is required to build Atom. ${pythonExecutable} returns version ${fullVersion}.\n` +
      `Set the PYTHON env var to '/path/to/Python27/python.exe' if your python is installed in a non-default location.`
    )
  }
}
