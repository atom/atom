// This file exports a function that has the same interface as
// `spawnSync`, but it throws if there's an error while executing
// the supplied command or if the exit code is not 0. This is similar to what
// `execSync` does, but we want to use `spawnSync` because it provides automatic
// escaping for the supplied arguments.

const childProcess = require('child_process');

module.exports = function() {
  const result = childProcess.spawnSync.apply(childProcess, arguments);
  if (result.error) {
    throw result.error;
  } else if (result.status !== 0) {
    if (result.stdout) console.error(result.stdout.toString());
    if (result.stderr) console.error(result.stderr.toString());
    throw new Error(
      `Command ${result.args.join(' ')} exited with code "${result.status}"`
    );
  } else {
    return result;
  }
};
