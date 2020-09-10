const fs = require('fs-extra');

const CONFIG = require('../config');
const { DefaultTask } = require('../lib/task');

module.exports = function(task = new DefaultTask()) {
  task.start('Clean output directory');

  if (fs.existsSync(CONFIG.buildOutputPath)) {
    task.log(`Cleaning ${CONFIG.buildOutputPath}`);
    fs.removeSync(CONFIG.buildOutputPath);
  } else {
    task.verbose('No output directory');
  }

  task.done();
};
