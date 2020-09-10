'use strict';

const fs = require('fs');
const path = require('path');

const { DefaultTask } = require('../lib/task');

module.exports = function(task = new DefaultTask()) {
  task.start('Delete MS Build from PATH');

  let removed = 0;

  process.env['PATH'] = process.env['PATH']
    .split(';')
    .filter(function(p) {
      if (fs.existsSync(path.join(p, 'msbuild.exe'))) {
        task.log(
          'Excluding "' +
            p +
            '" from PATH to avoid msbuild.exe mismatch that causes errors during module installation'
        );
        removed += 1;
        return false;
      } else {
        return true;
      }
    })
    .join(';');

  if (removed === 0) {
    task.verbose('msbuild.exe not found, no paths excluded');
  }

  task.done();
};
