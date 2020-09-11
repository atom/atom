'use strict';

const assert = require('assert');
const fs = require('fs-extra');
const path = require('path');
const spawnSync = require('./spawn-sync');
const template = require('lodash.template');

const CONFIG = require('../config');
const { DefaultTask } = require('./task');

module.exports = function(packagedAppPath, task = new DefaultTask()) {
  task.start(`Creating rpm package for "${packagedAppPath}"`);

  const atomExecutableName =
    CONFIG.channel === 'stable' ? 'atom' : `atom-${CONFIG.channel}`;
  const apmExecutableName =
    CONFIG.channel === 'stable' ? 'apm' : `apm-${CONFIG.channel}`;
  const appName = CONFIG.appName;
  const appDescription = CONFIG.appMetadata.description;
  // RPM versions can't have dashes or tildes in them.
  // (Ref.: https://twiki.cern.ch/twiki/bin/view/Main/RPMAndDebVersioning)
  const appVersion = CONFIG.appMetadata.version.replace(/-/g, '.');
  const policyFileName = `atom-${CONFIG.channel}.policy`;

  const rpmPackageDirPath = path.join(CONFIG.homeDirPath, 'rpmbuild');
  const rpmPackageBuildDirPath = path.join(rpmPackageDirPath, 'BUILD');
  const rpmPackageSourcesDirPath = path.join(rpmPackageDirPath, 'SOURCES');
  const rpmPackageSpecsDirPath = path.join(rpmPackageDirPath, 'SPECS');
  const rpmPackageRpmsDirPath = path.join(rpmPackageDirPath, 'RPMS');
  const rpmPackageApplicationDirPath = path.join(
    rpmPackageBuildDirPath,
    appName
  );
  const rpmPackageIconsDirPath = path.join(rpmPackageBuildDirPath, 'icons');

  if (fs.existsSync(rpmPackageDirPath)) {
    task.log(`Deleting existing rpm build directory at "${rpmPackageDirPath}"`);
    fs.removeSync(rpmPackageDirPath);
  }

  task.log(
    `Creating rpm package directory structure at "${rpmPackageDirPath}"`
  );
  fs.mkdirpSync(rpmPackageDirPath);
  fs.mkdirpSync(rpmPackageBuildDirPath);
  fs.mkdirpSync(rpmPackageSourcesDirPath);
  fs.mkdirpSync(rpmPackageSpecsDirPath);

  task.log(`Copying "${packagedAppPath}" to "${rpmPackageApplicationDirPath}"`);
  fs.copySync(packagedAppPath, rpmPackageApplicationDirPath);

  task.log(`Copying icons into "${rpmPackageIconsDirPath}"`);
  fs.copySync(
    path.join(
      CONFIG.repositoryRootPath,
      'resources',
      'app-icons',
      CONFIG.channel,
      'png'
    ),
    rpmPackageIconsDirPath
  );

  task.log(`Writing rpm package spec file into "${rpmPackageSpecsDirPath}"`);
  const rpmPackageSpecFilePath = path.join(rpmPackageSpecsDirPath, 'atom.spec');
  const rpmPackageSpecsTemplate = fs.readFileSync(
    path.join(
      CONFIG.repositoryRootPath,
      'resources',
      'linux',
      'redhat',
      'atom.spec.in'
    )
  );
  const rpmPackageSpecsContents = template(rpmPackageSpecsTemplate)({
    appName: appName,
    appFileName: atomExecutableName,
    apmFileName: apmExecutableName,
    description: appDescription,
    installDir: '/usr',
    version: appVersion,
    policyFileName
  });
  fs.writeFileSync(rpmPackageSpecFilePath, rpmPackageSpecsContents);

  task.log(`Writing desktop entry file into "${rpmPackageBuildDirPath}"`);
  const desktopEntryTemplate = fs.readFileSync(
    path.join(
      CONFIG.repositoryRootPath,
      'resources',
      'linux',
      'atom.desktop.in'
    )
  );
  const desktopEntryContents = template(desktopEntryTemplate)({
    appName: appName,
    appFileName: atomExecutableName,
    description: appDescription,
    installDir: '/usr',
    iconPath: atomExecutableName
  });
  fs.writeFileSync(
    path.join(rpmPackageBuildDirPath, `${atomExecutableName}.desktop`),
    desktopEntryContents
  );

  task.log(`Copying atom.sh into "${rpmPackageBuildDirPath}"`);
  fs.copySync(
    path.join(CONFIG.repositoryRootPath, 'atom.sh'),
    path.join(rpmPackageBuildDirPath, 'atom.sh')
  );

  task.log(`Copying atom.policy into "${rpmPackageBuildDirPath}"`);
  fs.copySync(
    path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'atom.policy'),
    path.join(rpmPackageBuildDirPath, policyFileName)
  );

  task.log(`Generating .rpm package from "${rpmPackageDirPath}"`);
  spawnSync('rpmbuild', ['-ba', '--clean', rpmPackageSpecFilePath]);
  for (let generatedArch of fs.readdirSync(rpmPackageRpmsDirPath)) {
    const generatedArchDirPath = path.join(
      rpmPackageRpmsDirPath,
      generatedArch
    );
    const generatedPackageFileNames = fs.readdirSync(generatedArchDirPath);
    assert(
      generatedPackageFileNames.length === 1,
      'Generated more than one rpm package'
    );
    const generatedPackageFilePath = path.join(
      generatedArchDirPath,
      generatedPackageFileNames[0]
    );
    const outputRpmPackageFilePath = path.join(
      CONFIG.buildOutputPath,
      `atom.${generatedArch}.rpm`
    );
    task.log(
      `Copying "${generatedPackageFilePath}" into "${outputRpmPackageFilePath}"`
    );
    fs.copySync(generatedPackageFilePath, outputRpmPackageFilePath);
  }

  task.done();
};
