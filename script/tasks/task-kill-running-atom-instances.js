const childProcess = require('child_process');

const CONFIG = require('../config.js');
const { DefaultTask } = require('../lib/task');

module.exports = function(task = new DefaultTask()) {
  task.start('Kill running Atom instances');

  if (process.platform === 'win32') {
    // Use START as a way to ignore error if Atom.exe isnt running
    childProcess.execSync(`START taskkill /F /IM ${CONFIG.executableName}`);
  } else {
    childProcess.execSync(`pkill -9 ${CONFIG.appMetadata.productName} || true`);
  }

  task.done();
};
