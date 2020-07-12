'use strict';

const CONFIG = require('../config');
const {taskify} = require("../lib/task");

module.exports = taskify("Clean caches", function() {
  const fs = require('fs-extra');
  const os = require('os');
  const path = require('path');

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
    this.update(`Cleaning ${path}`);
    fs.removeSync(path);
  }
}, {canFail: true});
