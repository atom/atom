'use strict';

const CompileCache = require('../../src/compile-cache');
const fs = require('fs');
const glob = require('glob');
const path = require('path');

const CONFIG = require('../config');

module.exports = function(task) {
  task.start(`Transpiling Babel paths in ${CONFIG.intermediateAppPath}`);

  const paths = getPathsToTranspile();

  if (path.length === 0) {
    task.warn('No paths to transpile');
  } else {
    task.info(`Transpiling ${paths.length} paths`);
  }

  for (let path of paths) {
    transpileBabelPath(path);
  }

  task.done();
};

function getPathsToTranspile() {
  let paths = [];
  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    paths = paths.concat(
      glob.sync(
        path.join(
          CONFIG.intermediateAppPath,
          'node_modules',
          packageName,
          '**',
          '*.js'
        ),
        {
          ignore: path.join(
            CONFIG.intermediateAppPath,
            'node_modules',
            packageName,
            'spec',
            '**',
            '*.js'
          ),
          nodir: true
        }
      )
    );
  }
  return paths;
}

function transpileBabelPath(path) {
  fs.writeFileSync(
    path,
    CompileCache.addPathToCache(path, CONFIG.atomHomeDirPath)
  );
}
