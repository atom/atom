require('colors');

const fs = require('fs');
const path = require('path');
const express = require('express');

const app = express();
const port = process.env.PORT || 3456;

// Load the metadata for the local build of Atom
const buildPath = path.resolve(__dirname, '..', '..', 'out');
const packageJsonPath = path.join(buildPath, 'app', 'package.json');
if (!fs.existsSync(buildPath) || !fs.existsSync(packageJsonPath)) {
  console.log(
    `This script requires a full Atom build with release packages for the current platform in the following path:\n    ${buildPath}\n`
  );
  if (process.platform === 'darwin') {
    console.log(
      `Run this command before trying again:\n    script/build --compress-artifacts --test-sign\n\n`
    );
  } else if (process.platform === 'win32') {
    console.log(
      `Run this command before trying again:\n    script/build --create-windows-installer\n\n`
    );
  }
  process.exit(1);
}

const appMetadata = require(packageJsonPath);
const versionMatch = appMetadata.version.match(/-(beta|nightly)\d+$/);
const releaseChannel = versionMatch ? versionMatch[1] : 'stable';

console.log(
  `Serving ${
    appMetadata.productName
  } release assets (channel = ${releaseChannel})\n`.green
);

function getMacZip(req, res) {
  console.log(`Received request for atom-mac.zip, sending it`);
  res.sendFile(path.join(buildPath, 'atom-mac.zip'));
}

function getMacUpdates(req, res) {
  if (req.query.version !== appMetadata.version) {
    const updateInfo = {
      name: appMetadata.version,
      pub_date: new Date().toISOString(),
      url: `http://localhost:${port}/mac/atom-mac.zip`,
      notes: '<p>No Details</p>'
    };

    console.log(
      `Received request for macOS updates (version = ${
        req.query.version
      }), sending\n`,
      updateInfo
    );
    res.json(updateInfo);
  } else {
    console.log(
      `Received request for macOS updates, sending 204 as Atom is up to date (version = ${
        req.query.version
      })`
    );
    res.sendStatus(204);
  }
}

function getReleasesFile(fileName) {
  return function(req, res) {
    console.log(
      `Received request for ${fileName}, version: ${req.query.version}`
    );
    if (req.query.version) {
      const versionMatch = (req.query.version || '').match(
        /-(beta|nightly)\d+$/
      );
      const versionChannel = (versionMatch && versionMatch[1]) || 'stable';
      if (releaseChannel !== versionChannel) {
        console.log(
          `Atom requested an update for version ${
            req.query.version
          } but the current release channel is ${releaseChannel}`
        );
        res.sendStatus(404);
        return;
      }
    }

    res.sendFile(path.join(buildPath, fileName));
  };
}

function getNupkgFile(is64bit) {
  return function(req, res) {
    let nupkgFile = req.params.nupkg;
    if (is64bit) {
      const nupkgMatch = nupkgFile.match(/atom-(.+)-(delta|full)\.nupkg/);
      if (nupkgMatch) {
        nupkgFile = `atom-x64-${nupkgMatch[1]}-${nupkgMatch[2]}.nupkg`;
      }
    }

    console.log(
      `Received request for ${req.params.nupkg}, sending ${nupkgFile}`
    );
    res.sendFile(path.join(buildPath, nupkgFile));
  };
}

if (process.platform === 'darwin') {
  app.get('/mac/atom-mac.zip', getMacZip);
  app.get('/api/updates', getMacUpdates);
} else if (process.platform === 'win32') {
  app.get('/api/updates/RELEASES', getReleasesFile('RELEASES'));
  app.get('/api/updates/:nupkg', getNupkgFile());
  app.get('/api/updates-x64/RELEASES', getReleasesFile('RELEASES-x64'));
  app.get('/api/updates-x64/:nupkg', getNupkgFile(true));
} else {
  console.log(
    `The current platform '${
      process.platform
    }' doesn't support Squirrel updates, exiting.`.red
  );
  process.exit(1);
}

app.listen(port, () => {
  console.log(
    `Run Atom with ATOM_UPDATE_URL_PREFIX="http://localhost:${port}" set to test updates!\n`
      .yellow
  );
});
