'use strict';

const fs = require('fs');
const path = require('path');

module.exports = function() {
  process.env['PATH'] = process.env['PATH']
    .split(';')
    .filter(function(p) {
      if (fs.existsSync(path.join(p, 'msbuild.exe'))) {
        console.log(
          'Excluding "' +
            p +
            '" from PATH to avoid msbuild.exe mismatch that causes errors during module installation'
        );
        return false;
      } else {
        return true;
      }
    })
    .join(';');
};
