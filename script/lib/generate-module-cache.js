'use strict';

const fs = require('fs');
const path = require('path');
const ModuleCache = require('../../src/module-cache');

const CONFIG = require('../config');

module.exports = function() {
  console.log(`Generating module cache for ${CONFIG.intermediateAppPath}`);
  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    ModuleCache.create(
      path.join(CONFIG.intermediateAppPath, 'node_modules', packageName)
    );
  }
  ModuleCache.create(CONFIG.intermediateAppPath);
  const newMetadata = JSON.parse(
    fs.readFileSync(path.join(CONFIG.intermediateAppPath, 'package.json'))
  );
  for (let folder of newMetadata._atomModuleCache.folders) {
    if (folder.paths.indexOf('') !== -1) {
      folder.paths = [
        '',
        'exports',
        'spec',
        'src',
        'src/main-process',
        'static',
        'vendor'
      ];
    }
  }
  CONFIG.appMetadata = newMetadata;
  fs.writeFileSync(
    path.join(CONFIG.intermediateAppPath, 'package.json'),
    JSON.stringify(CONFIG.appMetadata)
  );
};
