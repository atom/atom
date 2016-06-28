'use babel'
/* eslint-env jasmine */

import child_process from 'child_process'
import environmentHelpers from '../src/environment-helpers'
import os from 'os'

describe('Environment handling', () => {
  let originalEnv
  let options

  beforeEach(() => {
    originalEnv = process.env
    delete process._originalEnv
    options = {
      platform: process.platform,
      env: Object.assign({}, process.env)
    }
  })

  afterEach(() => {
    process.env = originalEnv
    delete process._originalEnv
  })

  describe('on macOS, when PWD is not set', () => {
    beforeEach(() => {
      options.platform = 'darwin'
    })

    describe('needsPatching', () => {
      it('returns true if PWD is unset', () => {
        delete options.env.PWD
        expect(environmentHelpers.needsPatching(options)).toBe(true)
        options.env.PWD = undefined
        expect(environmentHelpers.needsPatching(options)).toBe(true)
        options.env.PWD = null
        expect(environmentHelpers.needsPatching(options)).toBe(true)
        options.env.PWD = false
        expect(environmentHelpers.needsPatching(options)).toBe(true)
      })

      it('returns false if PWD is set', () => {
        options.env.PWD = 'xterm'
        expect(environmentHelpers.needsPatching(options)).toBe(false)
      })
    })

    describe('normalize', () => {
      it('changes process.env if PWD is unset', () => {
        if (process.platform === 'win32') {
          return
        }
        delete options.env.PWD
        environmentHelpers.normalize(options)
        expect(process._originalEnv).toBeDefined()
        expect(process._originalEnv).toBeTruthy()
        expect(process.env).toBeDefined()
        expect(process.env).toBeTruthy()
        expect(process.env.PWD).toBeDefined()
        expect(process.env.PWD).toBeTruthy()
        expect(process.env.PATH).toBeDefined()
        expect(process.env.PATH).toBeTruthy()
        expect(process.env.ATOM_HOME).toBeDefined()
        expect(process.env.ATOM_HOME).toBeTruthy()
      })
    })
  })

  describe('on a platform other than macOS', () => {
    beforeEach(() => {
      options.platform = 'penguin'
    })

    describe('needsPatching', () => {
      it('returns false if PWD is set or unset', () => {
        delete options.env.PWD
        expect(environmentHelpers.needsPatching(options)).toBe(false)
        options.env.PWD = undefined
        expect(environmentHelpers.needsPatching(options)).toBe(false)
        options.env.PWD = null
        expect(environmentHelpers.needsPatching(options)).toBe(false)
        options.env.PWD = false
        expect(environmentHelpers.needsPatching(options)).toBe(false)
        options.env.PWD = '/'
        expect(environmentHelpers.needsPatching(options)).toBe(false)
      })

      it('returns false for linux', () => {
        options.platform = 'linux'
        options.PWD = '/'
        expect(environmentHelpers.needsPatching(options)).toBe(false)
      })

      it('returns false for windows', () => {
        options.platform = 'win32'
        options.PWD = 'c:\\'
        expect(environmentHelpers.needsPatching(options)).toBe(false)
      })
    })

    describe('normalize', () => {
      it('does not change the environment', () => {
        if (process.platform === 'win32') {
          return
        }
        delete options.env.PWD
        environmentHelpers.normalize(options)
        expect(process._originalEnv).toBeUndefined()
        expect(process.env).toBeDefined()
        expect(process.env).toBeTruthy()
        expect(process.env.PATH).toBeDefined()
        expect(process.env.PATH).toBeTruthy()
        expect(process.env.PWD).toBeUndefined()
        expect(process.env.PATH).toBe(originalEnv.PATH)
        expect(process.env.ATOM_HOME).toBeDefined()
        expect(process.env.ATOM_HOME).toBeTruthy()
      })
    })
  })

  describe('getFromShell', () => {
    describe('when things are configured properly', () => {
      beforeEach(() => {
        spyOn(child_process, 'spawnSync').andReturn({
          stdout: 'FOO=BAR' + os.EOL + 'TERM=xterm-something' + os.EOL +
                  'PATH=/usr/bin:/bin:/usr/sbin:/sbin:/crazy/path'
        })
      })

      it('returns an object containing the information from the user\'s shell environment', () => {
        let env = environmentHelpers.getFromShell()
        expect(env.FOO).toEqual('BAR')
        expect(env.TERM).toEqual('xterm-something')
        expect(env.PATH).toEqual('/usr/bin:/bin:/usr/sbin:/sbin:/crazy/path')
      })
    })

    describe('when an error occurs launching the shell', () => {
      beforeEach(() => {
        spyOn(child_process, 'spawnSync').andReturn({
          error: new Error('testing when an error occurs')
        })
      })

      it('returns undefined', () => {
        expect(environmentHelpers.getFromShell()).toBeUndefined()
      })

      it('leaves the environment as-is when normalize() is called', () => {
        options.platform = 'darwin'
        delete options.env.PWD
        expect(environmentHelpers.needsPatching(options)).toBe(true)
        environmentHelpers.normalize(options)
        expect(process.env).toBeDefined()
        expect(process._originalEnv).toBeUndefined()
      })
    })
  })
})
