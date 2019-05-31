'use strict';

const dedent = require('dedent');
const yargs = require('yargs');
const { app } = require('electron');

module.exports = function parseCommandLine(processArgs) {
  const options = yargs(processArgs).wrap(yargs.terminalWidth());
  const version = app.getVersion();
  options.usage(
    dedent`Atom Editor v${version}

    Usage:
      atom
      atom [options] [path ...]
      atom file[:line[:column]]

    One or more paths to files or folders may be specified. If there is an
    existing Atom window that contains all of the given folders, the paths
    will be opened in that window. Otherwise, they will be opened in a new
    window.

    A file may be opened at the desired line (and optionally column) by
    appending the numbers right after the file name, e.g. \`atom file:5:8\`.

    Paths that start with \`atom://\` will be interpreted as URLs.

    Environment Variables:

      ATOM_DEV_RESOURCE_PATH  The path from which Atom loads source code in dev mode.
                              Defaults to \`~/github/atom\`.

      ATOM_HOME               The root path for all configuration files and folders.
                              Defaults to \`~/.atom\`.`
  );
  // Deprecated 1.0 API preview flag
  options
    .alias('1', 'one')
    .boolean('1')
    .describe('1', 'This option is no longer supported.');
  options
    .boolean('include-deprecated-apis')
    .describe(
      'include-deprecated-apis',
      'This option is not currently supported.'
    );
  options
    .alias('d', 'dev')
    .boolean('d')
    .describe('d', 'Run in development mode.');
  options
    .alias('f', 'foreground')
    .boolean('f')
    .describe('f', 'Keep the main process in the foreground.');
  options
    .alias('h', 'help')
    .boolean('h')
    .describe('h', 'Print this usage message.');
  options
    .alias('l', 'log-file')
    .string('l')
    .describe('l', 'Log all output to file.');
  options
    .alias('n', 'new-window')
    .boolean('n')
    .describe('n', 'Open a new window.');
  options
    .boolean('profile-startup')
    .describe(
      'profile-startup',
      'Create a profile of the startup execution time.'
    );
  options
    .alias('r', 'resource-path')
    .string('r')
    .describe(
      'r',
      'Set the path to the Atom source directory and enable dev-mode.'
    );
  options
    .boolean('safe')
    .describe(
      'safe',
      'Do not load packages from ~/.atom/packages or ~/.atom/dev/packages.'
    );
  options
    .boolean('benchmark')
    .describe(
      'benchmark',
      'Open a new window that runs the specified benchmarks.'
    );
  options
    .boolean('benchmark-test')
    .describe(
      'benchmark-test',
      'Run a faster version of the benchmarks in headless mode.'
    );
  options
    .alias('t', 'test')
    .boolean('t')
    .describe(
      't',
      'Run the specified specs and exit with error code on failures.'
    );
  options
    .alias('m', 'main-process')
    .boolean('m')
    .describe('m', 'Run the specified specs in the main process.');
  options
    .string('timeout')
    .describe(
      'timeout',
      'When in test mode, waits until the specified time (in minutes) and kills the process (exit code: 130).'
    );
  options
    .alias('v', 'version')
    .boolean('v')
    .describe('v', 'Print the version information.');
  options
    .alias('w', 'wait')
    .boolean('w')
    .describe('w', 'Wait for window to be closed before returning.');
  options
    .alias('a', 'add')
    .boolean('a')
    .describe('add', 'Open path as a new project in last used window.');
  options.string('user-data-dir');
  options
    .boolean('clear-window-state')
    .describe('clear-window-state', 'Delete all Atom environment state.');
  options
    .boolean('enable-electron-logging')
    .describe(
      'enable-electron-logging',
      'Enable low-level logging messages from Electron.'
    );
  options.boolean('uri-handler');

  let args = options.argv;

  // If --uri-handler is set, then we parse NOTHING else
  if (args.uriHandler) {
    args = {
      uriHandler: true,
      'uri-handler': true,
      _: args._.filter(str => str.startsWith('atom://')).slice(0, 1)
    };
  }

  if (args.help) {
    process.stdout.write(options.help());
    process.exit(0);
  }

  if (args.version) {
    process.stdout.write(
      `Atom    : ${app.getVersion()}\n` +
        `Electron: ${process.versions.electron}\n` +
        `Chrome  : ${process.versions.chrome}\n` +
        `Node    : ${process.versions.node}\n`
    );
    process.exit(0);
  }

  const addToLastWindow = args['add'];
  const safeMode = args['safe'];
  const benchmark = args['benchmark'];
  const benchmarkTest = args['benchmark-test'];
  const test = args['test'];
  const mainProcess = args['main-process'];
  const timeout = args['timeout'];
  const newWindow = args['new-window'];
  let executedFrom = null;
  if (args['executed-from'] && args['executed-from'].toString()) {
    executedFrom = args['executed-from'].toString();
  } else {
    executedFrom = process.cwd();
  }

  if (newWindow && addToLastWindow) {
    process.stderr.write(
      `Only one of the --add and --new-window options may be specified at the same time.\n\n${options.help()}`
    );

    // Exiting the main process with a nonzero exit code on MacOS causes the app open to fail with the mysterious
    // message "LSOpenURLsWithRole() failed for the application /Applications/Atom Dev.app with error -10810."
    process.exit(0);
  }

  let pidToKillWhenClosed = null;
  if (args['wait']) {
    pidToKillWhenClosed = args['pid'];
  }

  const logFile = args['log-file'];
  const userDataDir = args['user-data-dir'];
  const profileStartup = args['profile-startup'];
  const clearWindowState = args['clear-window-state'];
  let pathsToOpen = [];
  let urlsToOpen = [];
  let devMode = args['dev'];

  for (const path of args._) {
    if (path.startsWith('atom://')) {
      urlsToOpen.push(path);
    } else {
      pathsToOpen.push(path);
    }
  }

  if (args.resourcePath || test) {
    devMode = true;
  }

  if (args['path-environment']) {
    // On Yosemite the $PATH is not inherited by the "open" command, so we have to
    // explicitly pass it by command line, see http://git.io/YC8_Ew.
    process.env.PATH = args['path-environment'];
  }

  return {
    pathsToOpen,
    urlsToOpen,
    executedFrom,
    test,
    version,
    pidToKillWhenClosed,
    devMode,
    safeMode,
    newWindow,
    logFile,
    userDataDir,
    profileStartup,
    timeout,
    clearWindowState,
    addToLastWindow,
    mainProcess,
    benchmark,
    benchmarkTest,
    env: process.env
  };
};
