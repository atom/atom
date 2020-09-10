'use strict';

const CompileCache = require('../../src/compile-cache');
const fs = require('fs');
const glob = require('glob');
const path = require('path');

const CONFIG = require('../config');

module.exports = function(task) {
  task.start(`Transpiling CSON paths in ${CONFIG.intermediateAppPath}`);

  const paths = getPathsToTranspile();
  if (paths.length === 0) {
    task.warn('No paths to transpile');
  } else {
    task.info(`Transpiling ${paths.length} paths`);
  }

  for (let path of paths) {
    transpileCsonPath(path);
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
          '*.cson'
        ),
        {
          ignore: path.join(
            CONFIG.intermediateAppPath,
            'node_modules',
            packageName,
            'spec',
            '**',
            '*.cson'
          ),
          nodir: true
        }
      )
    );
  }
  return paths;
}

function transpileCsonPath(csonPath) {
  const jsonPath = csonPath.replace(/cson$/g, 'json');
  fs.writeFileSync(
    jsonPath,
    JSON.stringify(
      CompileCache.addPathToCache(csonPath, CONFIG.atomHomeDirPath)
    )
  );
  fs.unlinkSync(csonPath);
}
