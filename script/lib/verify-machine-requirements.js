'use strict';

const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');

const CONFIG = require('../config');

module.exports = function(ci) {
  verifyNode();
  verifyNpm(ci);
  if (process.platform === 'win32') {
    verifyPython();
  }
};

function verifyNode() {
  const fullVersion = process.versions.node;
  const majorVersion = fullVersion.split('.')[0];
  if (majorVersion >= 6) {
    console.log(`Node:\tv${fullVersion}`);
  } else if (majorVersion >= 4) {
    console.log(`Node:\tv${fullVersion}`);
    console.warn(
      '\tWarning: Building on Node below version 6 is deprecated. Please use Node 6.x+ to build Atom.'
    );
  } else {
    throw new Error(
      `node v4+ is required to build Atom. node v${fullVersion} is installed.`
    );
  }
}

function verifyNpm(ci) {
  const stdout = childProcess.execFileSync(
    CONFIG.getNpmBinPath(ci),
    ['--version'],
    { env: process.env }
  );
  const fullVersion = stdout.toString().trim();
  const majorVersion = fullVersion.split('.')[0];
  const oldestMajorVersionSupported = ci ? 6 : 3;
  if (majorVersion >= oldestMajorVersionSupported) {
    console.log(`Npm:\tv${fullVersion}`);
  } else {
    throw new Error(
      `npm v${oldestMajorVersionSupported}+ is required to build Atom. npm v${fullVersion} was detected.`
    );
  }
}

function verifyPython() {
  const systemDrive = process.env.SystemDrive || 'C:\\';
  let pythonExecutable;
  if (process.env.PYTHON) {
    pythonExecutable = process.env.PYTHON;
  } else {
    const pythonBinPath = path.join(systemDrive, 'Python27', 'python.exe');
    if (fs.existsSync(pythonBinPath)) {
      pythonExecutable = pythonBinPath;
    } else {
      pythonExecutable = 'python';
    }
  }

  let stdout = childProcess.execFileSync(
    pythonExecutable,
    ['-c', 'import platform\nprint(platform.python_version())'],
    { env: process.env }
  );
  if (stdout.indexOf('+') !== -1) stdout = stdout.replace(/\+/g, '');
  if (stdout.indexOf('rc') !== -1) stdout = stdout.replace(/rc(.*)$/gi, '');
  const fullVersion = stdout.toString().trim();
  const versionComponents = fullVersion.split('.');
  const majorVersion = Number(versionComponents[0]);
  const minorVersion = Number(versionComponents[1]);
  if (majorVersion === 2 && minorVersion === 7) {
    console.log(`Python:\tv${fullVersion}`);
  } else {
    throw new Error(
      `Python 2.7 is required to build Atom. ${pythonExecutable} returns version ${fullVersion}.\n` +
        `Set the PYTHON env var to '/path/to/Python27/python.exe' if your python is installed in a non-default location.`
    );
  }
}
