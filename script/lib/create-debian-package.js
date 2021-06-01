'use strict';

const fs = require('fs-extra');
const os = require('os');
const path = require('path');
const spawnSync = require('./spawn-sync');
const template = require('lodash.template');

const CONFIG = require('../config');

module.exports = function(packagedAppPath) {
  console.log(`Creating Debian package for "${packagedAppPath}"`);
  const atomExecutableName =
    CONFIG.channel === 'stable' ? 'atom' : `atom-${CONFIG.channel}`;
  const apmExecutableName =
    CONFIG.channel === 'stable' ? 'apm' : `apm-${CONFIG.channel}`;
  const appDescription = CONFIG.appMetadata.description;
  const appVersion = CONFIG.appMetadata.version;
  let arch;
  if (process.arch === 'ia32') {
    arch = 'i386';
  } else if (process.arch === 'x64') {
    arch = 'amd64';
  } else if (process.arch === 'ppc') {
    arch = 'powerpc';
  } else {
    arch = process.arch;
  }

  const outputDebianPackageFilePath = path.join(
    CONFIG.buildOutputPath,
    `atom-${arch}.deb`
  );
  const debianPackageDirPath = path.join(
    os.tmpdir(),
    path.basename(packagedAppPath)
  );
  const debianPackageConfigPath = path.join(debianPackageDirPath, 'DEBIAN');
  const debianPackageInstallDirPath = path.join(debianPackageDirPath, 'usr');
  const debianPackageBinDirPath = path.join(debianPackageInstallDirPath, 'bin');
  const debianPackageShareDirPath = path.join(
    debianPackageInstallDirPath,
    'share'
  );
  const debianPackageAtomDirPath = path.join(
    debianPackageShareDirPath,
    atomExecutableName
  );
  const debianPackageApplicationsDirPath = path.join(
    debianPackageShareDirPath,
    'applications'
  );
  const debianPackageIconsDirPath = path.join(
    debianPackageShareDirPath,
    'pixmaps'
  );
  const debianPackageDocsDirPath = path.join(
    debianPackageShareDirPath,
    'doc',
    atomExecutableName
  );

  if (fs.existsSync(debianPackageDirPath)) {
    console.log(
      `Deleting existing build dir for Debian package at "${debianPackageDirPath}"`
    );
    fs.removeSync(debianPackageDirPath);
  }
  if (fs.existsSync(`${debianPackageDirPath}.deb`)) {
    console.log(
      `Deleting existing Debian package at "${debianPackageDirPath}.deb"`
    );
    fs.removeSync(`${debianPackageDirPath}.deb`);
  }
  if (fs.existsSync(debianPackageDirPath)) {
    console.log(
      `Deleting existing Debian package at "${outputDebianPackageFilePath}"`
    );
    fs.removeSync(debianPackageDirPath);
  }

  console.log(
    `Creating Debian package directory structure at "${debianPackageDirPath}"`
  );
  fs.mkdirpSync(debianPackageDirPath);
  fs.mkdirpSync(debianPackageConfigPath);
  fs.mkdirpSync(debianPackageInstallDirPath);
  fs.mkdirpSync(debianPackageShareDirPath);
  fs.mkdirpSync(debianPackageApplicationsDirPath);
  fs.mkdirpSync(debianPackageIconsDirPath);
  fs.mkdirpSync(debianPackageDocsDirPath);
  fs.mkdirpSync(debianPackageBinDirPath);

  console.log(`Copying "${packagedAppPath}" to "${debianPackageAtomDirPath}"`);
  fs.copySync(packagedAppPath, debianPackageAtomDirPath);
  fs.chmodSync(debianPackageAtomDirPath, '755');

  console.log(`Copying binaries into "${debianPackageBinDirPath}"`);
  fs.copySync(
    path.join(CONFIG.repositoryRootPath, 'atom.sh'),
    path.join(debianPackageBinDirPath, atomExecutableName)
  );
  fs.symlinkSync(
    path.join(
      '..',
      'share',
      atomExecutableName,
      'resources',
      'app',
      'apm',
      'node_modules',
      '.bin',
      'apm'
    ),
    path.join(debianPackageBinDirPath, apmExecutableName)
  );

  fs.chmodSync(path.join(debianPackageAtomDirPath, 'chrome-sandbox'), '4755');

  console.log(`Writing control file into "${debianPackageConfigPath}"`);
  const packageSizeInKilobytes = spawnSync('du', ['-sk', packagedAppPath])
    .stdout.toString()
    .split(/\s+/)[0];
  const controlFileTemplate = fs.readFileSync(
    path.join(
      CONFIG.repositoryRootPath,
      'resources',
      'linux',
      'debian',
      'control.in'
    )
  );
  const controlFileContents = template(controlFileTemplate)({
    appFileName: atomExecutableName,
    version: appVersion,
    arch: arch,
    installedSize: packageSizeInKilobytes,
    description: appDescription
  });
  fs.writeFileSync(
    path.join(debianPackageConfigPath, 'control'),
    controlFileContents
  );

  console.log(
    `Writing desktop entry file into "${debianPackageApplicationsDirPath}"`
  );
  const desktopEntryTemplate = fs.readFileSync(
    path.join(
      CONFIG.repositoryRootPath,
      'resources',
      'linux',
      'atom.desktop.in'
    )
  );
  const desktopEntryContents = template(desktopEntryTemplate)({
    appName: CONFIG.appName,
    appFileName: atomExecutableName,
    description: appDescription,
    installDir: '/usr',
    iconPath: atomExecutableName
  });
  fs.writeFileSync(
    path.join(
      debianPackageApplicationsDirPath,
      `${atomExecutableName}.desktop`
    ),
    desktopEntryContents
  );

  console.log(`Copying icon into "${debianPackageIconsDirPath}"`);
  fs.copySync(
    path.join(
      packagedAppPath,
      'resources',
      'app.asar.unpacked',
      'resources',
      'atom.png'
    ),
    path.join(debianPackageIconsDirPath, `${atomExecutableName}.png`)
  );

  console.log(`Copying license into "${debianPackageDocsDirPath}"`);
  fs.copySync(
    path.join(packagedAppPath, 'resources', 'LICENSE.md'),
    path.join(debianPackageDocsDirPath, 'copyright')
  );

  console.log(
    `Copying polkit configuration into "${debianPackageShareDirPath}"`
  );
  fs.copySync(
    path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'atom.policy'),
    path.join(
      debianPackageShareDirPath,
      'polkit-1',
      'actions',
      `atom-${CONFIG.channel}.policy`
    )
  );

  console.log(`Generating .deb file from ${debianPackageDirPath}`);
  spawnSync('fakeroot', ['dpkg-deb', '-b', debianPackageDirPath], {
    stdio: 'inherit'
  });

  console.log(
    `Copying generated package into "${outputDebianPackageFilePath}"`
  );
  fs.copySync(`${debianPackageDirPath}.deb`, outputDebianPackageFilePath);
};
