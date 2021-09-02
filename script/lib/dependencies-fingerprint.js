const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const CONFIG = require('../config');
const FINGERPRINT_PATH = path.join(
  CONFIG.repositoryRootPath,
  'node_modules',
  '.dependencies-fingerprint'
);

module.exports = {
  write: function() {
    const fingerprint = this.compute();
    fs.writeFileSync(FINGERPRINT_PATH, fingerprint);
    console.log(
      'Wrote Dependencies Fingerprint:',
      FINGERPRINT_PATH,
      fingerprint
    );
  },
  read: function() {
    return fs.existsSync(FINGERPRINT_PATH)
      ? fs.readFileSync(FINGERPRINT_PATH, 'utf8')
      : null;
  },
  isOutdated: function() {
    const fingerprint = this.read();
    return fingerprint ? fingerprint !== this.compute() : false;
  },
  compute: function() {
    // Include the electron minor version in the fingerprint since that changing requires a re-install
    const electronVersion = CONFIG.appMetadata.electronVersion.replace(
      /\.\d+$/,
      ''
    );
    const apmVersion = CONFIG.apmMetadata.dependencies['atom-package-manager'];
    const body =
      electronVersion +
      apmVersion +
      process.platform +
      process.version +
      process.arch;
    return crypto
      .createHash('sha1')
      .update(body)
      .digest('hex');
  }
};
