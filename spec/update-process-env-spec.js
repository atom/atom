/** @babel */
<<<<<<< HEAD
/* eslint-env jasmine */

import path from 'path'
import temp from 'temp'
import child_process from 'child_process'
import {updateProcessEnv, shouldGetEnvFromShell} from '../src/update-process-env'
import dedent from 'dedent'

describe('updateProcessEnv(launchEnv)', function () {
  let originalProcessEnv, originalProcessPlatform

  beforeEach(function () {
    originalProcessEnv = process.env
    originalProcessPlatform = process.platform
    process.env = {}
  })

  afterEach(function () {
    process.env = originalProcessEnv
    process.platform = originalProcessPlatform
  })

  describe('when the launch environment appears to come from a shell', function () {
    it('updates process.env to match the launch environment', function () {
=======

import path from 'path';
import childProcess from 'child_process';
import {
  updateProcessEnv,
  shouldGetEnvFromShell
} from '../src/update-process-env';
import dedent from 'dedent';
import mockSpawn from 'mock-spawn';
const temp = require('temp').track();

describe('updateProcessEnv(launchEnv)', function() {
  let originalProcessEnv, originalProcessPlatform, originalSpawn, spawn;

  beforeEach(function() {
    originalSpawn = childProcess.spawn;
    spawn = mockSpawn();
    childProcess.spawn = spawn;
    originalProcessEnv = process.env;
    originalProcessPlatform = process.platform;
    process.env = {};
  });

  afterEach(function() {
    if (originalSpawn) {
      childProcess.spawn = originalSpawn;
    }
    process.env = originalProcessEnv;
    process.platform = originalProcessPlatform;
    try {
      temp.cleanupSync();
    } catch (e) {
      // Do nothing
    }
  });

  describe('when the launch environment appears to come from a shell', function() {
    it('updates process.env to match the launch environment because PWD is set', async function() {
>>>>>>> master
      process.env = {
        WILL_BE_DELETED: 'hi',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
<<<<<<< HEAD
      }
      const initialProcessEnv = process.env

      updateProcessEnv({PWD: '/the/dir', KEY1: 'value1', KEY2: 'value2'})
      expect(process.env).toEqual({
        PWD: '/the/dir',
=======
      };

      const initialProcessEnv = process.env;

      await updateProcessEnv({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PWD: '/the/dir',
        TERM: 'xterm-something',
        KEY1: 'value1',
        KEY2: 'value2'
      });
      expect(process.env).toEqual({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PWD: '/the/dir',
        TERM: 'xterm-something',
        KEY1: 'value1',
        KEY2: 'value2',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      });

      // See #11302. On Windows, `process.env` is a magic object that offers
      // case-insensitive environment variable matching, so we cannot replace it
      // with another object.
      expect(process.env).toBe(initialProcessEnv);
    });

    it('updates process.env to match the launch environment because PROMPT is set', async function() {
      process.env = {
        WILL_BE_DELETED: 'hi',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      };

      const initialProcessEnv = process.env;

      await updateProcessEnv({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PROMPT: '$P$G',
        KEY1: 'value1',
        KEY2: 'value2'
      });
      expect(process.env).toEqual({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PROMPT: '$P$G',
        KEY1: 'value1',
        KEY2: 'value2',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      });

      // See #11302. On Windows, `process.env` is a magic object that offers
      // case-insensitive environment variable matching, so we cannot replace it
      // with another object.
      expect(process.env).toBe(initialProcessEnv);
    });

    it('updates process.env to match the launch environment because PSModulePath is set', async function() {
      process.env = {
        WILL_BE_DELETED: 'hi',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      };

      const initialProcessEnv = process.env;

      await updateProcessEnv({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PSModulePath:
          'C:\\Program Files\\WindowsPowerShell\\Modules;C:\\WINDOWS\\system32\\WindowsPowerShell\\v1.0\\Modules\\',
        KEY1: 'value1',
        KEY2: 'value2'
      });
      expect(process.env).toEqual({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PSModulePath:
          'C:\\Program Files\\WindowsPowerShell\\Modules;C:\\WINDOWS\\system32\\WindowsPowerShell\\v1.0\\Modules\\',
>>>>>>> master
        KEY1: 'value1',
        KEY2: 'value2',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
<<<<<<< HEAD
      })
=======
      });
>>>>>>> master

      // See #11302. On Windows, `process.env` is a magic object that offers
      // case-insensitive environment variable matching, so we cannot replace it
      // with another object.
<<<<<<< HEAD
      expect(process.env).toBe(initialProcessEnv)
    })

    it('allows ATOM_HOME to be overwritten only if the new value is a valid path', function () {
      newAtomHomePath = temp.mkdirSync('atom-home')
=======
      expect(process.env).toBe(initialProcessEnv);
    });

    it('allows ATOM_HOME to be overwritten only if the new value is a valid path', async function() {
      let newAtomHomePath = temp.mkdirSync('atom-home');
>>>>>>> master

      process.env = {
        WILL_BE_DELETED: 'hi',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
<<<<<<< HEAD
      }

      updateProcessEnv({PWD: '/the/dir'})
      expect(process.env).toEqual({
        PWD: '/the/dir',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      })

      updateProcessEnv({PWD: '/the/dir', ATOM_HOME: path.join(newAtomHomePath, 'non-existent')})
      expect(process.env).toEqual({
=======
      };

      await updateProcessEnv({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PWD: '/the/dir'
      });
      expect(process.env).toEqual({
        PWD: '/the/dir',
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      });

      await updateProcessEnv({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PWD: '/the/dir',
        ATOM_HOME: path.join(newAtomHomePath, 'non-existent')
      });
      expect(process.env).toEqual({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
>>>>>>> master
        PWD: '/the/dir',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
<<<<<<< HEAD
      })


      updateProcessEnv({PWD: '/the/dir', ATOM_HOME: newAtomHomePath})
      expect(process.env).toEqual({
=======
      });

      await updateProcessEnv({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PWD: '/the/dir',
        ATOM_HOME: newAtomHomePath
      });
      expect(process.env).toEqual({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
>>>>>>> master
        PWD: '/the/dir',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: newAtomHomePath
<<<<<<< HEAD
      })
    })
  })

  describe('when the launch environment does not come from a shell', function () {
    describe('on osx', function () {
      it('updates process.env to match the environment in the user\'s login shell', function () {
        process.platform = 'darwin'
        process.env.SHELL = '/my/custom/bash'

        spyOn(child_process, 'spawnSync').andReturn({
          stdout: dedent`
            FOO=BAR=BAZ=QUUX
            TERM=xterm-something
            PATH=/usr/bin:/bin:/usr/sbin:/sbin:/crazy/path
          `
        })

        updateProcessEnv(process.env)
        expect(child_process.spawnSync.mostRecentCall.args[0]).toBe('/my/custom/bash')
=======
      });
    });

    it('allows ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT to be preserved if set', async function() {
      process.env = {
        WILL_BE_DELETED: 'hi',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      };

      await updateProcessEnv({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PWD: '/the/dir',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      });
      expect(process.env).toEqual({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PWD: '/the/dir',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      });

      await updateProcessEnv({
        PWD: '/the/dir',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      });
      expect(process.env).toEqual({
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        PWD: '/the/dir',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      });
    });

    it('allows an existing env variable to be updated', async function() {
      process.env = {
        WILL_BE_UPDATED: 'old-value',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      };

      await updateProcessEnv(process.env);
      expect(process.env).toEqual(process.env);

      let updatedEnv = {
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
        WILL_BE_UPDATED: 'new-value',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home',
        PWD: '/the/dir'
      };

      await updateProcessEnv(updatedEnv);
      expect(process.env).toEqual(updatedEnv);
    });
  });

  describe('when the launch environment does not come from a shell', function() {
    describe('on macOS', function() {
      it("updates process.env to match the environment in the user's login shell", async function() {
        if (process.platform === 'win32') return; // TestsThatFailOnWin32

        process.platform = 'darwin';
        process.env.SHELL = '/my/custom/bash';
        spawn.setDefault(
          spawn.simple(
            0,
            dedent`
          FOO=BAR=BAZ=QUUX
          TERM=xterm-something
          PATH=/usr/bin:/bin:/usr/sbin:/sbin:/crazy/path
        `
          )
        );
        await updateProcessEnv(process.env);
        expect(spawn.calls.length).toBe(1);
        expect(spawn.calls[0].command).toBe('/my/custom/bash');
        expect(spawn.calls[0].args).toEqual(['-ilc', 'command env']);
>>>>>>> master
        expect(process.env).toEqual({
          FOO: 'BAR=BAZ=QUUX',
          TERM: 'xterm-something',
          PATH: '/usr/bin:/bin:/usr/sbin:/sbin:/crazy/path'
<<<<<<< HEAD
        })
      })
    })

    describe('not on osx', function () {
      it('does not update process.env', function () {
        process.platform = 'win32'
        spyOn(child_process, 'spawnSync')
        process.env = {FOO: 'bar'}

        updateProcessEnv(process.env)
        expect(child_process.spawnSync).not.toHaveBeenCalled()
        expect(process.env).toEqual({FOO: 'bar'})
      })
    })

    describe('shouldGetEnvFromShell()', function () {
      it('returns the shell when the shell should be patched', function () {
        process.platform = 'darwin'
        expect(shouldGetEnvFromShell('/bin/sh')).toBe(true)
        expect(shouldGetEnvFromShell('/usr/local/bin/sh')).toBe(true)
        expect(shouldGetEnvFromShell('/bin/bash')).toBe(true)
        expect(shouldGetEnvFromShell('/usr/local/bin/bash')).toBe(true)
        expect(shouldGetEnvFromShell('/bin/zsh')).toBe(true)
        expect(shouldGetEnvFromShell('/usr/local/bin/zsh')).toBe(true)
        expect(shouldGetEnvFromShell('/bin/fish')).toBe(true)
        expect(shouldGetEnvFromShell('/usr/local/bin/fish')).toBe(true)
      })

      it('returns false when the shell should not be patched', function () {
        process.platform = 'darwin'
        expect(shouldGetEnvFromShell('/bin/unsupported')).toBe(false)
        expect(shouldGetEnvFromShell('/bin/shh')).toBe(false)
        expect(shouldGetEnvFromShell('/bin/tcsh')).toBe(false)
        expect(shouldGetEnvFromShell('/usr/csh')).toBe(false)
      })

      it('returns false when the shell is undefined or empty', function () {
        process.platform = 'darwin'
        expect(shouldGetEnvFromShell(undefined)).toBe(false)
        expect(shouldGetEnvFromShell('')).toBe(false)
      })
    })
  })
})
=======
        });

        // Doesn't error
        await updateProcessEnv(null);
      });
    });

    describe('on linux', function() {
      it("updates process.env to match the environment in the user's login shell", async function() {
        if (process.platform === 'win32') return; // TestsThatFailOnWin32

        process.platform = 'linux';
        process.env.SHELL = '/my/custom/bash';
        spawn.setDefault(
          spawn.simple(
            0,
            dedent`
          FOO=BAR=BAZ=QUUX
          TERM=xterm-something
          PATH=/usr/bin:/bin:/usr/sbin:/sbin:/crazy/path
        `
          )
        );
        await updateProcessEnv(process.env);
        expect(spawn.calls.length).toBe(1);
        expect(spawn.calls[0].command).toBe('/my/custom/bash');
        expect(spawn.calls[0].args).toEqual(['-ilc', 'command env']);
        expect(process.env).toEqual({
          FOO: 'BAR=BAZ=QUUX',
          TERM: 'xterm-something',
          PATH: '/usr/bin:/bin:/usr/sbin:/sbin:/crazy/path'
        });

        // Doesn't error
        await updateProcessEnv(null);
      });
    });

    describe('on windows', function() {
      it('does not update process.env', async function() {
        process.platform = 'win32';
        spyOn(childProcess, 'spawn');
        process.env = { FOO: 'bar' };

        await updateProcessEnv(process.env);
        expect(childProcess.spawn).not.toHaveBeenCalled();
        expect(process.env).toEqual({ FOO: 'bar' });
      });
    });

    describe('shouldGetEnvFromShell()', function() {
      it('indicates when the environment should be fetched from the shell', function() {
        if (process.platform === 'win32') return; // TestsThatFailOnWin32

        process.platform = 'darwin';
        expect(shouldGetEnvFromShell({ SHELL: '/bin/sh' })).toBe(true);
        expect(shouldGetEnvFromShell({ SHELL: '/usr/local/bin/sh' })).toBe(
          true
        );
        expect(shouldGetEnvFromShell({ SHELL: '/bin/bash' })).toBe(true);
        expect(shouldGetEnvFromShell({ SHELL: '/usr/local/bin/bash' })).toBe(
          true
        );
        expect(shouldGetEnvFromShell({ SHELL: '/bin/zsh' })).toBe(true);
        expect(shouldGetEnvFromShell({ SHELL: '/usr/local/bin/zsh' })).toBe(
          true
        );
        expect(shouldGetEnvFromShell({ SHELL: '/bin/fish' })).toBe(true);
        expect(shouldGetEnvFromShell({ SHELL: '/usr/local/bin/fish' })).toBe(
          true
        );
        process.platform = 'linux';
        expect(shouldGetEnvFromShell({ SHELL: '/bin/sh' })).toBe(true);
        expect(shouldGetEnvFromShell({ SHELL: '/usr/local/bin/sh' })).toBe(
          true
        );
        expect(shouldGetEnvFromShell({ SHELL: '/bin/bash' })).toBe(true);
        expect(shouldGetEnvFromShell({ SHELL: '/usr/local/bin/bash' })).toBe(
          true
        );
        expect(shouldGetEnvFromShell({ SHELL: '/bin/zsh' })).toBe(true);
        expect(shouldGetEnvFromShell({ SHELL: '/usr/local/bin/zsh' })).toBe(
          true
        );
        expect(shouldGetEnvFromShell({ SHELL: '/bin/fish' })).toBe(true);
        expect(shouldGetEnvFromShell({ SHELL: '/usr/local/bin/fish' })).toBe(
          true
        );
      });

      it('returns false when the environment indicates that Atom was launched from a shell', function() {
        process.platform = 'darwin';
        expect(
          shouldGetEnvFromShell({
            ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
            SHELL: '/bin/sh'
          })
        ).toBe(false);
        process.platform = 'linux';
        expect(
          shouldGetEnvFromShell({
            ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT: 'true',
            SHELL: '/bin/sh'
          })
        ).toBe(false);
      });

      it('returns false when the shell is undefined or empty', function() {
        process.platform = 'darwin';
        expect(shouldGetEnvFromShell(undefined)).toBe(false);
        expect(shouldGetEnvFromShell({})).toBe(false);

        process.platform = 'linux';
        expect(shouldGetEnvFromShell(undefined)).toBe(false);
        expect(shouldGetEnvFromShell({})).toBe(false);
      });
    });
  });
});
>>>>>>> master
