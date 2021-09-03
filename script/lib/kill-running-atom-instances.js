const childProcess = require('child_process');

const CONFIG = require('../config.js');

module.exports = function() {
  if (process.platform === 'win32') {
    // Use START as a way to ignore error if Atom.exe isnt running
    childProcess.execSync(`START taskkill /F /IM ${CONFIG.executableName}`);
  } else {
    childProcess.execSync(`pkill -9 ${CONFIG.appMetadata.productName} || true`);
  }
};
