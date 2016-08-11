/** @babel */

import fs from 'fs-plus'
import path from 'path'
import temp from 'temp'
import AtomApplication from '../../src/main-process/atom-application'
import parseCommandLine from '../../src/main-process/parse-command-line'

const ATOM_RESOURCE_PATH = path.resolve(__dirname, '..', '..')

describe('AtomApplication', function () {
  let originalAtomHome, atomApplicationsToDestroy

  function buildAtomApplication () {
    const atomApplication = new AtomApplication({
      resourcePath: ATOM_RESOURCE_PATH,
      atomHomeDirPath: process.env.ATOM_HOME
    })
    atomApplicationsToDestroy.push(atomApplication)
    return atomApplication
  }

  beforeEach(function () {
    originalAtomHome = process.env.ATOM_HOME
    process.env.ATOM_HOME = temp.mkdirSync('atom-home')
    // Symlinking the compile cache into the temporary home dir makes the windows load much faster
    fs.symlinkSync(path.join(originalAtomHome, 'compile-cache'), path.join(process.env.ATOM_HOME, 'compile-cache'))
    atomApplicationsToDestroy = []
  })

  afterEach(function () {
    process.env.ATOM_HOME = originalAtomHome
    for (let atomApplication of atomApplicationsToDestroy) {
      atomApplication.destroy()
    }
  })

  describe('openWithOptions', function () {
    it('positions new windows at an offset distance from the previous window', async function () {
      this.timeout(20000)

      const atomApplication = buildAtomApplication()

      const window1 = atomApplication.openWithOptions(parseCommandLine([]))
      await window1.loadedPromise
      window1.browserWindow.setBounds({width: 400, height: 400, x: 0, y: 0})

      const window2 = atomApplication.openWithOptions(parseCommandLine([]))
      await window2.loadedPromise

      window1Dimensions = window1.getDimensions()
      window2Dimensions = window2.getDimensions()
      assert.isAbove(window2Dimensions.x, window1Dimensions.x)
      assert.isAbove(window2Dimensions.y, window1Dimensions.y)
    })
  })
})
