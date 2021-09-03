'use strict';

const glob = require('glob');

module.exports = function(globPaths) {
  return Promise.all(globPaths.map(g => expandGlobPath(g))).then(paths =>
    paths.reduce((a, b) => a.concat(b), [])
  );
};

function expandGlobPath(globPath) {
  return new Promise((resolve, reject) => {
    glob(globPath, (error, paths) => {
      if (error) {
        reject(error);
      } else {
        resolve(paths);
      }
    });
  });
}
