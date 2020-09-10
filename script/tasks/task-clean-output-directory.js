const fs = require('fs-extra');
const CONFIG = require('../config');

module.exports = function (task) {
  task.start('Clean output directory');

  if (fs.existsSync(CONFIG.buildOutputPath)) {
    task.log(`Cleaning ${CONFIG.buildOutputPath}`);
    fs.removeSync(CONFIG.buildOutputPath);
  } else {
    task.verbose('No output directory');
  }

  task.done();
};
