var path  = require('path');
var spawn = require('child_process').spawn;

var atomCommandPath = path.resolve(__dirname, '..', '..', 'atom.exe');
var arguments = process.argv.slice(2);
arguments.unshift('--executed-from', process.cwd());
var options = {detached: true, stdio: 'ignore'};
spawn(atomCommandPath, arguments, options);
process.exit(0);
