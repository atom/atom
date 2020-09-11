const downloadFileFromGithub = require('./download-file-from-github');
const fs = require('fs-extra');
const os = require('os');
const path = require('path');
const spawnSync = require('./spawn-sync');
const osxSign = require('electron-osx-sign');

const CONFIG = require('../config');
const { DefaultTask } = require('./task');

const macEntitlementsPath = path.join(
  CONFIG.repositoryRootPath,
  'resources',
  'mac',
  'entitlements.plist'
);

module.exports = async function(packagedAppPath, task = new DefaultTask()) {
  task.start('Code sign on mac');

  if (
    !process.env.ATOM_MAC_CODE_SIGNING_CERT_DOWNLOAD_URL &&
    !process.env.ATOM_MAC_CODE_SIGNING_CERT_PATH
  ) {
    task.log(
      'Skipping code signing because the ATOM_MAC_CODE_SIGNING_CERT_DOWNLOAD_URL environment variable is not defined'
        .gray
    );
    task.done();
    return;
  }

  let certPath = process.env.ATOM_MAC_CODE_SIGNING_CERT_PATH;
  if (!certPath) {
    certPath = path.join(os.tmpdir(), 'mac.p12');
    downloadFileFromGithub(
      process.env.ATOM_MAC_CODE_SIGNING_CERT_DOWNLOAD_URL,
      certPath
    );
  }
  try {
    task.log(
      `Ensuring keychain ${process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN} exists`
    );
    try {
      spawnSync(
        'security',
        ['show-keychain-info', process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN],
        { stdio: 'inherit' }
      );
    } catch (err) {
      task.log(
        `Creating keychain ${process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN}`
      );
      // The keychain doesn't exist, try to create it
      spawnSync(
        'security',
        [
          'create-keychain',
          '-p',
          process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN_PASSWORD,
          process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN
        ],
        { stdio: 'inherit' }
      );

      // List the keychain to "activate" it.  Somehow this seems
      // to be needed otherwise the signing operation fails
      spawnSync(
        'security',
        ['list-keychains', '-s', process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN],
        { stdio: 'inherit' }
      );

      // Make sure it doesn't time out before we use it
      spawnSync(
        'security',
        [
          'set-keychain-settings',
          '-t',
          '3600',
          '-u',
          process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN
        ],
        { stdio: 'inherit' }
      );
    }

    task.log(
      `Unlocking keychain ${process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN}`
    );
    const unlockArgs = ['unlock-keychain'];
    // For signing on local workstations, password could be entered interactively
    if (process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN_PASSWORD) {
      unlockArgs.push(
        '-p',
        process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN_PASSWORD
      );
    }
    unlockArgs.push(process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN);
    spawnSync('security', unlockArgs, { stdio: 'inherit' });

    task.log(
      `Importing certificate at ${certPath} into ${
        process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN
      } keychain`
    );
    spawnSync('security', [
      'import',
      certPath,
      '-P',
      process.env.ATOM_MAC_CODE_SIGNING_CERT_PASSWORD,
      '-k',
      process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN,
      '-T',
      '/usr/bin/codesign'
    ]);

    task.log(
      'Running incantation to suppress dialog when signing on macOS Sierra'
    );
    try {
      spawnSync('security', [
        'set-key-partition-list',
        '-S',
        'apple-tool:,apple:',
        '-s',
        '-k',
        process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN_PASSWORD,
        process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN
      ]);
    } catch (e) {
      task.warn("Incantation failed... maybe this isn't Sierra?");
    }

    task.log(`Code-signing application at ${packagedAppPath}`);

    try {
      await osxSign.signAsync({
        app: packagedAppPath,
        entitlements: macEntitlementsPath,
        'entitlements-inherit': macEntitlementsPath,
        identity: 'Developer ID Application: GitHub',
        keychain: process.env.ATOM_MAC_CODE_SIGNING_KEYCHAIN,
        platform: 'darwin',
        hardenedRuntime: true
      });
      task.info('Application signing complete');
    } catch (err) {
      task.error('Applicaiton singing failed');
      task.error(err);
    }
  } finally {
    if (!process.env.ATOM_MAC_CODE_SIGNING_CERT_PATH) {
      task.log(`Deleting certificate at ${certPath}`);
      fs.removeSync(certPath);
    }
  }

  task.done();
};
