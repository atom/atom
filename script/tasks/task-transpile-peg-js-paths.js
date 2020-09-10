'use strict';

const peg = require('pegjs');
const fs = require('fs');
const glob = require('glob');
const path = require('path');

const CONFIG = require('../config');
const { DefaultTask } = require('../lib/task');

module.exports = function(task = new DefaultTask()) {
  task.start(`Transpiling PEG.js paths in ${CONFIG.intermediateAppPath}`);

  const paths = getPathsToTranspile();
  if (paths.length === 0) {
    task.warn('No paths to transpile');
  } else {
    task.info(`Transpiling ${paths.length} paths`);
  }

  for (let path of paths) {
    transpilePegJsPath(path);
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
          '*.pegjs'
        ),
        { nodir: true }
      )
    );
  }
  return paths;
}

function transpilePegJsPath(pegJsPath) {
  const inputCode = fs.readFileSync(pegJsPath, 'utf8');
  const jsPath = pegJsPath.replace(/pegjs$/g, 'js');
  const outputCode =
    'module.exports = ' + peg.buildParser(inputCode, { output: 'source' });
  fs.writeFileSync(jsPath, outputCode);
  fs.unlinkSync(pegJsPath);
}
