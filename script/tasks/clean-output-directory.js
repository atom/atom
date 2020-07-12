const CONFIG = require('../config');
const {taskify} = require("../lib/task");

module.exports = taskify("Clean ouptut directory", function() {
  const fs = require('fs-extra');

  if (fs.existsSync(CONFIG.buildOutputPath)) {
    this.update(`Cleaning ${CONFIG.buildOutputPath}`);
    fs.removeSync(CONFIG.buildOutputPath);
  } else {
    this.verbose(`${CONFIG.buildOutputPath} doesn't exist`);
  }

  if (fs.existsSync(CONFIG.docsOutputPath)) {
    this.update(`Cleaning ${CONFIG.docsOutputPath}`);
    fs.removeSync(CONFIG.docsOutputPath);
  } else {
    this.verbose(`${CONFIG.docsOutputPath} doesn't exist`);
  }
}, {canFail: true});
