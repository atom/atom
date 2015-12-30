var childProcess = require('child_process');

// Exit the process if the command failed and only call the callback if the
// command succeed, output of the command would also be piped.
exports.safeExec = function(command, options, callback) {
  if (!callback) {
    callback = options;
    options = {};
  }
  if (!options)
    options = {};

  // This needed to be increased for `apm test` runs that generate many failures
  // The default is 200KB.
  options.maxBuffer = 1024 * 1024;

  var child = childProcess.exec(command, options, function(error, stdout, stderr) {
    if (error)
      process.exit(error.code || 1);
    else
      callback(null);
  });
  child.stderr.pipe(process.stderr);
  if (!options.ignoreStdout)
    child.stdout.pipe(process.stdout);
}

// Same with safeExec but call child_process.spawn instead.
exports.safeSpawn = function(command, args, options, callback) {
  if (!callback) {
    callback = options;
    options = {};
  }
  var child = childProcess.spawn(command, args, options);
  child.stderr.pipe(process.stderr);
  child.stdout.pipe(process.stdout);
  child.on('exit', function(code) {
    if (code != 0)
      process.exit(code);
    else
      callback(null);
  });
}
