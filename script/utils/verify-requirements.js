var path = require('path');
var fs = require('fs');
var cp = require('child_process');
var execFile = cp.execFile;
var pythonExecutable = process.env.PYTHON;

module.exports = function(cb) {
  verifyNode();
  verifyPython27(cb);
};

function verifyNode() {
  var nodeVersion = process.versions.node.split('.');
  var nodeMajorVersion = +nodeVersion[0];
  var nodeMinorVersion = +nodeVersion[1];
  if (nodeMajorVersion === 0 && nodeMinorVersion < 10) {
    console.warn("node v0.10 is required to build Atom.");
    process.exit(1);
  }
}

function verifyPython27(cb) {
  if (process.platform !== 'win32') {
    cb();
  }
  else {
    if (!pythonExecutable) {
      var systemDrive = process.env.SystemDrive || 'C:\\';
      pythonExecutable = path.join(systemDrive, 'Python27');

      if (fs.existsSync(pythonExecutable)) {
        pythonExecutable = path.join(pythonExecutable, 'python');
      }
      else {
        pythonExecutable = 'python';
      }
    }

    checkPythonVersion(pythonExecutable, cb);
  }
}

function checkPythonVersion (python, cb) {
  var pythonRequiredMessage = "Python 2.7 is required to build Atom. Python 2.7 must be installed at '" + pythonPath + "', or the PYTHON env var must be set to '/path/to/Python27/python.exe', or the Python install directory must be in the path.";

  execFile(python, ['-c', 'import platform; print(platform.python_version());'], { env: process.env }, function (err, stdout) {
    if (err) {
      console.log(pythonRequiredMessage);
      process.exit(1);
    }

    var version = stdout.trim()
    if (~version.indexOf('+')) {
      version = version.replace(/\+/g, '')
    }
    if (~version.indexOf('rc')) {
      version = version.replace(/rc(.*)$/ig, '')
    }

    // Atom requires python 2.7 or better (but not python 3) for node-gyp
    var versionArray = version.split('.').map(function(num) { return +num; });
    var goodPythonVersion = (versionArray[0] === 2 && versionArray[1] >= 7)
    if (!goodPythonVersion) {
      console.log(pythonRequiredMessage);
      process.exit(1);
    }

    // Finally, if we've gotten this far, callback to resume the install process.
    cb();
  });
}
