"use strict";

const childProcess = require('child_process');

const CONFIG = require('../config');
const {taskify} = require("../lib/task")

process.env.ELECTRON_CUSTOM_VERSION = CONFIG.appMetadata.electronVersion;

module.exports = taskify("Install script dependencies", function() {
  const ci = CONFIG.ci;
  this.info(`Installing script dependencies (ci=${ci})`);
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(ci),
    ['--loglevel=error', ci ? 'ci' : 'install'],
    { env: process.env, cwd: CONFIG.scriptRootPath, stdio: "inherit" }
  );
});
