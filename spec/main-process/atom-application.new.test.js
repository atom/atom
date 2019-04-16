/* globals assert */

const temp = require('temp').track()
const season = require('season')
const dedent = require('dedent')
const electron = require('electron')
const fs = require('fs-plus')
const path = require('path')
const AtomApplication = require('../../src/main-process/atom-application')
const parseCommandLine = require('../../src/main-process/parse-command-line')
const {emitterEventPromise} = require('../async-spec-helpers')

describe('AtomApplication', function () {
  this.timeout(60 * 1000)
  let scenario

  beforeEach(async function () {
    scenario = await LaunchScenario.create()
  })

  afterEach(async function () {
    await scenario.destroy()
  })

  describe('command-line interface behavior', function () {
    describe('with no open windows', function () {
      it('opens a file', async function () {
        await scenario.launch(parseCommandLine(['a/1.md']))
        await scenario.assert('[_ 1.md]')
      })

      it('opens a directory', async function () {
        await scenario.launch(parseCommandLine(['a']))
        await scenario.assert('[a _]')
      })

      it('opens a file with --add', async function () {
        await scenario.launch(parseCommandLine(['--add', 'a/1.md']))
        await scenario.assert('[_ 1.md]')
      })

      it('opens a directory with --add', async function () {
        await scenario.launch(parseCommandLine(['--add', 'a']))
        await scenario.assert('[a _]')
      })

      it('opens a file with --new-window', async function () {
        await scenario.launch(parseCommandLine(['--new-window', 'a/1.md']))
        await scenario.assert('[_ 1.md]')
      })

      it('opens a directory with --new-window', async function () {
        await scenario.launch(parseCommandLine(['--new-window', 'a']))
        await scenario.assert('[a _]')
      })

      it('opens a directory with --new-window', async function () {
        await scenario.launch(parseCommandLine(['--new-window', 'a']))
      })
    })
  })
})

let channelIdCounter = 0

class LaunchScenario {
  static async create () {
    const scenario = new this()
    await scenario.init()
    return scenario
  }

  constructor () {
    this.applications = new Set()
    this.windows = new Set()
    this.root = null
    this.atomHome = null
    this.projectRootPool = new Map()
    this.filePathPool = new Map()

    this.originalAtomHome = process.env.ATOM_HOME
  }

  async init () {
    if (this.root !== null) {
      return this.root
    }

    await this.clearElectronSession()

    this.root = await new Promise((resolve, reject) => {
      temp.mkdir('launch-', (err, rootPath) => {
        if (err) { reject(err) } else { resolve(rootPath) }
      })
    })

    this.atomHome = path.join(this.root, '.atom')
    process.env.ATOM_HOME = this.atomHome
    await new Promise((resolve, reject) => {
      season.writeFile(path.join(this.atomHome, 'config.cson'), {
        '*': {
          welcome: { showOnStartup: false },
          core: { telemetryConsent: 'no', automaticallyUpdate: false }
        }
      }, err => {
        if (err) { reject(err) } else { resolve() }
      })
    })

    await new Promise((resolve, reject) => {
      // Symlinking the compile cache into the temporary home dir makes the windows load much faster
      fs.symlink(
        path.join(this.originalAtomHome, 'compile-cache'),
        path.join(this.atomHome, 'compile-cache'),
        'junction',
        err => {
          if (err) { reject(err) } else { resolve() }
        }
      )
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
      const fullRootPaths = windowSpec.roots.map(rootPath => this.projectRootPool.get(rootPath))
      const fullEditorPaths = windowSpec.editors.map(filePath => this.filePathPool.get(filePath))

      windowPromises.push((async (theApp, foldersToOpen, pathsToOpen) => {
        const window = await theApp.openPaths({ newWindow: true, foldersToOpen, pathsToOpen })
        await emitterEventPromise(window, 'window:locations-opened')
        return window
      })(app, fullRootPaths, fullEditorPaths))
    }
    for (const window of await Promise.all(windowPromises)) {
      this.windows.add(window)
    }
  }

  async launch (options) {
    const app = this.addApplication()
    if (options.pathsToOpen) {
      options.pathsToOpen = this.convertPaths(options.pathsToOpen)
    }

    const windows = await app.launch(options)
    const openedPromises = []
    for (const window of windows) {
      this.windows.add(window)
      openedPromises.push(emitterEventPromise(window, 'window:locations-opened'))
    }
    await Promise.all(openedPromises)
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
    await emitterEventPromise(window, 'window:locations-opened')
    return window
  }

  async assert (source) {
    const windowSpecs = this.parseWindowSpecs(source)
    let specIndex = 0

    const windowPromises = []
    for (const window of this.windows) {
      windowPromises.push((async (theWindow, theSpec) => {
        const [rootPaths, editorPaths] = await Promise.all([
          this.getProjectRoots(theWindow),
          this.getOpenEditors(theWindow)
        ])

        const comparison = {
          ok: true,
          extraWindow: false,
          missingWindow: false,
          extraRoots: [],
          missingRoots: [],
          extraEditors: [],
          missingEditors: []
        }

        if (!theSpec) {
          comparison.ok = false
          comparison.extraWindow = true
          comparison.extraRoots = rootPaths
          comparison.extraEditors = editorPaths
        } else {
          const [missingRoots, extraRoots] = this.compareSets(theSpec.roots, rootPaths)
          const [missingEditors, extraEditors] = this.compareSets(theSpec.editors, editorPaths)

          comparison.ok = missingRoots.length > 0 ||
            extraRoots.length > 0 ||
            missingEditors.length > 0 ||
            extraEditors.length > 0
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
        missingEditors: spec.editors
      })
    }

    const descriptionParts = []
    for (const comparison of comparisons) {
      if (comparison.ok) {
        continue
      }

      let parts = []
      if (comparison.extraWindow) {
        parts.push('extra window\n')
      } else if (comparison.missingWindow) {
        parts.push('missing window\n')
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

      if (descriptionParts.length === 0) {
        descriptionParts.push('Launched windows did not match spec\n')
      }
      descriptionParts.push(parts.join(''))
    }

    assert.isTrue(descriptionParts.length === 0, descriptionParts.join(''))
  }

  async destroy () {
    await Promise.all(
      Array.from(this.applications, app => app.destroy())
    )
    await this.clearElectronSession()

    process.env.ATOM_HOME = this.originalAtomHome
  }

  addApplication (options = {}) {
    const app = new AtomApplication({
      resourcePath: path.resolve(__dirname, '../..'),
      atomHomeDirPath: this.atomHome,
      ...options
    })
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

  getProjectRoots (window) {
    return this.evalInWebContents(window.browserWindow.webContents, reply => reply(atom.project.getPaths()))
  }

  getOpenEditors (window) {
    return this.evalInWebContents(window.browserWindow.webContents, reply => {
      reply(atom.workspace.getTextEditors().map(editor => editor.getPath()).filter(Boolean))
    })
  }

  evalInWebContents (webContents, source, ...args) {
    const channelId = `eval-result-${channelIdCounter++}`
    return new Promise(resolve => {
      electron.ipcMain.on(channelId, receiveResult)

      function receiveResult (_event, result) {
        electron.ipcMain.removeListener('eval-result', receiveResult)
        resolve(result)
      }

      const js = dedent`
        function sendBackToMainProcess (result) {
          require('electron').ipcRenderer.send('${channelId}', result)
        }
        (${source})(sendBackToMainProcess, ${args.map(JSON.stringify).join(', ')})
      `
      webContents.executeJavaScript(js)
    })
  }

  clearElectronSession () {
    return new Promise(resolve => {
      electron.session.defaultSession.clearStorageData(() => {
        // Resolve promise on next tick, otherwise the process stalls. This
        // might be a bug in Electron, but it's probably fixed on the newer
        // versions.
        process.nextTick(resolve)
      })
    })
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
      specs.push({
        roots: (match[1] || '').split(','),
        editors: (match[2] || '').split(',')
      })

      match = rx.exec(source)
    }

    return specs
  }
}
