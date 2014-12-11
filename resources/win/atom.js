var spawn = require('child_process').spawn;

var options = {
  detached: true,
  stdio: 'ignore'
}

console.log(process.argv);
spawn("C:\\Users\\kevin\\AppData\\Local\\atom\\app-0.156.0\\atom.exe", [], options);
process.exit();
