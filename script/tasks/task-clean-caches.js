'use strict';

const fs = require('fs-extra');
const os = require('os');
const path = require('path');

const CONFIG = require('../config');
const { DefaultTask } = require('../lib/task');

module.exports = function(task = new DefaultTask()) {
  task.start('Clean caches');

  const cachePaths = [
    path.join(CONFIG.repositoryRootPath, 'electron'),
    path.join(CONFIG.atomHomeDirPath, '.node-gyp'),
    path.join(CONFIG.atomHomeDirPath, 'storage'),
    path.join(CONFIG.atomHomeDirPath, '.apm'),
    path.join(CONFIG.atomHomeDirPath, '.npm'),
    path.join(CONFIG.atomHomeDirPath, 'compile-cache'),
    path.join(CONFIG.atomHomeDirPath, 'snapshot-cache'),
    path.join(CONFIG.atomHomeDirPath, 'atom-shell'),
    path.join(CONFIG.atomHomeDirPath, 'electron'),
    path.join(os.tmpdir(), 'atom-build'),
    path.join(os.tmpdir(), 'atom-cached-atom-shells')
  ];

  for (let path of cachePaths) {
    task.log(`Cleaning ${path}`);
    fs.removeSync(path);
  }

  task.done();
};
