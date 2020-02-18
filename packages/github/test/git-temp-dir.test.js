import fs from 'fs-extra';
import path from 'path';

import GitTempDir, {BIN_SCRIPTS} from '../lib/git-temp-dir';

describe('GitTempDir', function() {
  it('ensures that a temporary directory is populated', async function() {
    const tempDir = new GitTempDir();
    await tempDir.ensure();

    const root = tempDir.getRootPath();
    for (const scriptName in BIN_SCRIPTS) {
      const script = BIN_SCRIPTS[scriptName];
      const stat = await fs.stat(path.join(root, script));
      assert.isTrue(stat.isFile());
      if (script.endsWith('.sh') && process.platform !== 'win32') {
        // eslint-disable-next-line no-bitwise
        assert.isTrue((stat.mode & fs.constants.S_IXUSR) === fs.constants.S_IXUSR);
      }
    }

    await tempDir.ensure();
    assert.strictEqual(root, tempDir.getRootPath());
  });

  it('generates getters for script paths', async function() {
    const tempDir = new GitTempDir();
    await tempDir.ensure();

    const scriptPath = tempDir.getScriptPath('git-credential-atom.js');
    assert.isTrue(scriptPath.startsWith(tempDir.getRootPath()));
    assert.isTrue(scriptPath.endsWith('git-credential-atom.js'));

    assert.strictEqual(tempDir.getCredentialHelperJs(), tempDir.getScriptPath('git-credential-atom.js'));
    assert.strictEqual(tempDir.getCredentialHelperSh(), tempDir.getScriptPath('git-credential-atom.sh'));
    assert.strictEqual(tempDir.getAskPassJs(), tempDir.getScriptPath('git-askpass-atom.js'));
  });

  it('fails when the temp dir is not yet created', function() {
    const tempDir = new GitTempDir();
    assert.throws(() => tempDir.getAskPassJs(), /uninitialized GitTempDir/);
  });

  if (process.platform === 'win32') {
    it('generates options to create a TCP socket on an unbound port', async function() {
      const tempDir = new GitTempDir();
      await tempDir.ensure();

      assert.deepEqual(tempDir.getSocketOptions(), {port: 0, host: 'localhost'});
    });
  } else {
    it('generates a socket path within the directory', async function() {
      const tempDir = new GitTempDir();
      await tempDir.ensure();

      const opts = tempDir.getSocketOptions();
      assert.isTrue(opts.path.startsWith(tempDir.getRootPath()));
    });
  }

  it('deletes the directory on dispose', async function() {
    const tempDir = new GitTempDir();
    await tempDir.ensure();

    const beforeStat = await fs.stat(tempDir.getRootPath());
    assert.isTrue(beforeStat.isDirectory());

    await tempDir.dispose();

    await assert.isRejected(fs.stat(tempDir.getRootPath()), /ENOENT/);
  });
});
