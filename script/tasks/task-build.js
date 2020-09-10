module.exports = function(task) {
  task.start('Build');

  if (process.argv.includes('--no-bootstrap')) {
    task.log('Skipping bootstrap');
  } else {
    // Bootstrap first to ensure all the dependencies used later in this script
    // are installed.
    require('./task-bootstrap')(task.subtask());
  }

  // Needed so we can require src/module-cache.coffee during generateModuleCache
  require('coffee-script/register');
  require('colors');

  const path = require('path');
  const yargs = require('yargs');
  const argv = yargs
    .usage('Usage: $0 [options]')
    .help('help')
    .describe(
      'existing-binaries',
      'Use existing Atom binaries (skip clean/transpile/cache)'
    )
    .describe('code-sign', 'Code-sign executables (macOS and Windows only)')
    .describe('test-sign', 'Test-sign executables (macOS only)')
    .describe('create-windows-installer', 'Create installer (Windows only)')
    .describe('create-debian-package', 'Create .deb package (Linux only)')
    .describe('create-rpm-package', 'Create .rpm package (Linux only)')
    .describe(
      'compress-artifacts',
      'Compress Atom binaries (and symbols on macOS)'
    )
    .describe('generate-api-docs', 'Only build the API documentation')
    .describe('install', 'Install Atom')
    .string('install')
    .describe(
      'ci',
      'Install dependencies quickly (package-lock.json files must be up to date)'
    )
    .wrap(yargs.terminalWidth()).argv;

  const checkChromedriverVersion = require('./task-check-chromedriver-version');
  const cleanOutputDirectory = require('./task-clean-output-directory');
  const codeSignOnMac = require('../lib/code-sign-on-mac');
  const codeSignOnWindows = require('../lib/code-sign-on-windows');
  const compressArtifacts = require('../lib/compress-artifacts');
  const copyAssets = require('./task-copy-assets');
  const createDebianPackage = require('../lib/create-debian-package');
  const createRpmPackage = require('../lib/create-rpm-package');
  const createWindowsInstaller = require('../lib/create-windows-installer');
  const dumpSymbols = require('../lib/dump-symbols');
  const generateAPIDocs = require('../lib/generate-api-docs');
  const generateMetadata = require('../lib/generate-metadata');
  const generateModuleCache = require('../lib/generate-module-cache');
  const generateStartupSnapshot = require('../lib/generate-startup-snapshot');
  const installApplication = require('../lib/install-application');
  const notarizeOnMac = require('../lib/notarize-on-mac');
  const packageApplication = require('../lib/package-application');
  const prebuildLessCache = require('../lib/prebuild-less-cache');
  const testSignOnMac = require('../lib/test-sign-on-mac');
  const transpileBabelPaths = require('./task-transpile-babel-paths');
  const transpileCoffeeScriptPaths = require('./task-transpile-coffee-script-paths');
  const transpileCsonPaths = require('../lib/transpile-cson-paths');
  const transpilePegJsPaths = require('../lib/transpile-peg-js-paths');
  const transpilePackagesWithCustomTranspilerPaths = require('./task-transpile-packages-with-custom-transpiler-paths.js');

  process.on('unhandledRejection', function(e) {
    task.error(e.stack || e);
    process.exit(1);
  });

  const CONFIG = require('../config');
  process.env.ELECTRON_VERSION = CONFIG.appMetadata.electronVersion;

  let binariesPromise = Promise.resolve();

  if (!argv.existingBinaries) {
    checkChromedriverVersion(task.subtask());
    cleanOutputDirectory(task.subtask());
    copyAssets(task.subtask());
    transpilePackagesWithCustomTranspilerPaths(task.subtask());
    transpileBabelPaths(task.subtask());
    transpileCoffeeScriptPaths(task.subtask());
    transpileCsonPaths();
    transpilePegJsPaths();
    generateModuleCache();
    prebuildLessCache();
    generateMetadata();
    generateAPIDocs();
    if (!argv.generateApiDocs) {
      binariesPromise = dumpSymbols();
    }
  }

  if (!argv.generateApiDocs) {
    binariesPromise
      .then(packageApplication)
      .then(packagedAppPath =>
        generateStartupSnapshot(packagedAppPath).then(() => packagedAppPath)
      )
      .then(async packagedAppPath => {
        switch (process.platform) {
          case 'darwin': {
            if (argv.codeSign) {
              await codeSignOnMac(packagedAppPath);
              await notarizeOnMac(packagedAppPath);
            } else if (argv.testSign) {
              testSignOnMac(packagedAppPath);
            } else {
              task.log(
                'Skipping code-signing. Specify the --code-sign option to perform code-signing'
                  .gray
              );
            }
            break;
          }
          case 'win32': {
            if (argv.testSign) {
              task.log(
                'Test signing is not supported on Windows, skipping.'.gray
              );
            }

            if (argv.codeSign) {
              const executablesToSign = [
                path.join(packagedAppPath, CONFIG.executableName)
              ];
              if (argv.createWindowsInstaller) {
                executablesToSign.push(
                  path.join(
                    __dirname,
                    'node_modules',
                    '@atom',
                    'electron-winstaller',
                    'vendor',
                    'Squirrel.exe'
                  )
                );
              }
              codeSignOnWindows(executablesToSign);
            } else {
              task.log(
                'Skipping code-signing. Specify the --code-sign option to perform code-signing'
                  .gray
              );
            }
            if (argv.createWindowsInstaller) {
              return createWindowsInstaller(packagedAppPath).then(
                installerPath => {
                  argv.codeSign && codeSignOnWindows([installerPath]);
                  return packagedAppPath;
                }
              );
            } else {
              task.log(
                'Skipping creating installer. Specify the --create-windows-installer option to create a Squirrel-based Windows installer.'
                  .gray
              );
            }
            break;
          }
          case 'linux': {
            if (argv.createDebianPackage) {
              createDebianPackage(packagedAppPath);
            } else {
              task.log(
                'Skipping creating debian package. Specify the --create-debian-package option to create it.'
                  .gray
              );
            }

            if (argv.createRpmPackage) {
              createRpmPackage(packagedAppPath);
            } else {
              task.log(
                'Skipping creating rpm package. Specify the --create-rpm-package option to create it.'
                  .gray
              );
            }
            break;
          }
        }

        return Promise.resolve(packagedAppPath);
      })
      .then(packagedAppPath => {
        if (argv.compressArtifacts) {
          compressArtifacts(packagedAppPath);
        } else {
          task.log(
            'Skipping artifacts compression. Specify the --compress-artifacts option to compress Atom binaries (and symbols on macOS)'
              .gray
          );
        }

        if (argv.install != null) {
          installApplication(packagedAppPath, argv.install);
        } else {
          task.log(
            'Skipping installation. Specify the --install option to install Atom'
              .gray
          );
        }
      });
  }

  binariesPromise.then(() => {
    task.done();
  });
};
