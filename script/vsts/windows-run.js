// NOTE: This script is only used as part of the Windows build on VSTS,
//       see script/vsts/platforms/windows.yml for its usage
const fs = require('fs');
const path = require('path');
const download = require('download');
const childProcess = require('child_process');

const nodeVersion = '8.9.3';
const nodeFileName = `node-v${nodeVersion}-win-x86`;
const extractedNodePath = `c:\\tmp\\${nodeFileName}`;

async function downloadX86Node() {
  if (!fs.existsSync(extractedNodePath)) {
    await download(
      `https://nodejs.org/download/release/v${nodeVersion}/${nodeFileName}.zip`,
      'c:\\tmp',
      { extract: true }
    );
  }
}

async function runScriptForBuildArch() {
  if (process.argv.length <= 2) {
    console.error('A target script must be specified');
    process.exit(1);
  }

  let exitCode = 0;
  if (process.env.BUILD_ARCH === 'x86') {
    await downloadX86Node();

    // Write out a launcher script that will launch the requested script
    // using the 32-bit cmd.exe and 32-bit Node.js
    const runScript = `@echo off\r\nCALL ${extractedNodePath}\\nodevars.bat\r\nCALL ${path.resolve(
      process.argv[2]
    )} ${process.argv.splice(3).join(' ')}`;
    const runScriptPath = 'c:\\tmp\\run.cmd';
    fs.writeFileSync(runScriptPath, runScript);
    exitCode = childProcess.spawnSync(
      'C:\\Windows\\SysWOW64\\cmd.exe',
      ['/C', runScriptPath],
      { env: process.env, stdio: 'inherit' }
    ).status;
  } else {
    exitCode = childProcess.spawnSync(process.argv[2], process.argv.splice(3), {
      env: process.env,
      stdio: 'inherit'
    }).status;
  }

  process.exit(exitCode);
}

runScriptForBuildArch();
