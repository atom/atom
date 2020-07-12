'use strict';

const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');

const CONFIG = require('../config');

const {Task} = require("../lib/task");

class VerifyMachineRequirements extends Task {
  constructor() {
    super("Verify machine requirements");
  }

  run() {
    this.verifyNode();
    this.verifyNpm(CONFIG.ci);
    this.verifyPython();
  }

  verifyNode() {
    const fullVersion = process.versions.node;
    const majorVersion = fullVersion.split('.')[0];

    this.info(`node:\tv${fullVersion}`);

    if (majorVersion < 4) {
      throw new Error(
        `node v4+ is required to build Atom`
      );
    } else if (majorVersion < 6) {
      this.warn(
        'Building on Node below version 6 is deprecated. Please use Node 6.x+ to build Atom.'
      );
    }
  }

  verifyNpm(ci) {
    const stdout = childProcess.execFileSync(
      CONFIG.getNpmBinPath(ci),
      ['--version'],
      { env: process.env }
    );
    const fullVersion = stdout.toString().trim();
    const majorVersion = fullVersion.split('.')[0];
    const oldestMajorVersionSupported = ci ? 6 : 3;

    this.info(`npm:\tv${fullVersion}`);

    if (majorVersion < oldestMajorVersionSupported) {
      throw new Error(
        `npm v${oldestMajorVersionSupported}+ is required to build Atom`
      );
    }
  }

  verifyPython() {
    let pythonExecutable;

    if (process.env.PYTHON) {
      this.verbose("python source set in PYTHON env variable");
      pythonExecutable = process.env.PYTHON;
    } else if (process.platform === "win32") {
      const systemDrive = process.env.SystemDrive || 'C:\\';
      const pythonBinPath = path.join(systemDrive, 'Python27', 'python.exe');
      if (fs.existsSync(pythonBinPath)) {
        pythonExecutable = pythonBinPath;
      }
    }

    if (!pythonExecutable) {
       pythonExecutable = 'python';
    }

    let stdout = childProcess.execFileSync(
      pythonExecutable,
      ['-c', 'import platform\nprint(platform.python_version())'],
      { env: process.env }
    );

    if (stdout.indexOf('+') !== -1) { stdout = stdout.replace(/\+/g, ''); }
    if (stdout.indexOf('rc') !== -1) { stdout = stdout.replace(/rc(.*)$/gi, ''); }

    const fullVersion = stdout.toString().trim();
    const versionComponents = fullVersion.split('.');
    const majorVersion = Number(versionComponents[0]);
    const minorVersion = Number(versionComponents[1]);

    this.info(`python:\tv${fullVersion}`);

    if (majorVersion < 2 || (majorVersion === 2 && minorVersion < 7)) {
      this.warn(
        `Python 2.7 or greater is probably required to build Atom, detected ${majorVersion}.${minorVersion}`
      );
      if (process.platform === "win32") {
        this.warn(
          `Set the PYTHON env var to '/path/to/Python27/python.exe' if your python is installed in a non-default location.`
        );
      }
    }
  }
}

module.exports = new VerifyMachineRequirements();
