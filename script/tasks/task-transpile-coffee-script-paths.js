'use strict';

const CompileCache = require('../../src/compile-cache');
const fs = require('fs');
const glob = require('glob');
const path = require('path');

const CONFIG = require('../config');

module.exports = function(task) {
  task.start(`Transpiling CoffeeScript paths in ${CONFIG.intermediateAppPath}`);

  const paths = getPathsToTranspile();

  if (paths.length === 0) {
    task.warn('No paths to transpile');
  } else {
    task.info(`Transpiling ${paths.length} paths`);
  }

  for (let path of paths) {
    transpileCoffeeScriptPath(path);
  }

  task.done();
};

function getPathsToTranspile() {
  let paths = [];
  paths = paths.concat(
    glob.sync(path.join(CONFIG.intermediateAppPath, 'src', '**', '*.coffee'), {
      nodir: true
    })
  );
  paths = paths.concat(
    glob.sync(path.join(CONFIG.intermediateAppPath, 'spec', '*.coffee'), {
      nodir: true
    })
  );
  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    paths = paths.concat(
      glob.sync(
        path.join(
          CONFIG.intermediateAppPath,
          'node_modules',
          packageName,
          '**',
          '*.coffee'
        ),
        {
          ignore: path.join(
            CONFIG.intermediateAppPath,
            'node_modules',
            packageName,
            'spec',
            '**',
            '*.coffee'
          ),
          nodir: true
        }
      )
    );
  }
  return paths;
}

function transpileCoffeeScriptPath(coffeePath) {
  const jsPath = coffeePath.replace(/coffee$/g, 'js');
  fs.writeFileSync(
    jsPath,
    CompileCache.addPathToCache(coffeePath, CONFIG.atomHomeDirPath)
  );
  fs.unlinkSync(coffeePath);
}
