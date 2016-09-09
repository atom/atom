/** @babel */

import season from 'season'
import dedent from 'dedent'
import electron from 'electron'
import fs from 'fs-plus'
import path from 'path'
import AtomApplication from '../../src/main-process/atom-application'
import parseCommandLine from '../../src/main-process/parse-command-line'
import {timeoutPromise, conditionPromise} from '../async-spec-helpers'

const ATOM_RESOURCE_PATH = path.resolve(__dirname, '..', '..')

describe('AtomApplication', function () {
  this.timeout(60 * 1000)

  let originalAppQuit, originalAtomHome, atomApplicationsToDestroy

  beforeEach(function () {
    originalAppQuit = electron.app.quit
    mockElectronAppQuit()
    originalAtomHome = process.env.ATOM_HOME
    process.env.ATOM_HOME = makeTempDir('atom-home')
    // Symlinking the compile cache into the temporary home dir makes the windows load much faster
    fs.symlinkSync(path.join(originalAtomHome, 'compile-cache'), path.join(process.env.ATOM_HOME, 'compile-cache'))
    season.writeFileSync(path.join(process.env.ATOM_HOME, 'config.cson'), {
      '*': {
        welcome: {showOnStartup: false},
        core: {telemetryConsent: 'no'}
      }
    })
    atomApplicationsToDestroy = []
  })

  afterEach(async function () {
    process.env.ATOM_HOME = originalAtomHome
    for (let atomApplication of atomApplicationsToDestroy) {
      await atomApplication.destroy()
    }
    await clearElectronSession()
    electron.app.quit = originalAppQuit
  })

  describe('launch', function () {
    it('can open to a specific line number of a file', async function () {
      const filePath = path.join(makeTempDir(), 'new-file')
      fs.writeFileSync(filePath, '1\n2\n3\n4\n')
      const atomApplication = buildAtomApplication()

      const window = atomApplication.launch(parseCommandLine([filePath + ':3']))
      await focusWindow(window)

      const cursorRow = await evalInWebContents(window.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.observeActivePaneItem(function (textEditor) {
          if (textEditor) sendBackToMainProcess(textEditor.getCursorBufferPosition().row)
        })
      })

      assert.equal(cursorRow, 2)
    })

    it('can open to a specific line and column of a file', async function () {
      const filePath = path.join(makeTempDir(), 'new-file')
      fs.writeFileSync(filePath, '1\n2\n3\n4\n')
      const atomApplication = buildAtomApplication()

      const window = atomApplication.launch(parseCommandLine([filePath + ':2:2']))
      await focusWindow(window)

      const cursorPosition = await evalInWebContents(window.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.observeActivePaneItem(function (textEditor) {
          if (textEditor) sendBackToMainProcess(textEditor.getCursorBufferPosition())
        })
      })

      assert.deepEqual(cursorPosition, {row: 1, column: 1})
    })

    it('removes all trailing whitespace and colons from the specified path', async function () {
      let filePath = path.join(makeTempDir(), 'new-file')
      fs.writeFileSync(filePath, '1\n2\n3\n4\n')
      const atomApplication = buildAtomApplication()

      const window = atomApplication.launch(parseCommandLine([filePath + '::   ']))
      await focusWindow(window)

      const openedPath = await evalInWebContents(window.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.observeActivePaneItem(function (textEditor) {
          if (textEditor) sendBackToMainProcess(textEditor.getPath())
        })
      })

      assert.equal(openedPath, filePath)
    })

    if (process.platform === 'darwin' || process.platform === 'win32') {
      it('positions new windows at an offset distance from the previous window', async function () {
        const atomApplication = buildAtomApplication()

        const window1 = atomApplication.launch(parseCommandLine([makeTempDir()]))
        await focusWindow(window1)
        window1.browserWindow.setBounds({width: 400, height: 400, x: 0, y: 0})

        const window2 = atomApplication.launch(parseCommandLine([makeTempDir()]))
        await focusWindow(window2)

        assert.notEqual(window1, window2)
        const window1Dimensions = window1.getDimensions()
        const window2Dimensions = window2.getDimensions()
        assert.isAbove(window2Dimensions.x, window1Dimensions.x)
        assert.isAbove(window2Dimensions.y, window1Dimensions.y)
      })
    }

    it('reuses existing windows when opening paths, but not directories', async function () {
      const dirAPath = makeTempDir("a")
      const dirBPath = makeTempDir("b")
      const dirCPath = makeTempDir("c")
      const existingDirCFilePath = path.join(dirCPath, 'existing-file')
      fs.writeFileSync(existingDirCFilePath, 'this is an existing file')

      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([path.join(dirAPath, 'new-file')]))
      await focusWindow(window1)

      let activeEditorPath
      activeEditorPath = await evalInWebContents(window1.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.observeActivePaneItem(function (textEditor) {
          if (textEditor) sendBackToMainProcess(textEditor.getPath())
        })
      })
      assert.equal(activeEditorPath, path.join(dirAPath, 'new-file'))

      // Reuses the window when opening *files*, even if they're in a different directory
      // Does not change the project paths when doing so.
      const reusedWindow = atomApplication.launch(parseCommandLine([existingDirCFilePath]))
      assert.equal(reusedWindow, window1)
      assert.deepEqual(atomApplication.windows, [window1])
      activeEditorPath = await evalInWebContents(window1.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.onDidChangeActivePaneItem(function (textEditor) {
          sendBackToMainProcess(textEditor.getPath())
        })
      })
      assert.equal(activeEditorPath, existingDirCFilePath)
      assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath])

      // Opens new windows when opening directories
      const window2 = atomApplication.launch(parseCommandLine([dirCPath]))
      assert.notEqual(window2, window1)
      await focusWindow(window2)
      assert.deepEqual(await getTreeViewRootDirectories(window2), [dirCPath])
    })

    it('adds folders to existing windows when the --add option is used', async function () {
      const dirAPath = makeTempDir("a")
      const dirBPath = makeTempDir("b")
      const dirCPath = makeTempDir("c")
      const existingDirCFilePath = path.join(dirCPath, 'existing-file')
      fs.writeFileSync(existingDirCFilePath, 'this is an existing file')

      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([path.join(dirAPath, 'new-file')]))
      await focusWindow(window1)

      let activeEditorPath
      activeEditorPath = await evalInWebContents(window1.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.observeActivePaneItem(function (textEditor) {
          if (textEditor) sendBackToMainProcess(textEditor.getPath())
        })
      })
      assert.equal(activeEditorPath, path.join(dirAPath, 'new-file'))

      // When opening *files* with --add, reuses an existing window and adds
      // parent directory to the project
      let reusedWindow = atomApplication.launch(parseCommandLine([existingDirCFilePath, '--add']))
      assert.equal(reusedWindow, window1)
      assert.deepEqual(atomApplication.windows, [window1])
      activeEditorPath = await evalInWebContents(window1.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.onDidChangeActivePaneItem(function (textEditor) {
          sendBackToMainProcess(textEditor.getPath())
        })
      })
      assert.equal(activeEditorPath, existingDirCFilePath)
      assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath, dirCPath])

      // When opening *directories* with add reuses an existing window and adds
      // the directory to the project
      reusedWindow = atomApplication.launch(parseCommandLine([dirBPath, '-a']))
      assert.equal(reusedWindow, window1)
      assert.deepEqual(atomApplication.windows, [window1])
      assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath, dirCPath, dirBPath])
    })

    it('persists window state based on the project directories', async function () {
      const tempDirPath = makeTempDir()
      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([path.join(tempDirPath, 'new-file')]))
      await evalInWebContents(window1.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.observeActivePaneItem(function (textEditor) {
          if (textEditor) {
            textEditor.insertText('Hello World!')
            sendBackToMainProcess(null)
          }
        })
      })
      window1.close()
      await window1.closedPromise

      const window2 = atomApplication.launch(parseCommandLine([path.join(tempDirPath)]))
      const window2Text = await evalInWebContents(window2.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.observeActivePaneItem(function (textEditor) {
          if (textEditor) sendBackToMainProcess(textEditor.getText())
        })
      })

      assert.equal(window2Text, 'Hello World!')
    })

    it('shows all directories in the tree view when multiple directory paths are passed to Atom', async function () {
      const dirAPath = makeTempDir("a")
      const dirBPath = makeTempDir("b")
      const dirBSubdirPath = path.join(dirBPath, 'c')
      fs.mkdirSync(dirBSubdirPath)

      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([dirAPath, dirBPath]))
      await focusWindow(window1)

      await timeoutPromise(1000)

      let treeViewPaths = await evalInWebContents(window1.browserWindow.webContents, function (sendBackToMainProcess) {
        sendBackToMainProcess(
          Array
            .from(document.querySelectorAll('.tree-view .project-root > .header .name'))
            .map(element => element.dataset.path)
        )
      })
      assert.deepEqual(treeViewPaths, [dirAPath, dirBPath])
    })

    it('reuses windows with no project paths to open directories', async function () {
      const tempDirPath = makeTempDir()
      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([]))
      await focusWindow(window1)

      const reusedWindow = atomApplication.launch(parseCommandLine([tempDirPath]))
      assert.equal(reusedWindow, window1)
      assert.deepEqual(await getTreeViewRootDirectories(window1), [tempDirPath])
    })

    it('opens a new window with a single untitled buffer when launched with no path, even if windows already exist', async function () {
      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([]))
      await focusWindow(window1)
      const window1EditorTitle = await evalInWebContents(window1.browserWindow.webContents, function (sendBackToMainProcess) {
        sendBackToMainProcess(atom.workspace.getActiveTextEditor().getTitle())
      })
      assert.equal(window1EditorTitle, 'untitled')

      const window2 = atomApplication.launch(parseCommandLine([]))
      await focusWindow(window2)
      const window2EditorTitle = await evalInWebContents(window1.browserWindow.webContents, function (sendBackToMainProcess) {
        sendBackToMainProcess(atom.workspace.getActiveTextEditor().getTitle())
      })
      assert.equal(window2EditorTitle, 'untitled')

      assert.deepEqual(atomApplication.windows, [window1, window2])
    })

    it('does not open an empty editor when opened with no path if the core.openEmptyEditorOnStart config setting is false', async function () {
      const configPath = path.join(process.env.ATOM_HOME, 'config.cson')
      const config = season.readFileSync(configPath)
      if (!config['*'].core) config['*'].core = {}
      config['*'].core.openEmptyEditorOnStart = false
      season.writeFileSync(configPath, config)

      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([]))
      await focusWindow(window1)

     // wait a bit just to make sure we don't pass due to querying the render process before it loads
      await timeoutPromise(1000)

      const itemCount = await evalInWebContents(window1.browserWindow.webContents, function (sendBackToMainProcess) {
        sendBackToMainProcess(atom.workspace.getActivePane().getItems().length)
      })
      assert.equal(itemCount, 0)
    })

    it('opens an empty text editor and loads its parent directory in the tree-view when launched with a new file path', async function () {
      const atomApplication = buildAtomApplication()
      const newFilePath = path.join(makeTempDir(), 'new-file')
      const window = atomApplication.launch(parseCommandLine([newFilePath]))
      await focusWindow(window)
      const {editorTitle, editorText} = await evalInWebContents(window.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.observeActivePaneItem(function (editor) {
          if (editor) sendBackToMainProcess({editorTitle: editor.getTitle(), editorText: editor.getText()})
        })
      })
      assert.equal(editorTitle, path.basename(newFilePath))
      assert.equal(editorText, '')
      assert.deepEqual(await getTreeViewRootDirectories(window), [path.dirname(newFilePath)])
    })

    it('opens an empty text editor and loads its parent directory in the tree-view when launched with a new file path in a remote directory', async function () {
      // Disable the tree-view because it will try to enumerate the contents of
      // the remote directory and, since it doesn't exist, throw an error.
      const configPath = path.join(process.env.ATOM_HOME, 'config.cson')
      const config = season.readFileSync(configPath)
      if (!config['*'].core) config['*'].core = {}
      config['*'].core.disabledPackages = ['tree-view']
      season.writeFileSync(configPath, config)

      const atomApplication = buildAtomApplication()
      const newRemoteFilePath = 'remote://server:3437/some/directory/path'
      const window = atomApplication.launch(parseCommandLine([newRemoteFilePath]))
      await focusWindow(window)
      const {projectPaths, editorTitle, editorText} = await evalInWebContents(window.browserWindow.webContents, function (sendBackToMainProcess) {
        atom.workspace.observeActivePaneItem(function (editor) {
          if (editor) {
            sendBackToMainProcess({
              projectPaths: atom.project.getPaths(),
              editorTitle: editor.getTitle(),
              editorText: editor.getText()
            })
          }
        })
      })
      assert.deepEqual(projectPaths, [newRemoteFilePath])
      assert.equal(editorTitle, path.basename(newRemoteFilePath))
      assert.equal(editorText, '')
    })

    it('reopens any previously opened windows when launched with no path', async function () {
      const tempDirPath1 = makeTempDir()
      const tempDirPath2 = makeTempDir()

      const atomApplication1 = buildAtomApplication()
      const app1Window1 = atomApplication1.launch(parseCommandLine([tempDirPath1]))
      await app1Window1.loadedPromise
      const app1Window2 = atomApplication1.launch(parseCommandLine([tempDirPath2]))
      await app1Window2.loadedPromise

      const atomApplication2 = buildAtomApplication()
      const [app2Window1, app2Window2] = atomApplication2.launch(parseCommandLine([]))
      await app2Window1.loadedPromise
      await app2Window2.loadedPromise

      assert.deepEqual(await getTreeViewRootDirectories(app2Window1), [tempDirPath1])
      assert.deepEqual(await getTreeViewRootDirectories(app2Window2), [tempDirPath2])
    })

    it('does not reopen any previously opened windows when launched with no path and `core.restorePreviousWindowsOnStart` is false', async function () {
      const atomApplication1 = buildAtomApplication()
      const app1Window1 = atomApplication1.launch(parseCommandLine([makeTempDir()]))
      await focusWindow(app1Window1)
      const app1Window2 = atomApplication1.launch(parseCommandLine([makeTempDir()]))
      await focusWindow(app1Window2)

      const configPath = path.join(process.env.ATOM_HOME, 'config.cson')
      const config = season.readFileSync(configPath)
      if (!config['*'].core) config['*'].core = {}
      config['*'].core.restorePreviousWindowsOnStart = false
      season.writeFileSync(configPath, config)

      const atomApplication2 = buildAtomApplication()
      const app2Window = atomApplication2.launch(parseCommandLine([]))
      await focusWindow(app2Window)
      assert.deepEqual(await getTreeViewRootDirectories(app2Window), [])
    })

    describe('when closing the last window', function () {
      if (process.platform === 'linux' || process.platform === 'win32') {
        it('quits the application', async function () {
          const atomApplication = buildAtomApplication()
          const window = atomApplication.launch(parseCommandLine([path.join(makeTempDir("a"), 'file-a')]))
          await focusWindow(window)
          window.close()
          await window.closedPromise
          assert(electron.app.hasQuitted())
        })
      } else if (process.platform === 'darwin') {
        it('leaves the application open', async function () {
          const atomApplication = buildAtomApplication()
          const window = atomApplication.launch(parseCommandLine([path.join(makeTempDir("a"), 'file-a')]))
          await focusWindow(window)
          window.close()
          await window.closedPromise
          assert(!electron.app.hasQuitted())
        })
      }
    })
  })

  describe('before quitting', function () {
    it('waits until all the windows have saved their state and then quits', async function () {
      const dirAPath = makeTempDir("a")
      const dirBPath = makeTempDir("b")
      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([path.join(dirAPath, 'file-a')]))
      await focusWindow(window1)
      const window2 = atomApplication.launch(parseCommandLine([path.join(dirBPath, 'file-b')]))
      await focusWindow(window2)
      electron.app.quit()
      assert(!electron.app.hasQuitted())
      await Promise.all([window1.lastSaveStatePromise, window2.lastSaveStatePromise])
      assert(electron.app.hasQuitted())
    })
  })

  function buildAtomApplication () {
    const atomApplication = new AtomApplication({
      resourcePath: ATOM_RESOURCE_PATH,
      atomHomeDirPath: process.env.ATOM_HOME
    })
    atomApplicationsToDestroy.push(atomApplication)
    return atomApplication
  }

  async function focusWindow (window) {
    window.focus()
    await window.loadedPromise
    await conditionPromise(() => window.atomApplication.lastFocusedWindow === window)
  }

  function mockElectronAppQuit () {
    let quitted = false
    electron.app.quit = function () {
      let shouldQuit = true
      electron.app.emit('before-quit', {preventDefault: () => { shouldQuit = false }})
      if (shouldQuit) {
        quitted = true
      }
    }
    electron.app.hasQuitted = function () {
      return quitted
    }
  }

  function makeTempDir (name) {
    return fs.realpathSync(require('temp').mkdirSync(name))
  }

  let channelIdCounter = 0
  function evalInWebContents (webContents, source) {
    const channelId = 'eval-result-' + channelIdCounter++
    return new Promise(function (resolve) {
      electron.ipcMain.on(channelId, receiveResult)

      function receiveResult (event, result) {
        electron.ipcMain.removeListener('eval-result', receiveResult)
        resolve(result)
      }

      webContents.executeJavaScript(dedent`
        function sendBackToMainProcess (result) {
          require('electron').ipcRenderer.send('${channelId}', result)
        }
        (${source})(sendBackToMainProcess)
      `)
    })
  }

  function getTreeViewRootDirectories (atomWindow) {
    return evalInWebContents(atomWindow.browserWindow.webContents, function (sendBackToMainProcess) {
      sendBackToMainProcess(
        Array
          .from(document.querySelectorAll('.tree-view .project-root > .header .name'))
          .map(element => element.dataset.path)
      )
    })
  }

  function clearElectronSession () {
    return new Promise(function (resolve) {
      electron.session.defaultSession.clearStorageData(function () {
        // Resolve promise on next tick, otherwise the process stalls. This
        // might be a bug in Electron, but it's probably fixed on the newer
        // versions.
        process.nextTick(resolve)
      })
    })
  }
})
