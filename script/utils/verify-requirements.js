// The original source of the python checker can be found at 
// https://github.com/TooTallNate/node-gyp/blob/52e8d9f70d/lib/configure.js

var childProcess = require('child_process')
var fs = require('fs')
var path = require('path')
var extend = require('util')._extend
var which = require('../vendor/which/which')

module.exports = function() {
  verifyNode()
  verifyPython27()
}

function verifyNode() {
  var nodeVersion = process.versions.node.split('.')
  var nodeMajorVersion = +nodeVersion[0]
  var nodeMinorVersion = +nodeVersion[1]
  if (nodeMajorVersion === 0 && nodeMinorVersion < 10) {
    console.warn("You must run script/bootstrap and script/build with node v0.10 or above")
    process.exit(1)
  }
}

function verifyPython27() {
  // Check $PATH before trying other options
  var python = process.env.PYTHON || 'python'
  which(python, function(err, execPath) {
    if (err) {
      return guessPython27()
    }

    if (python === 'python') {
      python = execPath
    }

    checkPythonVersion27(python)
  })
}

// Makes python location guesses if python is not in $PATH
function guessPython27() {
  if (process.platform == 'win32') {
    return guessPythonWin27()
  }

  failNoPython27()
}

// Called on Windows when "python" isn't available in the current $PATH.
// We're gonna check if "%SystemDrive%\python27\python.exe" exists.
function guessPythonWin27() {
  var rootDir = process.env.SystemDrive || 'C:\\'
  if (rootDir[rootDir.length - 1] !== '\\') {
    rootDir += '\\'
  }
  var pythonPath = path.resolve(rootDir, 'Python27', 'python.exe')

  // ensuring that file exists
  fs.stat(pythonPath, function (err, stat) {
    if (err) {
      if (err.code == 'ENOENT') {
        failNoPython27()
      } else {
        console.warn('fs.stat on ' + pythonPath + ' failed: ' + err)
        console.warn('Did you install python correctly?')
        process.exit(1)
      }
      return
    }

    checkPythonVersion27(python)
  })
}

function checkPythonVersion27(python) {
  var env = extend({}, process.env)
  env.TERM = 'dumb'

  childProcess.execFile(python, ['-c', 'import platform; print(platform.python_version());'], { env: env }, function (err, stdout) {
    if (err) {
      console.warn('Could not run python: ' + err)
      console.warn('Did you install python correctly?')
      process.exit(1)
      return
    }

    // Strip off unwanted characters
    var version = stdout.trim()
    version = version.replace(/\+/g, '')
    version = version.replace(/rc(.*)$/ig, '')

    var range = new RegExp('^\w*2.(5|6|7).[0-9]+\w*$')
    if (!range.test(version)) {
      console.warn('Python executable "' + python +
        '" is v' + version + ', which is not supported by gyp (requires python >= v2.5.0 & 3.0.0).\n' +
        'The recommended python version is 2.7.x.')
      process.exit(1)
    }
  })
}

function failNoPython27() {
  console.warn('Can\'t find Python executable, you can set the PYTHON env variable.')
  console.warn('Did you install python2 >= 2.5.0?')
  process.exit(1)
}

