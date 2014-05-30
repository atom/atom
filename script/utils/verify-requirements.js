var path = require('path');
var fs = require('fs');

module.exports = function() {
  verifyNode();
  verifyPython27();
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

function verifyPython27() {
  if (process.platform == 'win32') {
    var pythonPath = process.env.PYTHON;
    if (!pythonPath) {
      var systemDrive = process.env.SystemDrive || 'C:\\';
      pythonPath = path.join(systemDrive, 'Python27');
    }

    if (!fs.existsSync(pythonPath)) {
      console.warn("Python 2.7 is required to build Atom. Python 2.7 must be installed at '" + pythonPath + "' or the PYTHON env var must be set to '/path/to/Python27/python.exe'");
      process.exit(1);
    }
  }
}
