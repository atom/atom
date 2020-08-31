const { spawn } = require('child_process');

const electronVersion = require('./config').appMetadata.electronVersion;

if (process.env.ELECTRON_CUSTOM_VERSION !== electronVersion) {
  const electronEnv = process.env.ELECTRON_CUSTOM_VERSION;
  console.info(
    `env var ELECTRON_CUSTOM_VERSION is not set,\n` +
      `or doesn't match electronVersion in ../package.json.\n` +
      `(is: "${electronEnv}", wanted: "${electronVersion}").\n` +
      `Setting, and re-downloading chromedriver and mksnapshot.\n`
  );

  process.env.ELECTRON_CUSTOM_VERSION = electronVersion;
  const downloadChromedriverPath = require.resolve(
    'electron-chromedriver/download-chromedriver.js'
  );
  const downloadMksnapshotPath = require.resolve(
    'electron-mksnapshot/download-mksnapshot.js'
  );
  const downloadChromedriver = spawn('node', [downloadChromedriverPath]);
  const downloadMksnapshot = spawn('node', [downloadMksnapshotPath]);
  var exitStatus;

  downloadChromedriver.on('close', code => {
    if (code === 0) {
      exitStatus = 'success';
    } else {
      exitStatus = 'error';
    }

    console.info(
      `info: Done re-downloading chromedriver. Status: ${exitStatus}`
    );
  });

  downloadMksnapshot.on('close', code => {
    if (code === 0) {
      exitStatus = 'success';
    } else {
      exitStatus = 'error';
    }

    console.info(`info: Done re-downloading mksnapshot. Status: ${exitStatus}`);
  });
} else {
  console.info(
    'info: env var "ELECTRON_CUSTOM_VERSION" is already set correctly.\n(No need to re-download chromedriver or mksnapshot). Skipping.\n'
  );
}
