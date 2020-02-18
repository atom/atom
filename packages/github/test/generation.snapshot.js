// Ensure that all of our source can be snapshotted correctly.

import fs from 'fs-extra';
import vm from 'vm';
import path from 'path';
import temp from 'temp';
import globby from 'globby';
import childProcess from 'child_process';
import electronLink from 'electron-link';

import {transpile} from './helpers';

describe('snapshot generation', function() {
  it('successfully preprocesses and snapshots the package', async function() {
    this.timeout(60000);

    const baseDirPath = path.resolve(__dirname, '..');
    const workDir = temp.mkdirSync('github-snapshot-');
    const snapshotScriptPath = path.join(workDir, 'snapshot-source.js');
    const snapshotBlobPath = path.join(workDir, 'snapshot-blob.bin');
    const coreModules = new Set(['electron', 'atom']);

    const sourceFiles = await globby(['lib/**/*.js'], {cwd: baseDirPath});
    await transpile(...sourceFiles);

    await fs.copyFile(
      path.resolve(__dirname, '../package.json'),
      path.resolve(__dirname, 'output/transpiled/package.json'),
    );

    const {snapshotScript} = await electronLink({
      baseDirPath,
      mainPath: path.join(__dirname, 'output/transpiled/lib/index.js'),
      cachePath: path.join(__dirname, 'output/snapshot-cache'),
      shouldExcludeModule: ({requiringModulePath, requiredModulePath}) => {
        const requiredModuleRelativePath = path.relative(baseDirPath, requiredModulePath);

        if (requiredModulePath.endsWith('.node')) { return true; }
        if (coreModules.has(requiredModulePath)) { return true; }
        if (requiredModuleRelativePath.startsWith(path.join('node_modules/dugite'))) { return true; }
        if (requiredModuleRelativePath.endsWith(path.join('node_modules/temp/lib/temp.js'))) { return true; }
        if (requiredModuleRelativePath.endsWith(path.join('node_modules/graceful-fs/graceful-fs.js'))) { return true; }
        if (requiredModuleRelativePath.endsWith(path.join('node_modules/fs-extra/lib/index.js'))) { return true; }
        if (requiredModuleRelativePath.endsWith(path.join('node_modules/superstring/index.js'))) { return true; }

        return false;
      },
    });

    await fs.writeFile(snapshotScriptPath, snapshotScript, 'utf8');

    vm.runInNewContext(snapshotScript, undefined, {filename: snapshotScriptPath, displayErrors: true});

    childProcess.execFileSync(
      path.join(__dirname, '../node_modules/electron-mksnapshot/bin/mksnapshot'),
      ['--no-use_ic', snapshotScriptPath, '--startup_blob', snapshotBlobPath],
    );
  });
});
