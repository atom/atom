var spawn = require('child_process').spawn;

var options = {
  detached: true,
  stdio: 'ignore'
}

var args = process.argv.slice(2);
console.log(args);
spawn("C:\\Users\\kevin\\AppData\\Local\\atom\\app-0.156.0\\atom.exe", args, options);
process.exit(0);
