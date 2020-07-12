"use strict"

const {taskify} = require("../lib/task");

const buildTask = taskify("Build", async function() {
  if (process.argv.includes("--bootstrap")) {
    await this.subtask(require("./bootstrap"));
  }

  require('coffee-script/register');
  require('colors');

  const path = require('path');
  const yargs = require('yargs');
  const argv = yargs
    .usage('Usage: $0 [options]')
    .help('help')
    .describe('existing-binaries', 'Use existing Atom binaries (skip clean/transpile/cache)')
    .describe('code-sign', 'Code-sign executables (macOS and Windows only)')
    .describe('test-sign', 'Test-sign executables (macOS only)')
    .describe('create-windows-installer', 'Create installer (Windows only)')
    .describe('create-debian-package', 'Create .deb package (Linux only)')
    .describe('create-rpm-package', 'Create .rpm package (Linux only)')
    .describe('compress-artifacts', 'Compress Atom binaries (and symbols on macOS)')
    .describe('generate-api-docs', 'Only build the API documentation')
    .describe('deps', 'Install apm and Atom deps')
    .describe('install', 'Install Atom')
    .string('install')
    .describe('ci', 'Install dependencies quickly (package-lock.json files must be up to date)')
    .wrap(yargs.terminalWidth())
    .argv;

  const CONFIG = require('../config');
  process.env.ELECTRON_VERSION = CONFIG.appMetadata.electronVersion

  let binariesPromise = Promise.resolve();

  if (argv.deps) {
    await this.subtask(taskify("Install dependencies", async function() {
      await this.subtask(require("./install-apm"));
      await this.subtask(require("./run-apm-install"), CONFIG.repositoryRootPath, CONFIG.ci);
    }));
  }

  if (!argv.existingBinaries) {
    await this.subtask(taskify("Generate binaries", async function() {
      await this.subtask(require("./check-chromedriver-version"));
      await this.subtask(require("./clean-output-directory"));
      await this.subtask(require("./copy-assets"));
      await this.subtask(require("./transpile-packages-with-custom-transpiler-paths"));
      await this.subtask(require("./transpile-babel-paths"));
      await this.subtask(require("./transpile-coffee-script-paths"));
      await this.subtask(require("./transpile-cson-paths"));
      await this.subtask(require("./transpile-peg-js-paths"));
      await this.subtask(require("./generate-module-cache"));
      await this.subtask(require("./prebuild-less-cache"));
      await this.subtask(require("./generate-metadata"));
      await this.subtask(require("./generate-api-docs"));

      if (!argv.generateApiDocs) {
        binariesPromise = this.subtask(require("./dump-symbols"));
      }
    }));
  }

  if (!argv.generateApiDocs) {
    await binariesPromise;

    const packagedAppPath = await this.subtask(require('./package-application'));

    await this.subtask(require('./generate-startup-snapshot'), packagedAppPath);

    switch (process.platform) {
      case 'darwin': {
        if (argv.codeSign) {
          await require('../lib/code-sign-on-mac')(packagedAppPath)
          await require('../lib/notarize-on-mac')(packagedAppPath)
        } else if (argv.testSign) {
          require('../lib/test-sign-on-mac')(packagedAppPath)
        } else {
          this.info('Skipping code-signing. Specify the --code-sign option to perform code-signing'.gray)
        }
        break
      }
      case 'win32': {
        if (argv.testSign) {
          this.info('Test signing is not supported on Windows, skipping.'.gray)
        }

        if (argv.codeSign) {
          const executablesToSign = [ path.join(packagedAppPath, CONFIG.executableName) ]
          if (argv.createWindowsInstaller) {
            executablesToSign.push(path.join(__dirname, 'node_modules', '@atom', 'electron-winstaller', 'vendor', 'Squirrel.exe'))
          }
          codeSignOnWindows(executablesToSign)
        } else {
          this.info('Skipping code-signing. Specify the --code-sign option to perform code-signing'.gray)
        }
        if (argv.createWindowsInstaller) {
          return createWindowsInstaller(packagedAppPath)
            .then((installerPath) => {
              argv.codeSign && codeSignOnWindows([installerPath])
              return packagedAppPath
            })
        } else {
          this.info('Skipping creating installer. Specify the --create-windows-installer option to create a Squirrel-based Windows installer.'.gray)
        }
        break
      }
      case 'linux': {
        if (argv.createDebianPackage) {
          createDebianPackage(packagedAppPath)
        } else {
          this.info('Skipping creating debian package. Specify the --create-debian-package option to create it.'.gray)
        }

        if (argv.createRpmPackage) {
          createRpmPackage(packagedAppPath)
        } else {
          this.info('Skipping creating rpm package. Specify the --create-rpm-package option to create it.'.gray)
        }
        break
      }
    }

    if (argv.compressArtifacts) {
      require('../lib/compress-artifacts')(packagedAppPath)
    } else {
      this.info('Skipping artifacts compression. Specify the --compress-artifacts option to compress Atom binaries (and symbols on macOS)'.gray)
    }

    if (argv.install != null) {
      require('../lib/install-application')(packagedAppPath, argv.install)
    } else {
      this.info('Skipping installation. Specify the --install option to install Atom'.gray)
    }
  }
});

module.exports = buildTask;
