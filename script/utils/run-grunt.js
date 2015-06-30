var cp = require('./child-process-wrapper.js');
var fs = require('fs');
var path = require('path');

module.exports = function(additionalArgs, callback) {
  var gruntPath = path.join('build', 'node_modules', '.bin', 'grunt') + (process.platform === 'win32' ? '.cmd' : '');

  if (!fs.existsSync(gruntPath)) {
    console.error('Grunt command does not exist at: ' + gruntPath);
    console.error('Run script/bootstrap to install Grunt');
    process.exit(1);
  }

  var args = ['--gruntfile', path.resolve('build', 'Gruntfile.coffee')];
  args = args.concat(additionalArgs);
  cp.safeSpawn(gruntPath, args, callback);
};
