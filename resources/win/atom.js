var spawn = require('child_process').spawn;

var atomCommandPath = process.argv[2];
var arguments = process.argv.slice(3);
var options = {detached: true, stdio: 'ignore'};
spawn(atomCommandPath, arguments, options);
process.exit(0);
