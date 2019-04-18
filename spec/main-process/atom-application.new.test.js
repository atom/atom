/* globals assert */

const path = require('path')
const {EventEmitter} = require('events')
const temp = require('temp').track()
const fs = require('fs-plus')
const {sandbox} = require('sinon')

const AtomApplication = require('../../src/main-process/atom-application')
const parseCommandLine = require('../../src/main-process/parse-command-line')

describe('AtomApplication', function () {
  let scenario, sinon

  beforeEach(async function () {
    sinon = sandbox.create()
    scenario = await LaunchScenario.create(sinon)
  })

  afterEach(async function () {
    await scenario.destroy()
    sinon.restore()
  })

  describe('command-line interface behavior', function () {
    describe('with no open windows', function () {
      // This is also the case when a user clicks on a file in their file manager
      it('opens a file', async function () {
        await scenario.open(parseCommandLine(['a/1.md']))
        await scenario.assert('[_ 1.md]')
      })

      // This is also the case when a user clicks on a folder in their file manager
      // (or, on macOS, drags the folder to Atom in their doc)
      it('opens a directory', async function () {
        await scenario.open(parseCommandLine(['a']))
        await scenario.assert('[a _]')
      })

      it('opens a file with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'a/1.md']))
        await scenario.assert('[_ 1.md]')
      })

      it('opens a directory with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'a']))
        await scenario.assert('[a _]')
      })

      it('opens a file with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'a/1.md']))
        await scenario.assert('[_ 1.md]')
      })

      it('opens a directory with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'a']))
        await scenario.assert('[a _]')
      })
    })

    describe('with one empty window', function () {
      beforeEach(async function () {
        await scenario.preconditions('[_ _]')
      })

      // This is also the case when a user clicks on a file in their file manager
      it('opens a file', async function () {
        await scenario.open(parseCommandLine(['a/1.md']))
        await scenario.assert('[_ 1.md]')
      })

      // This is also the case when a user clicks on a folder in their file manager
      it('opens a directory', async function () {
        await scenario.open(parseCommandLine(['a']))
        await scenario.assert('[a _]')
      })

      it('opens a file with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'a/1.md']))
        await scenario.assert('[_ 1.md]')
      })

      it('opens a directory with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'a']))
        await scenario.assert('[a _]')
      })

      it('opens a file with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'a/1.md']))
        await scenario.assert('[_ _] [_ 1.md]')
      })

      it('opens a directory with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'a']))
        await scenario.assert('[_ _] [a _]')
      })
    })

    describe('with one window that has a project root', function () {
      beforeEach(async function () {
        await scenario.preconditions('[a _]')
      })

      // This is also the case when a user clicks on a file within the project root in their file manager
      it('opens a file within the project root', async function () {
        await scenario.open(parseCommandLine(['a/1.md']))
        await scenario.assert('[a 1.md]')
      })

      // This is also the case when a user clicks on a project root folder in their file manager
      it('opens a directory that matches the project root', async function () {
        await scenario.open(parseCommandLine(['a']))
        await scenario.assert('[a _]')
      })

      // This is also the case when a user clicks on a file outside the project root in their file manager
      it('opens a file outside the project root', async function () {
        await scenario.open(parseCommandLine(['b/2.md']))
        await scenario.assert('[a 2.md]')
      })

      // This is also the case when a user clicks on a new folder in their file manager
      it('opens a directory other than the project root', async function () {
        await scenario.open(parseCommandLine(['b']))
        await scenario.assert('[a _] [b _]')
      })

      it('opens a file within the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'a/1.md']))
        await scenario.assert('[a 1.md]')
      })

      it('opens a directory that matches the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'a']))
        await scenario.assert('[a _]')
      })

      it('opens a file outside the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'b/2.md']))
        await scenario.assert('[a 2.md]')
      })

      it('opens a directory other than the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'b']))
        await scenario.assert('[a,b _]')
      })

      it('opens a file within the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'a/1.md']))
        await scenario.assert('[a _] [_ 1.md]')
      })

      it('opens a directory that matches the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'a']))
        await scenario.assert('[a _] [a _]')
      })

      it('opens a file outside the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'b/2.md']))
        await scenario.assert('[a _] [_ 2.md]')
      })

      it('opens a directory other than the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'b']))
        await scenario.assert('[a _] [b _]')
      })
    })

    describe('with two windows, one with a project root and one empty', function () {
      beforeEach(async function () {
        await scenario.preconditions('[a _] [_ _]')
      })

      // This is also the case when a user clicks on a file within the project root in their file manager
      it('opens a file within the project root', async function () {
        await scenario.open(parseCommandLine(['a/1.md']))
        await scenario.assert('[a 1.md] [_ _]')
      })

      // This is also the case when a user clicks on a project root folder in their file manager
      it('opens a directory that matches the project root', async function () {
        await scenario.open(parseCommandLine(['a']))
        await scenario.assert('[a _] [_ _]')
      })

      // This is also the case when a user clicks on a file outside the project root in their file manager
      it('opens a file outside the project root', async function () {
        await scenario.open(parseCommandLine(['b/2.md']))
        await scenario.assert('[a _] [_ 2.md]')
      })

      // This is also the case when a user clicks on a new folder in their file manager
      it('opens a directory other than the project root', async function () {
        await scenario.open(parseCommandLine(['b']))
        await scenario.assert('[a _] [b _]')
      })

      it('opens a file within the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'a/1.md']))
        await scenario.assert('[a 1.md] [_ _]')
      })

      it('opens a directory that matches the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'a']))
        await scenario.assert('[a _] [_ _]')
      })

      it('opens a file outside the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'b/2.md']))
        await scenario.assert('[a _] [_ 2.md]')
      })

      it('opens a directory other than the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'b']))
        await scenario.assert('[a _] [b _]')
      })

      it('opens a file within the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'a/1.md']))
        await scenario.assert('[a _] [_ _] [_ 1.md]')
      })

      it('opens a directory that matches the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'a']))
        await scenario.assert('[a _] [_ _] [a _]')
      })

      it('opens a file outside the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'b/2.md']))
        await scenario.assert('[a _] [_ _] [_ 2.md]')
      })

      it('opens a directory other than the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'b']))
        await scenario.assert('[a _] [_ _] [b _]')
      })
    })

    describe('with two windows, one empty and one with a project root', function () {
      beforeEach(async function () {
        await scenario.preconditions('[_ _] [a _]')
      })

      // This is also the case when a user clicks on a file within the project root in their file manager
      it('opens a file within the project root', async function () {
        await scenario.open(parseCommandLine(['a/1.md']))
        await scenario.assert('[_ _] [a 1.md]')
      })

      // This is also the case when a user clicks on a project root folder in their file manager
      it('opens a directory that matches the project root', async function () {
        await scenario.open(parseCommandLine(['a']))
        await scenario.assert('[_ _] [a _]')
      })

      // This is also the case when a user clicks on a file outside the project root in their file manager
      it('opens a file outside the project root', async function () {
        await scenario.open(parseCommandLine(['b/2.md']))
        await scenario.assert('[_ 2.md] [a _]')
      })

      // This is also the case when a user clicks on a new folder in their file manager
      it('opens a directory other than the project root', async function () {
        await scenario.open(parseCommandLine(['b']))
        await scenario.assert('[b _] [a _]')
      })

      it('opens a file within the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'a/1.md']))
        await scenario.assert('[_ _] [a 1.md]')
      })

      it('opens a directory that matches the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'a']))
        await scenario.assert('[_ _] [a _]')
      })

      it('opens a file outside the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'b/2.md']))
        await scenario.assert('[_ _] [a 2.md]')
      })

      it('opens a directory other than the project root with --add', async function () {
        await scenario.open(parseCommandLine(['--add', 'b']))
        await scenario.assert('[_ _] [a,b _]')
      })

      it('opens a file within the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'a/1.md']))
        await scenario.assert('[_ _] [a _] [_ 1.md]')
      })

      it('opens a directory that matches the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'a']))
        await scenario.assert('[_ _] [a _] [a _]')
      })

      it('opens a file outside the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'b/2.md']))
        await scenario.assert('[_ _] [a _] [_ 2.md]')
      })

      it('opens a directory other than the project root with --new-window', async function () {
        await scenario.open(parseCommandLine(['--new-window', 'b']))
        await scenario.assert('[_ _] [a _] [b _]')
      })
    })
  })
})

class StubWindow extends EventEmitter {
  constructor (sinon, loadSettings, options) {
    super()

    this.loadSettings = loadSettings

    this._dimensions = {x: 100, y: 100}
    this._position = {x: 0, y: 0}
    this._locations = []
    this._rootPaths = new Set()
    this._editorPaths = new Set()

    let resolveClosePromise
    this.closedPromise = new Promise(resolve => { resolveClosePromise = resolve })

    this.minimize = sinon.spy()
    this.maximize = sinon.spy()
    this.center = sinon.spy()
    this.focus = sinon.spy()
    this.show = sinon.spy()
    this.hide = sinon.spy()
    this.prepareToUnload = sinon.spy()
    this.close = resolveClosePromise

    this.replaceEnvironment = sinon.spy()
    this.disableZoom = sinon.spy()

    this.isFocused = sinon.stub().returns(options.isFocused !== undefined ? options.isFocused : false)
    this.isMinimized = sinon.stub().returns(options.isMinimized !== undefined ? options.isMinimized : false)
    this.isMaximized = sinon.stub().returns(options.isMaximized !== undefined ? options.isMaximized : false)

    this.sendURIMessage = sinon.spy()
    this.didChangeUserSettings = sinon.spy()
    this.didFailToReadUserSettings = sinon.spy()

    this.isSpec = loadSettings.isSpec !== undefined ? loadSettings.isSpec : false
    this.devMode = loadSettings.devMode !== undefined ? loadSettings.devMode : false
    this.safeMode = loadSettings.safeMode !== undefined ? loadSettings.safeMode : false

    this.browserWindow = new EventEmitter()
    this.browserWindow.webContents = new EventEmitter()

    const {locationsToOpen} = this.loadSettings
    if (!(locationsToOpen.length === 1 && locationsToOpen[0].pathToOpen == null) && !this.isSpec) {
      this.openLocations(locationsToOpen)
    }
  }

  openPath (pathToOpen, initialLine, initialColumn) {
    return this.openLocations([{pathToOpen, initialLine, initialColumn}])
  }

  openLocations (locations) {
    this._locations.push(...locations)
    for (const location of locations) {
      if (location.pathToOpen) {
        if (location.isDirectory) {
          this._rootPaths.add(location.pathToOpen)
        } else if (location.isFile) {
          this._editorPaths.add(location.pathToOpen)
        }
      }
    }
    this.emit('window:locations-opened')
  }

  setSize (x, y) {
    this._dimensions = {x, y}
  }

  setPosition (x, y) {
    this._position = {x, y}
  }

  hasProjectPaths () {
    return this._rootPaths.size > 0
  }

  containsLocations (locations) {
    return locations.every(location => this.containsLocation(location))
  }

  containsLocation (location) {
    if (!location.pathToOpen) return false

    return Array.from(this._rootPaths).some(projectPath => {
      if (location.pathToOpen === projectPath) return true
      if (location.pathToOpen.startsWith(path.join(projectPath, path.sep))) {
        if (!location.exists) return true
        if (!location.isDirectory) return true
      }
      return false
    })
  }

  getDimensions () {
    return this._dimensions
  }
}

class LaunchScenario {
  static async create (sandbox) {
    const scenario = new this(sandbox)
    await scenario.init()
    return scenario
  }

  constructor (sandbox) {
    this.sinon = sandbox

    this.applications = new Set()
    this.windows = new Set()
    this.root = null
    this.projectRootPool = new Map()
    this.filePathPool = new Map()
  }

  async init () {
    if (this.root !== null) {
      return this.root
    }

    this.root = await new Promise((resolve, reject) => {
      temp.mkdir('launch-', (err, rootPath) => {
        if (err) { reject(err) } else { resolve(rootPath) }
      })
    })

    await Promise.all(
      ['a', 'b'].map(dirPath => new Promise((resolve, reject) => {
        const fullDirPath = path.join(this.root, dirPath)
        fs.makeTree(fullDirPath, err => {
          if (err) {
            reject(err)
          } else {
            this.projectRootPool.set(dirPath, fullDirPath)
            resolve()
          }
        })
      }))
    )

    await Promise.all(
      ['a/1.md', 'b/2.md'].map(filePath => new Promise((resolve, reject) => {
        const fullFilePath = path.join(this.root, filePath)
        fs.writeFile(fullFilePath, `file: ${filePath}\n`, {encoding: 'utf8'}, err => {
          if (err) {
            reject(err)
          } else {
            this.filePathPool.set(filePath, fullFilePath)
            this.filePathPool.set(path.basename(filePath), fullFilePath)
            resolve()
          }
        })
      }))
    )
  }

  async preconditions (source) {
    const app = this.addApplication()
    const windowPromises = []

    for (const windowSpec of this.parseWindowSpecs(source)) {
      if (windowSpec.editors.length === 0) {
        windowSpec.editors.push(null)
      }

      windowPromises.push((async (theApp, foldersToOpen, pathsToOpen) => {
        const window = await theApp.openPaths({ newWindow: true, foldersToOpen, pathsToOpen })
        this.windows.add(window)
        return window
      })(app, windowSpec.roots, windowSpec.editors))
    }
    await Promise.all(windowPromises)
  }

  async launch (options) {
    const app = options.app || this.addApplication()
    delete options.app

    if (options.pathsToOpen) {
      options.pathsToOpen = this.convertPaths(options.pathsToOpen)
    }

    const windows = await app.launch(options)
    for (const window of windows) {
      this.windows.add(window)
    }
    return windows
  }

  async open (options) {
    if (this.applications.size === 0) {
      return this.launch(options)
    }

    let app = options.app
    if (!app) {
      const apps = Array.from(this.applications)
      app = apps[apps.length - 1]
    } else {
      delete options.app
    }

    if (options.pathsToOpen) {
      options.pathsToOpen = this.convertPaths(options.pathsToOpen)
    }

    const window = await app.openWithOptions(options)
    this.windows.add(window)
    return window
  }

  async assert (source) {
    const windowSpecs = this.parseWindowSpecs(source)
    let specIndex = 0

    const windowPromises = []
    for (const window of this.windows) {
      windowPromises.push((async (theWindow, theSpec) => {
        const {_rootPaths: rootPaths, _editorPaths: editorPaths} = theWindow

        const comparison = {
          ok: true,
          extraWindow: false,
          missingWindow: false,
          extraRoots: [],
          missingRoots: [],
          extraEditors: [],
          missingEditors: [],
          roots: rootPaths,
          editors: editorPaths
        }

        if (!theSpec) {
          comparison.ok = false
          comparison.extraWindow = true
          comparison.extraRoots = rootPaths
          comparison.extraEditors = editorPaths
        } else {
          const [missingRoots, extraRoots] = this.compareSets(theSpec.roots, rootPaths)
          const [missingEditors, extraEditors] = this.compareSets(theSpec.editors, editorPaths)

          comparison.ok = missingRoots.length === 0 &&
            extraRoots.length === 0 &&
            missingEditors.length === 0 &&
            extraEditors.length === 0
          comparison.extraRoots = extraRoots
          comparison.missingRoots = missingRoots
          comparison.extraEditors = extraEditors
          comparison.missingEditors = missingEditors
        }

        return comparison
      })(window, windowSpecs[specIndex++]))
    }

    const comparisons = await Promise.all(windowPromises)
    for (; specIndex < windowSpecs.length; specIndex++) {
      const spec = windowSpecs[specIndex]
      comparisons.push({
        ok: false,
        extraWindow: false,
        missingWindow: true,
        extraRoots: [],
        missingRoots: spec.roots,
        extraEditors: [],
        missingEditors: spec.editors,
        roots: [],
        editors: []
      })
    }

    const shorthandParts = []
    const descriptionParts = []
    for (const comparison of comparisons) {
      const shortRoots = Array.from(comparison.roots, r => path.basename(r)).join(',')
      const shortPaths = Array.from(comparison.editors, e => path.basename(e)).join(',')
      shorthandParts.push(`[${shortRoots} ${shortPaths}]`)

      if (comparison.ok) {
        continue
      }

      let parts = []
      if (comparison.extraWindow) {
        parts.push('extra window\n')
      } else if (comparison.missingWindow) {
        parts.push('missing window\n')
      } else {
        parts.push('incorrect window\n')
      }

      const shorten = fullPaths => fullPaths.map(fullPath => path.basename(fullPath)).join(', ')

      if (comparison.extraRoots.length > 0) {
        parts.push(`* extra roots ${shorten(comparison.extraRoots)}\n`)
      }
      if (comparison.missingRoots.length > 0) {
        parts.push(`* missing roots ${shorten(comparison.missingRoots)}\n`)
      }
      if (comparison.extraEditors.length > 0) {
        parts.push(`* extra editors ${shorten(comparison.extraEditors)}\n`)
      }
      if (comparison.missingEditors.length > 0) {
        parts.push(`* missing editors ${shorten(comparison.missingEditors)}\n`)
      }

      descriptionParts.push(parts.join(''))
    }

    if (descriptionParts.length !== 0) {
      descriptionParts.unshift(shorthandParts.join(' ') + '\n')
      descriptionParts.unshift('Launched windows did not match spec\n')
    }

    assert.isTrue(descriptionParts.length === 0, descriptionParts.join(''))
  }

  async destroy () {
    await Promise.all(
      Array.from(this.applications, app => app.destroy())
    )
  }

  addApplication (options = {}) {
    const app = new AtomApplication({
      resourcePath: path.resolve(__dirname, '../..'),
      atomHomeDirPath: this.atomHome,
      ...options
    })
    this.sinon.stub(app, 'createWindow', loadSettings => new StubWindow(this.sinon, loadSettings, options))
    this.applications.add(app)
    return app
  }

  getApplication (index) {
    const app = Array.from(this.applications)[index]
    if (!app) {
      throw new Error(`Application ${index} does not exist`)
    }
    return app
  }

  getWindow (index) {
    const window = Array.from(this.windows)[index]
    if (!window) {
      throw new Error(`Window ${index} does not exist`)
    }
    return window
  }

  compareSets (expected, actual) {
    const expectedItems = new Set(expected)
    const extra = []
    const missing = []

    for (const actualItem of actual) {
      if (!expectedItems.delete(actualItem)) {
        // actualItem was present, but not expected
        extra.push(actualItem)
      }
    }
    for (const remainingItem of expectedItems) {
      // remainingItem was expected, but not present
      missing.push(remainingItem)
    }
    return [missing, extra]
  }

  convertRootPath (shortRootPath) {
    const fullRootPath = this.projectRootPool.get(shortRootPath)
    if (!fullRootPath) {
      throw new Error(`Unexpected short project root path: ${shortRootPath}`)
    }
    return fullRootPath
  }

  convertEditorPath (shortEditorPath) {
    const fullEditorPath = this.filePathPool.get(shortEditorPath)
    if (!fullEditorPath) {
      throw new Error(`Unexpected short editor path: ${shortEditorPath}`)
    }
    return fullEditorPath
  }

  convertPaths (paths) {
    return paths.map(shortPath => {
      const fullRoot = this.projectRootPool.get(shortPath)
      if (fullRoot) { return fullRoot }
      const fullEditor = this.filePathPool.get(shortPath)
      if (fullEditor) { return fullEditor }
      throw new Error(`Unexpected short path: ${shortPath}`)
    })
  }

  parseWindowSpecs (source) {
    const specs = []

    const rx = /\s*\[(?:_|(\S+)) (?:_|(\S+))\]/g
    let match = rx.exec(source)

    while (match) {
      const roots = match[1] ? match[1].split(',').map(shortPath => this.convertRootPath(shortPath)) : []
      const editors = match[2] ? match[2].split(',').map(shortPath => this.convertEditorPath(shortPath)) : []
      specs.push({ roots, editors })

      match = rx.exec(source)
    }

    return specs
  }
}
