const BufferedProcess = require('./buffered-process');

// Extended: Like {BufferedProcess}, but accepts a Node script as the command
// to run.
//
// This is necessary on Windows since it doesn't support shebang `#!` lines.
//
// ## Examples
//
// ```js
//   const {BufferedNodeProcess} = require('atom')
// ```
module.exports = class BufferedNodeProcess extends BufferedProcess {
  // Public: Runs the given Node script by spawning a new child process.
  //
  // * `options` An {Object} with the following keys:
  //   * `command` The {String} path to the JavaScript script to execute.
  //   * `args` The {Array} of arguments to pass to the script (optional).
  //   * `options` The options {Object} to pass to Node's `ChildProcess.spawn`
  //               method (optional).
  //   * `stdout` The callback {Function} that receives a single argument which
  //              contains the standard output from the command. The callback is
  //              called as data is received but it's buffered to ensure only
  //              complete lines are passed until the source stream closes. After
  //              the source stream has closed all remaining data is sent in a
  //              final call (optional).
  //   * `stderr` The callback {Function} that receives a single argument which
  //              contains the standard error output from the command. The
  //              callback is called as data is received but it's buffered to
  //              ensure only complete lines are passed until the source stream
  //              closes. After the source stream has closed all remaining data
  //              is sent in a final call (optional).
  //   * `exit` The callback {Function} which receives a single argument
  //            containing the exit status (optional).
  constructor({ command, args, options = {}, stdout, stderr, exit }) {
    options.env = options.env || Object.create(process.env);
    options.env.ELECTRON_RUN_AS_NODE = 1;
    options.env.ELECTRON_NO_ATTACH_CONSOLE = 1;

    args = args ? args.slice() : [];
    args.unshift(command);
    args.unshift('--no-deprecation');

    super({
      command: process.execPath,
      args,
      options,
      stdout,
      stderr,
      exit
    });
  }
};
