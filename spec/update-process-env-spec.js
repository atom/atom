/** @babel */
/* eslint-env jasmine */

import child_process from 'child_process'
import {updateProcessEnv, shellShouldBePatched} from '../src/update-process-env'
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
      process.env = {
        WILL_BE_DELETED: 'hi',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      }
      const initialProcessEnv = process.env

      updateProcessEnv({PWD: '/the/dir', KEY1: 'value1', KEY2: 'value2'})
      expect(process.env).toEqual({
        PWD: '/the/dir',
        KEY1: 'value1',
        KEY2: 'value2',
        NODE_ENV: 'the-node-env',
        NODE_PATH: '/the/node/path',
        ATOM_HOME: '/the/atom/home'
      })

      // See #11302. On Windows, `process.env` is a magic object that offers
      // case-insensitive environment variable matching, so we cannot replace it
      // with another object.
      expect(process.env).toBe(initialProcessEnv)
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
        expect(process.env).toEqual({
          FOO: 'BAR=BAZ=QUUX',
          TERM: 'xterm-something',
          PATH: '/usr/bin:/bin:/usr/sbin:/sbin:/crazy/path'
        })

        // Doesn't error
        updateProcessEnv(null)
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

    describe('shells on osx', function () {
      it('shellShouldBePatched() returns the shell when the shell should be patched', function () {
        process.platform = 'darwin'
        let shellsToTest = new Set([
          '/bin/sh',
          '/usr/local/bin/sh',
          '/bin/bash',
          '/usr/local/bin/bash',
          '/bin/zsh',
          '/usr/local/bin/zsh',
          '/bin/fish',
          '/usr/local/bin/fish'
        ])
        for (let shell of shellsToTest) {
          process.env.SHELL = shell
          expect(shellShouldBePatched()).toBe(shell)
        }
      })

      it('shellShouldBePatched() returns false when the shell should not be patched', function () {
        process.platform = 'darwin'
        let shellsToTest = new Set([
          '/bin/unsupported',
          '/bin/shh',
          '/bin/tcsh',
          '/usr/csh'
        ])
        for (let shell of shellsToTest) {
          process.env.SHELL = shell
          let result = shellShouldBePatched()
          console.log(result)
          expect(result).toBe(false)
        }
      })
    })
  })
})
