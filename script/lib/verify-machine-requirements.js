'use strict';

const childProcess = require('child_process');
const path = require('path');

module.exports = function(ci) {
  verifyNode();
  verifyPython();
};

function verifyNode() {
  const fullVersion = process.versions.node;
  const majorVersion = fullVersion.split('.')[0];
  const minorVersion = fullVersion.split('.')[1];
  if (majorVersion >= 11 || (majorVersion === '10' && minorVersion >= 12)) {
    console.log(`Node:\tv${fullVersion}`);
  } else {
    throw new Error(
      `node v10.12+ is required to build Atom. node v${fullVersion} is installed.`
    );
  }
}

function verifyPython() {
  // This function essentially re-implements node-gyp's "find-python.js" library,
  // but in a synchronous, bootstrap-script-friendly way.
  // It is based off of the logic of the file from node-gyp v5.x:
  // https://github.com/nodejs/node-gyp/blob/v5.1.1/lib/find-python.js
  // This node-gyp is the version in use by current npm (in mid 2020).
  //
  // TODO: If this repo ships a newer version of node-gyp (v6.x or later), please update this script.
  // (Currently, the build scripts and apm each depend on npm v6.14, which depends on node-gyp v5.)
  // Differences between major versions of node-gyp:
  // node-gyp 5.x looks for python, then python2, then python3.
  // node-gyp 6.x looks for python3, then python, then python2.)
  // node-gyp 5.x accepts Python ^2.6 || >= 3.5, node-gyp 6+ only accepts Python == 2.7 || >= 3.5.
  // node-gyp 7.x stopped using the "-2" flag for "py.exe",
  // so as to allow finding Python 3 as well, not just Python 2.
  // https://github.com/nodejs/node-gyp/blob/master/CHANGELOG.md#v700-2020-06-03

  let stdout;
  let fullVersion;
  let usablePythonWasFound;
  let triedLog = '';
  let binaryPlusFlag;

  function verifyBinary(binary, prependFlag) {
    if (binary && !usablePythonWasFound) {
      // clear re-used "result" variables now that we're checking another python binary.
      stdout = '';
      fullVersion = '';

      let allFlags = [
        '-c',
        'import platform\nprint(platform.python_version())'
      ];
      if (prependFlag) {
        // prependFlag is an optional argument,
        // used to prepend "-2" for the "py.exe" launcher.
        //
        // TODO: Refactor this script by eliminating "prependFlag"
        // once we update to node-gyp v7.x or newer;
        // the "-2" flag is not used in node-gyp v7.x.
        allFlags.unshift(prependFlag);
      }

      try {
        stdout = childProcess.execFileSync(binary, allFlags, {
          env: process.env,
          stdio: ['ignore', 'pipe', 'ignore']
        });
      } catch (e) {}

      if (stdout) {
        if (stdout.indexOf('+') !== -1)
          stdout = stdout.toString().replace(/\+/g, '');
        if (stdout.indexOf('rc') !== -1)
          stdout = stdout.toString().replace(/rc(.*)$/gi, '');
        fullVersion = stdout.toString().trim();
      }

      if (fullVersion) {
        let versionComponents = fullVersion.split('.');
        let majorVersion = Number(versionComponents[0]);
        let minorVersion = Number(versionComponents[1]);
        if (
          (majorVersion === 2 && minorVersion >= 6) ||
          (majorVersion === 3 && minorVersion >= 5)
        ) {
          usablePythonWasFound = true;
        }
      }

      // Prepare to log which commands were tried, and the results, in case no usable Python can be found.
      if (prependFlag) {
        binaryPlusFlag = binary + ' ' + prependFlag;
      } else {
        binaryPlusFlag = binary;
      }
      triedLog = triedLog.concat(
        `log message: tried to check version of "${binaryPlusFlag}", got: "${fullVersion}"\n`
      );
    }
  }

  function verifyForcedBinary(binary) {
    if (typeof binary !== 'undefined' && binary.length > 0) {
      verifyBinary(binary);
      if (!usablePythonWasFound) {
        throw new Error(
          `NODE_GYP_FORCE_PYTHON is set to: "${binary}", but this is not a valid Python.\n` +
            'Please set NODE_GYP_FORCE_PYTHON to something valid, or unset it entirely.\n' +
            '(Python 2.6, 2.7 or 3.5+ is required to build Atom.)\n'
        );
      }
    }
  }

  // These first two checks do nothing if the relevant
  // environment variables aren't set.
  verifyForcedBinary(process.env.NODE_GYP_FORCE_PYTHON);
  // All the following checks will no-op if a previous check has succeeded.
  verifyBinary(process.env.PYTHON);
  verifyBinary('python');
  verifyBinary('python2');
  verifyBinary('python3');
  if (process.platform === 'win32') {
    verifyBinary('py.exe', '-2');
    verifyBinary(
      path.join(process.env.SystemDrive || 'C:', 'Python27', 'python.exe')
    );
    verifyBinary(
      path.join(process.env.SystemDrive || 'C:', 'Python37', 'python.exe')
    );
  }

  if (usablePythonWasFound) {
    console.log(`Python:\tv${fullVersion}`);
  } else {
    throw new Error(
      `\n${triedLog}\n` +
        'Python 2.6, 2.7 or 3.5+ is required to build Atom.\n' +
        'verify-machine-requirements.js was unable to find such a version of Python.\n' +
        "Set the PYTHON env var to e.g. 'C:/path/to/Python27/python.exe'\n" +
        'if your Python is installed in a non-default location.\n'
    );
  }
}
