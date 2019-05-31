var path = require('path');
var spawn = require('child_process').spawn;

var atomCommandPath = path.resolve(__dirname, '..', '..', 'atom.exe');
var args = process.argv.slice(2);
args.unshift('--executed-from', process.cwd());
var options = { detached: true, stdio: 'ignore' };
spawn(atomCommandPath, args, options);
process.exit(0);
