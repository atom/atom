'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');
const {taskify} = require("../lib/task");

module.exports = taskify("Install apm", function() {
  this.info('Installing apm');
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(),
    ['--global-style', '--loglevel=error', 'install'],
    { env: process.env, cwd: CONFIG.apmRootPath, stdio: "inherit" }
  );

  this.info("Printing apm version info");

  childProcess.execFileSync(
    CONFIG.getApmBinPath(),
    ['--version'],
    {stdio: 'inherit'}
  );
});
