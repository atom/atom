/* globals assert */

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
    describe('with no paths', () => {
      it('reopens any previously opened windows', async () => {
        if (process.platform === 'win32') return // Test is too flakey on Windows

        const tempDirPath1 = makeTempDir()
        const tempDirPath2 = makeTempDir()

        const atomApplication1 = buildAtomApplication()
        const [app1Window1] = await atomApplication1.launch(parseCommandLine([tempDirPath1]))
        await emitterEventPromise(app1Window1, 'window:locations-opened')

        const [app1Window2] = await atomApplication1.launch(parseCommandLine([tempDirPath2]))
        await emitterEventPromise(app1Window2, 'window:locations-opened')

        await Promise.all([
          app1Window1.prepareToUnload(),
          app1Window2.prepareToUnload()
        ])

        const atomApplication2 = buildAtomApplication()
        const [app2Window1, app2Window2] = await atomApplication2.launch(parseCommandLine([]))
        await Promise.all([
          emitterEventPromise(app2Window1, 'window:locations-opened'),
          emitterEventPromise(app2Window2, 'window:locations-opened')
        ])

        assert.deepEqual(await getTreeViewRootDirectories(app2Window1), [tempDirPath1])
        assert.deepEqual(await getTreeViewRootDirectories(app2Window2), [tempDirPath2])
      })

      it('when windows already exist, opens a new window with a single untitled buffer', async () => {
        const atomApplication = buildAtomApplication()
        const [window1] = await atomApplication.launch(parseCommandLine([]))
        await focusWindow(window1)
        const window1EditorTitle = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
          sendBackToMainProcess(atom.workspace.getActiveTextEditor().getTitle())
        })
        assert.equal(window1EditorTitle, 'untitled')

        const window2 = atomApplication.openWithOptions(parseCommandLine([]))
        await window2.loadedPromise
        const window2EditorTitle = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
          sendBackToMainProcess(atom.workspace.getActiveTextEditor().getTitle())
        })
        assert.equal(window2EditorTitle, 'untitled')

        assert.deepEqual(atomApplication.getAllWindows(), [window2, window1])
      })

      it('when no windows are open but --new-window is passed, opens a new window with a single untitled buffer', async () => {
        // Populate some saved state
        const tempDirPath1 = makeTempDir()
        const tempDirPath2 = makeTempDir()

        const atomApplication1 = buildAtomApplication()
        const [app1Window1] = await atomApplication1.launch(parseCommandLine([tempDirPath1]))
        await emitterEventPromise(app1Window1, 'window:locations-opened')

        const [app1Window2] = await atomApplication1.launch(parseCommandLine([tempDirPath2]))
        await emitterEventPromise(app1Window2, 'window:locations-opened')

        await Promise.all([
          app1Window1.prepareToUnload(),
          app1Window2.prepareToUnload()
        ])

        // Launch with --new-window
        const atomApplication2 = buildAtomApplication()
        const appWindows2 = await atomApplication2.launch(parseCommandLine(['--new-window']))
        assert.lengthOf(appWindows2, 1)
        const [appWindow2] = appWindows2
        await appWindow2.loadedPromise
        const window2EditorTitle = await evalInWebContents(appWindow2.browserWindow.webContents, sendBackToMainProcess => {
          sendBackToMainProcess(atom.workspace.getActiveTextEditor().getTitle())
        })
        assert.equal(window2EditorTitle, 'untitled')
      })

      it('does not open an empty editor if core.openEmptyEditorOnStart is false', async () => {
        const configPath = path.join(process.env.ATOM_HOME, 'config.cson')
        const config = season.readFileSync(configPath)
        if (!config['*'].core) config['*'].core = {}
        config['*'].core.openEmptyEditorOnStart = false
        season.writeFileSync(configPath, config)

        const atomApplication = buildAtomApplication()
        const [window1] = await atomApplication.launch(parseCommandLine([]))
        await focusWindow(window1)

       // wait a bit just to make sure we don't pass due to querying the render process before it loads
        await timeoutPromise(1000)

        const itemCount = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
          sendBackToMainProcess(atom.workspace.getActivePane().getItems().length)
        })
        assert.equal(itemCount, 0)
      })
    })

    describe('with file or folder paths', () => {
      it('shows all directories in the tree view when multiple directory paths are passed to Atom', async () => {
        const dirAPath = makeTempDir('a')
        const dirBPath = makeTempDir('b')
        const dirBSubdirPath = path.join(dirBPath, 'c')
        fs.mkdirSync(dirBSubdirPath)

        const atomApplication = buildAtomApplication()
        const [window1] = await atomApplication.launch(parseCommandLine([dirAPath, dirBPath]))
        await focusWindow(window1)

        await conditionPromise(async () => (await getTreeViewRootDirectories(window1)).length === 2)
        assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath, dirBPath])
      })

      it('can open to a specific line number of a file', async () => {
        const filePath = path.join(makeTempDir(), 'new-file')
        fs.writeFileSync(filePath, '1\n2\n3\n4\n')
        const atomApplication = buildAtomApplication()

        const [window] = await atomApplication.launch(parseCommandLine([filePath + ':3']))
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

        const [window] = await atomApplication.launch(parseCommandLine([filePath + ':2:2']))
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

        const [window] = await atomApplication.launch(parseCommandLine([filePath + '::   ']))
        await focusWindow(window)

        const openedPath = await evalInWebContents(window.browserWindow.webContents, sendBackToMainProcess => {
          atom.workspace.observeTextEditors(textEditor => {
            sendBackToMainProcess(textEditor.getPath())
          })
        })

        assert.equal(openedPath, filePath)
      })

      it('opens an empty text editor when launched with a new file path', async () => {
        // Choosing "Don't save"
        mockElectronShowMessageBox({response: 2})

        const atomApplication = buildAtomApplication()
        const newFilePath = path.join(makeTempDir(), 'new-file')
        const [window] = await atomApplication.launch(parseCommandLine([newFilePath]))
        await focusWindow(window)
        const {editorTitle, editorText} = await evalInWebContents(window.browserWindow.webContents, sendBackToMainProcess => {
          atom.workspace.observeTextEditors(editor => {
            sendBackToMainProcess({editorTitle: editor.getTitle(), editorText: editor.getText()})
          })
        })
        assert.equal(editorTitle, path.basename(newFilePath))
        assert.equal(editorText, '')
        assert.deepEqual(await getTreeViewRootDirectories(window), [])
      })
    })

    describe('when the --add option is specified', () => {
      it('adds folders to existing windows when the --add option is used', async () => {
        const dirAPath = makeTempDir('a')
        const dirBPath = makeTempDir('b')
        const dirCPath = makeTempDir('c')
        const existingDirCFilePath = path.join(dirCPath, 'existing-file')
        fs.writeFileSync(existingDirCFilePath, 'this is an existing file')

        const atomApplication = buildAtomApplication()
        const [window1] = await atomApplication.launch(parseCommandLine([dirAPath]))
        await focusWindow(window1)

        await conditionPromise(async () => (await getTreeViewRootDirectories(window1)).length === 1)
        assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath])

        // When opening *files* with --add, reuses an existing window
        let [reusedWindow] = await atomApplication.launch(parseCommandLine([existingDirCFilePath, '--add']))
        assert.equal(reusedWindow, window1)
        assert.deepEqual(atomApplication.getAllWindows(), [window1])
        let activeEditorPath = await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
          const subscription = atom.workspace.onDidChangeActivePaneItem(textEditor => {
            sendBackToMainProcess(textEditor.getPath())
            subscription.dispose()
          })
        })
        assert.equal(activeEditorPath, existingDirCFilePath)
        assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath])

        // When opening *directories* with --add, reuses an existing window and adds the directory to the project
        reusedWindow = (await atomApplication.launch(parseCommandLine([dirBPath, '-a'])))[0]
        assert.equal(reusedWindow, window1)
        assert.deepEqual(atomApplication.getAllWindows(), [window1])

        await conditionPromise(async () => (await getTreeViewRootDirectories(reusedWindow)).length === 2)
        assert.deepEqual(await getTreeViewRootDirectories(window1), [dirAPath, dirBPath])
      })
    })

    if (process.platform === 'darwin' || process.platform === 'win32') {
      it('positions new windows at an offset distance from the previous window', async () => {
        const atomApplication = buildAtomApplication()

        const [window1] = await atomApplication.launch(parseCommandLine([makeTempDir()]))
        await focusWindow(window1)
        window1.browserWindow.setBounds({width: 400, height: 400, x: 0, y: 0})

        const [window2] = await atomApplication.launch(parseCommandLine([makeTempDir()]))
        await focusWindow(window2)

        assert.notEqual(window1, window2)
        const window1Dimensions = window1.getDimensions()
        const window2Dimensions = window2.getDimensions()
        assert.isAbove(window2Dimensions.x, window1Dimensions.x)
        assert.isAbove(window2Dimensions.y, window1Dimensions.y)
      })
    }

    it('persists window state based on the project directories', async () => {
      // Choosing "Don't save"
      mockElectronShowMessageBox({response: 2})

      const tempDirPath = makeTempDir()
      const atomApplication = buildAtomApplication()
      const nonExistentFilePath = path.join(tempDirPath, 'new-file')

      const [window1] = await atomApplication.launch(parseCommandLine([tempDirPath, nonExistentFilePath]))
      await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
        atom.workspace.observeTextEditors(textEditor => {
          textEditor.insertText('Hello World!')
          sendBackToMainProcess(null)
        })
      })
      await window1.prepareToUnload()
      window1.close()
      await window1.closedPromise

      // Restore unsaved state when opening the same project directory
      const [window2] = await atomApplication.launch(parseCommandLine([tempDirPath]))
      await window2.loadedPromise
      const window2Text = await evalInWebContents(window2.browserWindow.webContents, sendBackToMainProcess => {
        const textEditor = atom.workspace.getActiveTextEditor()
        textEditor.moveToBottom()
        textEditor.insertText(' How are you?')
        sendBackToMainProcess(textEditor.getText())
      })
      assert.equal(window2Text, 'Hello World! How are you?')
    })

    it('adds a remote directory to the project when launched with a remote directory', async () => {
      const packagePath = path.join(__dirname, '..', 'fixtures', 'packages', 'package-with-directory-provider')
      const packagesDirPath = path.join(process.env.ATOM_HOME, 'packages')
      fs.mkdirSync(packagesDirPath)
      fs.symlinkSync(packagePath, path.join(packagesDirPath, 'package-with-directory-provider'), 'junction')

      const atomApplication = buildAtomApplication()
      atomApplication.config.set('core.disabledPackages', ['fuzzy-finder'])

      const remotePath = 'remote://server:3437/some/directory/path'
      let [window] = await atomApplication.launch(parseCommandLine([remotePath]))

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

    it('does not reopen any previously opened windows when launched with no path and `core.restorePreviousWindowsOnStart` is no', async () => {
      const atomApplication1 = buildAtomApplication()
      const [app1Window1] = await atomApplication1.launch(parseCommandLine([makeTempDir()]))
      await focusWindow(app1Window1)

      const [app1Window2] = await atomApplication1.launch(parseCommandLine([makeTempDir()]))
      await focusWindow(app1Window2)

      const configPath = path.join(process.env.ATOM_HOME, 'config.cson')
      const config = season.readFileSync(configPath)
      if (!config['*'].core) config['*'].core = {}
      config['*'].core.restorePreviousWindowsOnStart = 'no'
      season.writeFileSync(configPath, config)

      const atomApplication2 = buildAtomApplication()
      const [app2Window] = await atomApplication2.launch(parseCommandLine([]))
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
        const [window1] = await atomApplication.launch(parseCommandLine(['--wait', '--pid', '101']))
        await focusWindow(window1)

        const [window2] = await atomApplication.launch(parseCommandLine(['--new-window', '--wait', '--pid', '102']))
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
        const projectDir = makeTempDir('existing')
        const filePath1 = path.join(projectDir, 'file-1')
        const filePath2 = path.join(projectDir, 'file-2')
        fs.writeFileSync(filePath1, 'File 1')
        fs.writeFileSync(filePath2, 'File 2')

        const [window] = await atomApplication.launch(parseCommandLine(['--wait', '--pid', '101', projectDir]))
        await focusWindow(window)

        const [reusedWindow] = await atomApplication.launch(parseCommandLine(['--add', '--wait', '--pid', '102', filePath1, filePath2]))
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
        const [window] = await atomApplication.launch(parseCommandLine([]))
        await focusWindow(window)

        const dirPath1 = makeTempDir()
        const [reusedWindow] = await atomApplication.launch(parseCommandLine(['--add', '--wait', '--pid', '101', dirPath1]))
        assert.equal(reusedWindow, window)
        await conditionPromise(async () => (await getTreeViewRootDirectories(window)).length === 1)
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
          const [window] = await atomApplication.launch(parseCommandLine([path.join(makeTempDir('a'), 'file-a')]))
          await focusWindow(window)
          window.close()
          await window.closedPromise
          await atomApplication.lastBeforeQuitPromise
          assert(electron.app.didQuit())
        })
      } else if (process.platform === 'darwin') {
        it('leaves the application open', async () => {
          const atomApplication = buildAtomApplication()
          const [window] = await atomApplication.launch(parseCommandLine([path.join(makeTempDir('a'), 'file-a')]))
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
        const [window0] = await atomApplication.launch(parseCommandLine([dirA, dirB]))
        await focusWindow(window0)
        await conditionPromise(async () => (await getTreeViewRootDirectories(window0)).length === 2)
        assert.deepEqual(await getTreeViewRootDirectories(window0), [dirA, dirB])

        const saveStatePromise = emitterEventPromise(atomApplication, 'application:did-save-state')
        await evalInWebContents(window0.browserWindow.webContents, (sendBackToMainProcess) => {
          atom.project.removePath(atom.project.getPaths()[0])
          sendBackToMainProcess(null)
        })
        assert.deepEqual(await getTreeViewRootDirectories(window0), [dirB])
        await saveStatePromise

        // Window state should be saved when the project folder is removed
        const atomApplication2 = buildAtomApplication()
        const [window2] = await atomApplication2.launch(parseCommandLine([]))
        await focusWindow(window2)
        await conditionPromise(async () => (await getTreeViewRootDirectories(window2)).length === 1)
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
        let [windows] = await atomApplication.launch(launchOptions)
        await windows[0].loadedPromise

        let reached = await evalInWebContents(windows[0].browserWindow.webContents, sendBackToMainProcess => {
          sendBackToMainProcess(global.reachedUrlMain)
        })
        assert.isTrue(reached)
        windows[0].close()
      })

      it('triggers /core/open/file in the correct window', async function () {
        const dirAPath = makeTempDir('a')
        const dirBPath = makeTempDir('b')

        const atomApplication = buildAtomApplication()
        const [window1] = await atomApplication.launch(parseCommandLine([path.join(dirAPath)]))
        await focusWindow(window1)
        const [window2] = await atomApplication.launch(parseCommandLine([path.join(dirBPath)]))
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
    const dirAPath = makeTempDir('a')
    const dirBPath = makeTempDir('b')
    const atomApplication = buildAtomApplication()
    const [window1] = await atomApplication.launch(parseCommandLine([dirAPath]))
    await focusWindow(window1)
    const [window2] = await atomApplication.launch(parseCommandLine([dirBPath]))
    await focusWindow(window2)
    electron.app.quit()
    await new Promise(process.nextTick)
    assert(!electron.app.didQuit())

    await Promise.all([window1.lastPrepareToUnloadPromise, window2.lastPrepareToUnloadPromise])
    assert(!electron.app.didQuit())
    await atomApplication.lastBeforeQuitPromise
    await new Promise(process.nextTick)
    assert(electron.app.didQuit())
  })

  it('prevents quitting if user cancels when prompted to save an item', async () => {
    const atomApplication = buildAtomApplication()
    const [window1] = await atomApplication.launch(parseCommandLine([]))
    const [window2] = await atomApplication.launch(parseCommandLine([]))
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

  it('closes successfully unloaded windows when quitting', async () => {
    const atomApplication = buildAtomApplication()
    const [window1] = await atomApplication.launch(parseCommandLine([]))
    const [window2] = await atomApplication.launch(parseCommandLine([]))
    await Promise.all([window1.loadedPromise, window2.loadedPromise])
    await evalInWebContents(window1.browserWindow.webContents, sendBackToMainProcess => {
      atom.workspace.getActiveTextEditor().insertText('unsaved text')
      sendBackToMainProcess()
    })

    // Choosing "Cancel"
    mockElectronShowMessageBox({response: 1})
    electron.app.quit()
    await atomApplication.lastBeforeQuitPromise
    assert(atomApplication.getAllWindows().length === 1)

    // Choosing "Don't save"
    mockElectronShowMessageBox({response: 2})
    electron.app.quit()
    await atomApplication.lastBeforeQuitPromise
    assert(atomApplication.getAllWindows().length === 0)
  })

  if (process.platform === 'darwin') {
    it('allows opening a new folder after all windows are closed', async () => {
      const atomApplication = buildAtomApplication()
      sinon.stub(atomApplication, 'promptForPathToOpen')

      // Open a window and then close it, leaving the app running
      const [window] = await atomApplication.launch(parseCommandLine([]))
      await focusWindow(window)
      window.close()
      await window.closedPromise

      atomApplication.emit('application:open')
      await conditionPromise(() => atomApplication.promptForPathToOpen.calledWith('all'))
      atomApplication.promptForPathToOpen.reset()

      atomApplication.emit('application:open-file')
      await conditionPromise(() => atomApplication.promptForPathToOpen.calledWith('file'))
      atomApplication.promptForPathToOpen.reset()

      atomApplication.emit('application:open-folder')
      await conditionPromise(() => atomApplication.promptForPathToOpen.calledWith('file'))
      atomApplication.promptForPathToOpen.reset()
    })
  }

  function buildAtomApplication (params = {}) {
    const atomApplication = new AtomApplication(Object.assign({
      resourcePath: ATOM_RESOURCE_PATH,
      atomHomeDirPath: process.env.ATOM_HOME
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
      this.emit('before-quit', {preventDefault () { defaultPrevented = true }})
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

      const js = dedent`
        function sendBackToMainProcess (result) {
          require('electron').ipcRenderer.send('${channelId}', result)
        }
        (${source})(sendBackToMainProcess, ${args.map(JSON.stringify).join(', ')})
      `
      // console.log(`about to execute:\n${js}`)

      webContents.executeJavaScript(js)
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
        } else {
          sendBackToMainProcess([])
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
