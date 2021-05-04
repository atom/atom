'use strict';

const fs = require('fs');

module.exports = function(paths) {
  return Promise.all(paths.map(readFile));
};

function readFile(path) {
  return new Promise((resolve, reject) => {
    fs.readFile(path, 'utf8', (error, content) => {
      if (error) {
        reject(error);
      } else {
        resolve({ path, content });
      }
    });
  });
}
