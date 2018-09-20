var path  = require('path');
var spawn = require('child_process').spawn;

var atomCommandPath = path.resolve(__dirname, '..', '..', process.argv[2]);
var arguments = process.argv.slice(3);
arguments.unshift('--executed-from', process.cwd());
var options = {detached: true, stdio: 'ignore'};
spawn(atomCommandPath, arguments, options);
process.exit(0);
