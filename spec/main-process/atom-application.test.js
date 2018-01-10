const temp = require('temp').track()
const season = require('season')
const dedent = require('dedent')
const electron = require('electron')
const fs = require('fs-plus')
const path = require('path')
const sinon = require('sinon')
const AtomApplication = require('../../src/main-process/atom-application')
const parseCommandLine = require('../../src/main-process/parse-command-line')
const {timeoutPromise, conditionPromise, emitterEventPromise} = require('../async-spec-helpers')

const ATOM_RESOURCE_PATH = path.resolve(__dirname, '..', '..')

describe('AtomApplication', function () {
  this.timeout(60 * 1000)

  let originalAppQuit, originalShowMessageBox, originalAtomHome, atomApplicationsToDestroy

  beforeEach(() => {
    originalAppQuit = electron.app.quit
    originalShowMessageBox = electron.dialog.showMessageBox
    mockElectronAppQuit()
    originalAtomHome = process.env.ATOM_HOME
    process.env.ATOM_HOME = makeTempDir('atom-home')
    // Symlinking the compile cache into the temporary home dir makes the windows load much faster
    fs.symlinkSync(path.join(originalAtomHome, 'compile-cache'), path.join(process.env.ATOM_HOME, 'compile-cache'), 'junction')
    season.writeFileSync(path.join(process.env.ATOM_HOME, 'config.cson'), {
      '*': {
        welcome: {showOnStartup: false},
        core: {telemetryConsent: 'no'}
      }
    })
    atomApplicationsToDestroy = []
  })

  afterEach(async () => {
    process.env.ATOM_HOME = originalAtomHome
    for (let atomApplication of atomApplicationsToDestroy) {
      await atomApplication.destroy()
    }
    await clearElectronSession()
    electron.app.quit = originalAppQuit
    electron.dialog.showMessageBox = originalShowMessageBox
  })

  describe('launch', () => {
    it('can open to a specific line number of a file', async () => {
      const filePath = path.join(makeTempDir(), 'new-file')
      fs.writeFileSync(filePath, '1\n2\n3\n4\n')
      const atomApplication = buildAtomApplication()

      const window = atomApplication.launch(parseCommandLine([filePath + ':3']))
      await focusWindow(window)

      const cursorRow = await evalInWebContents(window.browserWindow.webContents, sendBackToMainProcess => {
        atom.workspace.observeTextEditors(textEditor => {
          sendBackToMainProcess(textEditor.getCursorBufferPosition().row)
        })
      })

      assert.equal(cursorRow, 2)
    })

    it('can open to a specific line and column of a file', async () => {
      const filePath = path.join(makeTempDir(), 'new-file')
      fs.writeFileSync(filePath, '1\n2\n3\n4\n')
      const atomApplication = buildAtomApplication()

      const window = atomApplication.launch(parseCommandLine([filePath + ':2:2']))
      await focusWindow(window)

      const cursorPosition = await evalInWebContents(window.browserWindow.webContents, sendBackToMainProcess => {
        atom.workspace.observeTextEditors(textEditor => {
          sendBackToMainProcess(textEditor.getCursorBufferPosition())
        })
      })

      assert.deepEqual(cursorPosition, {row: 1, column: 1})
    })

    it('removes all trailing whitespace and colons from the specified path', async () => {
      let filePath = path.join(makeTempDir(), 'new-file')
      fs.writeFileSync(filePath, '1\n2\n3\n4\n')
      const atomApplication = buildAtomApplication()

      const window = atomApplication.launch(parseCommandLine([filePath + '::   ']))
      await focusWindow(window)

      const openedPath = await evalInWebContents(window.browserWindow.webContents, sendBackToMainProcess => {
        atom.workspace.observeTextEditors(textEditor => {
          sendBackToMainProcess(textEditor.getPath())
        })
      })

      assert.equal(openedPath, filePath)
    })

    if (process.platform === 'darwin' || process.platform === 'win32') {
      it('positions new windows at an offset distance from the previous window', async () => {
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

    it('reuses existing windows when opening paths, but not directories', async () => {
      const dirAPath = makeTempDir("a")
      const dirBPath = makeTempDir("b")
      const dirCPath = makeTempDir("c")
      const existingDirCFilePath = path.join(dirCPath, 'existing-file')
      fs.writeFileSync(existingDirCFilePath, 'this is an existing file')

      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([path.join(dirAPath, 'new-file')]))
      await emitterEventPromise(window1, 'window:locations-opened')
      await focusWindow(window1)

      let activeEditorPath = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
        atom.workspace.observeTextEditors(textEditor => {
          sendBackToMainProcess(textEditor.getPath())
        })
      })
      assert.equal(activeEditorPath, path.join(dirAPath, 'new-file'))

      // Reuses the window when opening *files*, even if they're in a different directory
      // Does not change the project paths when doing so.
      const reusedWindow = atomApplication.launch(parseCommandLine([existingDirCFilePath]))
      assert.equal(reusedWindow, window1)
      assert.deepEqual(atomApplication.getAllWindows(), [window1])
      activeEditorPath = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
        const subscription = atom.workspace.onDidChangeActivePaneItem(textEditor => {
          sendBackToMainProcess(textEditor.getPath())
          subscription.dispose()
        })
      })
      assert.equal(activeEditorPath, existingDirCFilePath)
      assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath])

      // Opens new windows when opening directories
      const window2 = atomApplication.launch(parseCommandLine([dirCPath]))
      await emitterEventPromise(window2, 'window:locations-opened')
      assert.notEqual(window2, window1)
      await focusWindow(window2)
      assert.deepEqual(await getTreeViewRootDirectories(window2), [dirCPath])
    })

    it('adds folders to existing windows when the --add option is used', async () => {
      const dirAPath = makeTempDir("a")
      const dirBPath = makeTempDir("b")
      const dirCPath = makeTempDir("c")
      const existingDirCFilePath = path.join(dirCPath, 'existing-file')
      fs.writeFileSync(existingDirCFilePath, 'this is an existing file')

      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([path.join(dirAPath, 'new-file')]))
      await focusWindow(window1)

      let activeEditorPath = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
        atom.workspace.observeTextEditors(textEditor => {
          sendBackToMainProcess(textEditor.getPath())
        })
      })
      assert.equal(activeEditorPath, path.join(dirAPath, 'new-file'))

      // When opening *files* with --add, reuses an existing window and adds
      // parent directory to the project
      let reusedWindow = atomApplication.launch(parseCommandLine([existingDirCFilePath, '--add']))
      assert.equal(reusedWindow, window1)
      assert.deepEqual(atomApplication.getAllWindows(), [window1])
      activeEditorPath = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
        const subscription = atom.workspace.onDidChangeActivePaneItem(textEditor => {
          sendBackToMainProcess(textEditor.getPath())
          subscription.dispose()
        })
      })
      assert.equal(activeEditorPath, existingDirCFilePath)
      assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath, dirCPath])

      // When opening *directories* with add reuses an existing window and adds
      // the directory to the project
      reusedWindow = atomApplication.launch(parseCommandLine([dirBPath, '-a']))
      assert.equal(reusedWindow, window1)
      assert.deepEqual(atomApplication.getAllWindows(), [window1])

      await conditionPromise(async () => (await getTreeViewRootDirectories(reusedWindow)).length === 3)
      assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath, dirCPath, dirBPath])
    })

    it('persists window state based on the project directories', async () => {
      const tempDirPath = makeTempDir()
      const atomApplication = buildAtomApplication()
      const nonExistentFilePath = path.join(tempDirPath, 'new-file')

      const window1 = atomApplication.launch(parseCommandLine([nonExistentFilePath]))
      await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
        atom.workspace.observeTextEditors(textEditor => {
          textEditor.insertText('Hello World!')
          sendBackToMainProcess(null)
        })
      })
      await window1.prepareToUnload()
      window1.close()
      await window1.closedPromise

      // Restore unsaved state when opening the directory itself
      const window2 = atomApplication.launch(parseCommandLine([tempDirPath]))
      await window2.loadedPromise
      const window2Text = await evalInWebContents(window2.browserWindow.webContents, sendBackToMainProcess => {
        const textEditor = atom.workspace.getActiveTextEditor()
        textEditor.moveToBottom()
        textEditor.insertText(' How are you?')
        sendBackToMainProcess(textEditor.getText())
      })
      assert.equal(window2Text, 'Hello World! How are you?')
      await window2.prepareToUnload()
      window2.close()
      await window2.closedPromise

      // Restore unsaved state when opening a path to a non-existent file in the directory
      const window3 = atomApplication.launch(parseCommandLine([path.join(tempDirPath, 'another-non-existent-file')]))
      await window3.loadedPromise
      const window3Texts = await evalInWebContents(window3.browserWindow.webContents, (sendBackToMainProcess, nonExistentFilePath) => {
        sendBackToMainProcess(atom.workspace.getTextEditors().map(editor => editor.getText()))
      })
      assert.include(window3Texts, 'Hello World! How are you?')
    })

    it('shows all directories in the tree view when multiple directory paths are passed to Atom', async () => {
      const dirAPath = makeTempDir("a")
      const dirBPath = makeTempDir("b")
      const dirBSubdirPath = path.join(dirBPath, 'c')
      fs.mkdirSync(dirBSubdirPath)

      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([dirAPath, dirBPath]))
      await focusWindow(window1)

      assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath, dirBPath])
    })

    it('reuses windows with no project paths to open directories', async () => {
      const tempDirPath = makeTempDir()
      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([]))
      await focusWindow(window1)

      const reusedWindow = atomApplication.launch(parseCommandLine([tempDirPath]))
      assert.equal(reusedWindow, window1)
      await conditionPromise(async () => (await getTreeViewRootDirectories(reusedWindow)).length > 0)
    })

    it('opens a new window with a single untitled buffer when launched with no path, even if windows already exist', async () => {
      const atomApplication = buildAtomApplication()
      const window1 = atomApplication.launch(parseCommandLine([]))
      await focusWindow(window1)
      const window1EditorTitle = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
        sendBackToMainProcess(atom.workspace.getActiveTextEditor().getTitle())
      })
      assert.equal(window1EditorTitle, 'untitled')

      const window2 = atomApplication.openWithOptions(parseCommandLine([]))
      await focusWindow(window2)
      const window2EditorTitle = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
        sendBackToMainProcess(atom.workspace.getActiveTextEditor().getTitle())
      })
      assert.equal(window2EditorTitle, 'untitled')

      assert.deepEqual(atomApplication.getAllWindows(), [window2, window1])
    })

    it('does not open an empty editor when opened with no path if the core.openEmptyEditorOnStart config setting is false', async () => {
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

      const itemCount = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
        sendBackToMainProcess(atom.workspace.getActivePane().getItems().length)
      })
      assert.equal(itemCount, 0)
    })

    it('opens an empty text editor and loads its parent directory in the tree-view when launched with a new file path', async () => {
      const atomApplication = buildAtomApplication()
      const newFilePath = path.join(makeTempDir(), 'new-file')
      const window = atomApplication.launch(parseCommandLine([newFilePath]))
      await focusWindow(window)
      const {editorTitle, editorText} = await evalInWebContents(window.browserWindow.webContents, sendBackToMainProcess => {
        atom.workspace.observeTextEditors(editor => {
          sendBackToMainProcess({editorTitle: editor.getTitle(), editorText: editor.getText()})
        })
      })
      assert.equal(editorTitle, path.basename(newFilePath))
      assert.equal(editorText, '')
      assert.deepEqual(await getTreeViewRootDirectories(window), [path.dirname(newFilePath)])
    })

    it('adds a remote directory to the project when launched with a remote directory', async () => {
      const packagePath = path.join(__dirname, '..', 'fixtures', 'packages', 'package-with-directory-provider')
      const packagesDirPath = path.join(process.env.ATOM_HOME, 'packages')
      fs.mkdirSync(packagesDirPath)
      fs.symlinkSync(packagePath, path.join(packagesDirPath, 'package-with-directory-provider'), 'junction')

      const atomApplication = buildAtomApplication()
      atomApplication.config.set('core.disabledPackages', ['fuzzy-finder'])

      const remotePath = 'remote://server:3437/some/directory/path'
      let window = atomApplication.launch(parseCommandLine([remotePath]))

      await focusWindow(window)
      await conditionPromise(async () => (await getProjectDirectories()).length > 0)
      let directories = await getProjectDirectories()
      assert.deepEqual(directories, [{type: 'FakeRemoteDirectory', path: remotePath}])

      await window.reload()
      await focusWindow(window)
      directories = await getProjectDirectories()
      assert.deepEqual(directories, [{type: 'FakeRemoteDirectory', path: remotePath}])

      function getProjectDirectories () {
        return evalInWebContents(window.browserWindow.webContents, sendBackToMainProcess => {
          sendBackToMainProcess(atom.project.getDirectories().map(d => ({ type: d.constructor.name, path: d.getPath() })))
        })
      }
    })

    it('reopens any previously opened windows when launched with no path', async () => {
      if (process.platform === 'win32') return; // Test is too flakey on Windows

      const tempDirPath1 = makeTempDir()
      const tempDirPath2 = makeTempDir()

      const atomApplication1 = buildAtomApplication()
      const app1Window1 = atomApplication1.launch(parseCommandLine([tempDirPath1]))
      await emitterEventPromise(app1Window1, 'window:locations-opened')
      const app1Window2 = atomApplication1.launch(parseCommandLine([tempDirPath2]))
      await emitterEventPromise(app1Window2, 'window:locations-opened')

      await Promise.all([
        app1Window1.prepareToUnload(),
        app1Window2.prepareToUnload()
      ])

      const atomApplication2 = buildAtomApplication()
      const [app2Window1, app2Window2] = atomApplication2.launch(parseCommandLine([]))
      await Promise.all([
        emitterEventPromise(app2Window1, 'window:locations-opened'),
        emitterEventPromise(app2Window2, 'window:locations-opened')
      ])

      assert.deepEqual(await getTreeViewRootDirectories(app2Window1), [tempDirPath1])
      assert.deepEqual(await getTreeViewRootDirectories(app2Window2), [tempDirPath2])
    })

    it('does not reopen any previously opened windows when launched with no path and `core.restorePreviousWindowsOnStart` is no', async () => {
      const atomApplication1 = buildAtomApplication()
      const app1Window1 = atomApplication1.launch(parseCommandLine([makeTempDir()]))
      await focusWindow(app1Window1)
      const app1Window2 = atomApplication1.launch(parseCommandLine([makeTempDir()]))
      await focusWindow(app1Window2)

      const configPath = path.join(process.env.ATOM_HOME, 'config.cson')
      const config = season.readFileSync(configPath)
      if (!config['*'].core) config['*'].core = {}
      config['*'].core.restorePreviousWindowsOnStart = 'no'
      season.writeFileSync(configPath, config)

      const atomApplication2 = buildAtomApplication()
      const app2Window = atomApplication2.launch(parseCommandLine([]))
      await focusWindow(app2Window)
      assert.deepEqual(app2Window.representedDirectoryPaths, [])
    })

    describe('when the `--wait` flag is passed', () => {
      let killedPids, atomApplication, onDidKillProcess

      beforeEach(() => {
        killedPids = []
        onDidKillProcess = null
        atomApplication = buildAtomApplication({
          killProcess (pid) {
            killedPids.push(pid)
            if (onDidKillProcess) onDidKillProcess()
          }
        })
      })

      it('kills the specified pid after a newly-opened window is closed', async () => {
        const window1 = atomApplication.launch(parseCommandLine(['--wait', '--pid', '101']))
        await focusWindow(window1)

        const [window2] = atomApplication.launch(parseCommandLine(['--new-window', '--wait', '--pid', '102']))
        await focusWindow(window2)
        assert.deepEqual(killedPids, [])

        let processKillPromise = new Promise(resolve => { onDidKillProcess = resolve })
        window1.close()
        await processKillPromise
        assert.deepEqual(killedPids, [101])

        processKillPromise = new Promise(resolve => { onDidKillProcess = resolve })
        window2.close()
        await processKillPromise
        assert.deepEqual(killedPids, [101, 102])
      })

      it('kills the specified pid after a newly-opened file in an existing window is closed', async () => {
        const window = atomApplication.launch(parseCommandLine(['--wait', '--pid', '101']))
        await focusWindow(window)

        const filePath1 = temp.openSync('test').path
        const filePath2 = temp.openSync('test').path
        fs.writeFileSync(filePath1, 'File 1')
        fs.writeFileSync(filePath2, 'File 2')

        const reusedWindow = atomApplication.launch(parseCommandLine(['--wait', '--pid', '102', filePath1, filePath2]))
        assert.equal(reusedWindow, window)

        const activeEditorPath = await evalInWebContents(window.browserWindow.webContents, send => {
          const subscription = atom.workspace.onDidChangeActivePaneItem(editor => {
            send(editor.getPath())
            subscription.dispose()
          })
        })

        assert([filePath1, filePath2].includes(activeEditorPath))
        assert.deepEqual(killedPids, [])

        await evalInWebContents(window.browserWindow.webContents, send => {
          atom.workspace.getActivePaneItem().destroy()
          send()
        })
        await timeoutPromise(100)
        assert.deepEqual(killedPids, [])

        let processKillPromise = new Promise(resolve => { onDidKillProcess = resolve })
        await evalInWebContents(window.browserWindow.webContents, send => {
          atom.workspace.getActivePaneItem().destroy()
          send()
        })
        await processKillPromise
        assert.deepEqual(killedPids, [102])

        processKillPromise = new Promise(resolve => { onDidKillProcess = resolve })
        window.close()
        await processKillPromise
        assert.deepEqual(killedPids, [102, 101])
      })

      it('kills the specified pid after a newly-opened directory in an existing window is closed', async () => {
        const window = atomApplication.launch(parseCommandLine([]))
        await focusWindow(window)

        const dirPath1 = makeTempDir()
        const reusedWindow = atomApplication.launch(parseCommandLine(['--wait', '--pid', '101', dirPath1]))
        assert.equal(reusedWindow, window)
        assert.deepEqual(await getTreeViewRootDirectories(window), [dirPath1])
        assert.deepEqual(killedPids, [])

        const dirPath2 = makeTempDir()
        await evalInWebContents(window.browserWindow.webContents, (send, dirPath1, dirPath2) => {
          atom.project.setPaths([dirPath1, dirPath2])
          send()
        }, dirPath1, dirPath2)
        await timeoutPromise(100)
        assert.deepEqual(killedPids, [])

        let processKillPromise = new Promise(resolve => { onDidKillProcess = resolve })
        await evalInWebContents(window.browserWindow.webContents, (send, dirPath2) => {
          atom.project.setPaths([dirPath2])
          send()
        }, dirPath2)
        await processKillPromise
        assert.deepEqual(killedPids, [101])
      })
    })

    describe('when closing the last window', () => {
      if (process.platform === 'linux' || process.platform === 'win32') {
        it('quits the application', async () => {
          const atomApplication = buildAtomApplication()
          const window = atomApplication.launch(parseCommandLine([path.join(makeTempDir("a"), 'file-a')]))
          await focusWindow(window)
          window.close()
          await window.closedPromise
          await atomApplication.lastBeforeQuitPromise
          assert(electron.app.didQuit())
        })
      } else if (process.platform === 'darwin') {
        it('leaves the application open', async () => {
          const atomApplication = buildAtomApplication()
          const window = atomApplication.launch(parseCommandLine([path.join(makeTempDir("a"), 'file-a')]))
          await focusWindow(window)
          window.close()
          await window.closedPromise
          await timeoutPromise(1000)
          assert(!electron.app.didQuit())
        })
      }
    })

    describe('when adding or removing project folders', () => {
      it('stores the window state immediately', async () => {
        const dirA = makeTempDir()
        const dirB = makeTempDir()

        const atomApplication = buildAtomApplication()
        const window = atomApplication.launch(parseCommandLine([dirA, dirB]))
        await emitterEventPromise(window, 'window:locations-opened')
        await focusWindow(window)
        assert.deepEqual(await getTreeViewRootDirectories(window), [dirA, dirB])

        const saveStatePromise = emitterEventPromise(atomApplication, 'application:did-save-state')
        await evalInWebContents(window.browserWindow.webContents, (sendBackToMainProcess) => {
          atom.project.removePath(atom.project.getPaths()[0])
          sendBackToMainProcess(null)
        })
        assert.deepEqual(await getTreeViewRootDirectories(window), [dirB])
        await saveStatePromise

        // Window state should be saved when the project folder is removed
        const atomApplication2 = buildAtomApplication()
        const [window2] = atomApplication2.launch(parseCommandLine([]))
        await emitterEventPromise(window2, 'window:locations-opened')
        await focusWindow(window2)
        assert.deepEqual(await getTreeViewRootDirectories(window2), [dirB])
      })
    })

    describe('when opening atom:// URLs', () => {
      it('loads the urlMain file in a new window', async () => {
        const packagePath = path.join(__dirname, '..', 'fixtures', 'packages', 'package-with-url-main')
        const packagesDirPath = path.join(process.env.ATOM_HOME, 'packages')
        fs.mkdirSync(packagesDirPath)
        fs.symlinkSync(packagePath, path.join(packagesDirPath, 'package-with-url-main'), 'junction')

        const atomApplication = buildAtomApplication()
        const launchOptions = parseCommandLine([])
        launchOptions.urlsToOpen = ['atom://package-with-url-main/test']
        let windows = atomApplication.launch(launchOptions)
        await windows[0].loadedPromise

        let reached = await evalInWebContents(windows[0].browserWindow.webContents, sendBackToMainProcess => {
          sendBackToMainProcess(global.reachedUrlMain)
        })
        assert.equal(reached, true);
        windows[0].close();
      })

      it('triggers /core/open/file in the correct window', async function() {
        const dirAPath = makeTempDir('a')
        const dirBPath = makeTempDir('b')

        const atomApplication = buildAtomApplication()
        const window1 = atomApplication.launch(parseCommandLine([path.join(dirAPath)]))
        await focusWindow(window1)
        const window2 = atomApplication.launch(parseCommandLine([path.join(dirBPath)]))
        await focusWindow(window2)

        const fileA = path.join(dirAPath, 'file-a')
        const uriA = `atom://core/open/file?filename=${fileA}`
        const fileB = path.join(dirBPath, 'file-b')
        const uriB = `atom://core/open/file?filename=${fileB}`

        sinon.spy(window1, 'sendURIMessage')
        sinon.spy(window2, 'sendURIMessage')

        atomApplication.launch(parseCommandLine(['--uri-handler', uriA]))
        await conditionPromise(() => window1.sendURIMessage.calledWith(uriA), `window1 to be focused from ${fileA}`)

        atomApplication.launch(parseCommandLine(['--uri-handler', uriB]))
        await conditionPromise(() => window2.sendURIMessage.calledWith(uriB), `window2 to be focused from ${fileB}`)
      })
    })
  })

  it('waits until all the windows have saved their state before quitting', async () => {
    const dirAPath = makeTempDir("a")
    const dirBPath = makeTempDir("b")
    const atomApplication = buildAtomApplication()
    const window1 = atomApplication.launch(parseCommandLine([path.join(dirAPath, 'file-a')]))
    await focusWindow(window1)
    const window2 = atomApplication.launch(parseCommandLine([path.join(dirBPath, 'file-b')]))
    await focusWindow(window2)
    electron.app.quit()
    await new Promise(process.nextTick)
    assert(!electron.app.didQuit())

    await Promise.all([window1.lastPrepareToUnloadPromise, window2.lastPrepareToUnloadPromise])
    await new Promise(process.nextTick)
    assert(electron.app.didQuit())
  })

  it('prevents quitting if user cancels when prompted to save an item', async () => {
    const atomApplication = buildAtomApplication()
    const window1 = atomApplication.launch(parseCommandLine([]))
    const window2 = atomApplication.launch(parseCommandLine([]))
    await Promise.all([window1.loadedPromise, window2.loadedPromise])
    await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
      atom.workspace.getActiveTextEditor().insertText('unsaved text')
      sendBackToMainProcess()
    })

    // Choosing "Cancel"
    mockElectronShowMessageBox({response: 1})
    electron.app.quit()
    await atomApplication.lastBeforeQuitPromise
    assert(!electron.app.didQuit())
    assert.equal(electron.app.quit.callCount, 1) // Ensure choosing "Cancel" doesn't try to quit the electron app more than once (regression)

    // Choosing "Don't save"
    mockElectronShowMessageBox({response: 2})
    electron.app.quit()
    await atomApplication.lastBeforeQuitPromise
    assert(electron.app.didQuit())
  })

  function buildAtomApplication (params = {}) {
    const atomApplication = new AtomApplication(Object.assign({
      resourcePath: ATOM_RESOURCE_PATH,
      atomHomeDirPath: process.env.ATOM_HOME,
    }, params))
    atomApplicationsToDestroy.push(atomApplication)
    return atomApplication
  }

  async function focusWindow (window) {
    window.focus()
    await window.loadedPromise
    await conditionPromise(() => window.atomApplication.getLastFocusedWindow() === window)
  }

  function mockElectronAppQuit () {
    let didQuit = false

    electron.app.quit = function () {
      this.quit.callCount++
      let defaultPrevented = false
      this.emit('before-quit', {preventDefault() { defaultPrevented = true }})
      if (!defaultPrevented) didQuit = true
    }

    electron.app.quit.callCount = 0

    electron.app.didQuit = () => didQuit
  }

  function mockElectronShowMessageBox ({response}) {
    electron.dialog.showMessageBox = (window, options, callback) => {
      callback(response)
    }
  }

  function makeTempDir (name) {
    return fs.realpathSync(temp.mkdirSync(name))
  }

  let channelIdCounter = 0
  function evalInWebContents (webContents, source, ...args) {
    const channelId = 'eval-result-' + channelIdCounter++
    return new Promise(resolve => {
      electron.ipcMain.on(channelId, receiveResult)

      function receiveResult (event, result) {
        electron.ipcMain.removeListener('eval-result', receiveResult)
        resolve(result)
      }

      webContents.executeJavaScript(dedent`
        function sendBackToMainProcess (result) {
          require('electron').ipcRenderer.send('${channelId}', result)
        }
        (${source})(sendBackToMainProcess, ${args.map(JSON.stringify).join(', ')})
      `)
    })
  }

  function getTreeViewRootDirectories (atomWindow) {
    return evalInWebContents(atomWindow.browserWindow.webContents, sendBackToMainProcess => {
      atom.workspace.getLeftDock().observeActivePaneItem((treeView) => {
        if (treeView) {
          sendBackToMainProcess(
            Array
              .from(treeView.element.querySelectorAll('.project-root > .header .name'))
              .map(element => element.dataset.path)
          )
        }
      })
    })
  }

  function clearElectronSession () {
    return new Promise(resolve => {
      electron.session.defaultSession.clearStorageData(() => {
        // Resolve promise on next tick, otherwise the process stalls. This
        // might be a bug in Electron, but it's probably fixed on the newer
        // versions.
        process.nextTick(resolve)
      })
    })
  }
})
