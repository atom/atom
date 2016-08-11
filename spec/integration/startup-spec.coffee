# These tests are excluded by default. To run them from the command line:
#
# ATOM_INTEGRATION_TESTS_ENABLED=true apm test
return unless process.env.ATOM_INTEGRATION_TESTS_ENABLED

fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()
runAtom = require './helpers/start-atom'
CSON = require 'season'

describe "Starting Atom", ->
  atomHome = temp.mkdirSync('atom-home')
  [tempDirPath, otherTempDirPath] = []

  beforeEach ->
    jasmine.useRealClock()
    fs.writeFileSync(path.join(atomHome, 'config.cson'), fs.readFileSync(path.join(__dirname, 'fixtures', 'atom-home', 'config.cson')))
    fs.removeSync(path.join(atomHome, 'storage'))

    tempDirPath = temp.mkdirSync("empty-dir")
    otherTempDirPath = temp.mkdirSync("another-temp-dir")

  describe "opening a new file", ->
    it "opens the parent directory and creates an empty text editor", ->
      runAtom [path.join(tempDirPath, "new-file")], {ATOM_HOME: atomHome}, (client) ->
        client
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([tempDirPath])

          .waitForExist("atom-text-editor", 5000)
          .then (exists) -> expect(exists).toBe true
          .waitForPaneItemCount(1, 1000)
          .click("atom-text-editor")
          .keys("Hello!")
          .execute -> atom.workspace.getActiveTextEditor().getText()
          .then ({value}) -> expect(value).toBe "Hello!"
          .dispatchCommand("editor:delete-line")

    it "opens the file to the specified line number", ->
      filePath = path.join(fs.realpathSync(tempDirPath), "new-file")
      fs.writeFileSync filePath, """
        1
        2
        3
        4
      """

      runAtom ["#{filePath}:3"], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForPaneItemCount(1, 1000)
          .waitForExist("atom-text-editor", 5000)
          .then (exists) -> expect(exists).toBe true

          .execute -> atom.workspace.getActiveTextEditor().getPath()
          .then ({value}) -> expect(value).toBe filePath

          .execute -> atom.workspace.getActiveTextEditor().getCursorBufferPosition()
          .then ({value}) ->
            expect(value.row).toBe 2
            expect(value.column).toBe 0

    it "opens the file to the specified line number and column number", ->
      filePath = path.join(fs.realpathSync(tempDirPath), "new-file")
      fs.writeFileSync filePath, """
        1
        2
        3
        4
      """

      runAtom ["#{filePath}:2:2"], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForPaneItemCount(1, 1000)
          .waitForExist("atom-text-editor", 5000)
          .then (exists) -> expect(exists).toBe true

          .execute -> atom.workspace.getActiveTextEditor().getPath()
          .then ({value}) -> expect(value).toBe filePath

          .execute -> atom.workspace.getActiveTextEditor().getCursorBufferPosition()
          .then ({value}) ->
            expect(value.row).toBe 1
            expect(value.column).toBe 1

    it "removes all trailing whitespace and colons from the specified path", ->
      filePath = path.join(tempDirPath, "new-file")
      runAtom ["#{filePath}:  "], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForPaneItemCount(1, 1000)
          .waitForExist("atom-text-editor", 5000)
          .then (exists) -> expect(exists).toBe true

          .execute -> atom.workspace.getActiveTextEditor().getPath()
          .then ({value}) -> expect(value).toBe filePath

  describe "when there is already a window open", ->
    it "reuses that window when opening files, but not when opening directories", ->
      tempFilePath = path.join(temp.mkdirSync("a-third-dir"), "a-file")
      fs.writeFileSync(tempFilePath, "This file was already here.")

      runAtom [path.join(tempDirPath, "new-file")], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForPaneItemCount(1, 5000)

          # Opening another file reuses the same window and does not change the
          # project paths.
          .startAnotherAtom([tempFilePath], ATOM_HOME: atomHome)
          .waitForPaneItemCount(2, 5000)
          .waitForWindowCount(1, 1000)
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([tempDirPath])
          .execute -> atom.workspace.getActiveTextEditor().getText()
          .then ({value: text}) -> expect(text).toBe "This file was already here."

          # Opening another directory creates a second window.
          .waitForNewWindow(->
            @startAnotherAtom([otherTempDirPath], ATOM_HOME: atomHome)
          , 5000)
          .waitForPaneItemCount(0, 1000)
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([otherTempDirPath])
    describe "when using the -a, --add option", ->
      it "reuses that window and add the folder to project paths", ->
        fourthTempDir = temp.mkdirSync("a-fourth-dir")
        fourthTempFilePath = path.join(fourthTempDir, "a-file")
        fs.writeFileSync(fourthTempFilePath, "4 - This file was already here.")

        fifthTempDir = temp.mkdirSync("a-fifth-dir")
        fifthTempFilePath = path.join(fifthTempDir, "a-file")
        fs.writeFileSync(fifthTempFilePath, "5 - This file was already here.")

        runAtom [path.join(tempDirPath, "new-file")], {ATOM_HOME: atomHome}, (client) ->
          client
            .waitForPaneItemCount(1, 5000)

            # Opening another file reuses the same window and add parent dir to
            # project paths.
            .startAnotherAtom(['-a', fourthTempFilePath], ATOM_HOME: atomHome)
            .waitForPaneItemCount(2, 5000)
            .waitForWindowCount(1, 1000)
            .treeViewRootDirectories()
            .then ({value}) -> expect(value).toEqual([tempDirPath, fourthTempDir])
            .execute -> atom.workspace.getActiveTextEditor().getText()
            .then ({value: text}) -> expect(text).toBe "4 - This file was already here."

            # Opening another directory resuses the same window and add the folder to project paths.
            .startAnotherAtom(['--add', fifthTempDir], ATOM_HOME: atomHome)
            .treeViewRootDirectories()
            .then ({value}) -> expect(value).toEqual([tempDirPath, fourthTempDir, fifthTempDir])

    it "opens the new window offset from the other window", ->
      runAtom [path.join(tempDirPath, "new-file")], {ATOM_HOME: atomHome}, (client) ->
        win0Position = null
        win1Position = null
        client
          .waitForWindowCount(1, 10000)
          .execute -> atom.getPosition()
          .then ({value}) -> win0Position = value
          .waitForNewWindow(->
            @startAnotherAtom([path.join(temp.mkdirSync("a-third-dir"), "a-file")], ATOM_HOME: atomHome)
          , 5000)
          .waitForWindowCount(2, 10000)
          .execute -> atom.getPosition()
          .then ({value}) -> win1Position = value
          .then ->
            expect(win1Position.x).toBeGreaterThan(win0Position.x)
            # Ideally we'd test the y coordinate too, but if the window's
            # already as tall as it can be, then macOS won't move it down outside
            # the screen.
            # expect(win1Position.y).toBeGreaterThan(win0Position.y)

  describe "reopening a directory that was previously opened", ->
    it "remembers the state of the window", ->
      runAtom [tempDirPath], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForPaneItemCount(0, 3000)
          .execute -> atom.workspace.open()
          .waitForPaneItemCount(1, 3000)
          .keys("Hello!")
          .waitUntil((-> Promise.resolve(false)), 1100)

      runAtom [tempDirPath], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForPaneItemCount(1, 5000)

  describe "opening multiple directories simultaneously", ->
    it "shows them all in the tree-view", ->
      nestedDir = path.join(otherTempDirPath, "nested-dir")
      fs.mkdirSync(nestedDir)

      runAtom [tempDirPath, otherTempDirPath], {ATOM_HOME: atomHome}, (client) ->
        client
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([tempDirPath, otherTempDirPath])

          # Opening one of those directories again reuses the same window and
          # does not change the project paths.
          .startAnotherAtom([nestedDir], ATOM_HOME: atomHome)
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([tempDirPath, otherTempDirPath])

  describe "when there is an existing window with no project path", ->
    it "reuses that window to open a directory", ->
      runAtom [], {ATOM_HOME: atomHome}, (client) ->
        client
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([])

          .startAnotherAtom([tempDirPath], ATOM_HOME: atomHome)
          .waitUntil(->
            @treeViewRootDirectories()
            .then ({value}) -> value[0] is tempDirPath
          , 5000)
          .then (result) -> expect(result).toBe(true)
          .waitForWindowCount(1, 5000)

  describe "launching with no path", ->
    it "opens a new window with a single untitled buffer", ->
      runAtom [], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForPaneItemCount(1, 5000)

          # Opening with no file paths always creates a new window, even if
          # existing windows have no project paths.
          .waitForNewWindow(->
            @startAnotherAtom([], ATOM_HOME: atomHome)
          , 5000)
          .waitForPaneItemCount(1, 5000)

    it "doesn't open a new window if openEmptyEditorOnStart is disabled", ->
      configPath = path.join(atomHome, 'config.cson')
      config = CSON.readFileSync(configPath)
      config['*'].core = {openEmptyEditorOnStart: false}
      CSON.writeFileSync(configPath, config)

      runAtom [], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForPaneItemCount(0, 5000)

    it "reopens any previously opened windows", ->
      runAtom [tempDirPath], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForNewWindow(->
            @startAnotherAtom([otherTempDirPath], ATOM_HOME: atomHome)
          , 5000)

      runAtom [], {ATOM_HOME: atomHome}, (client) ->
        windowProjectPaths = []

        client
          .waitForWindowCount(2, 10000)
          .then ({value: windowHandles}) ->
            @window(windowHandles[0])
            .treeViewRootDirectories()
            .then ({value: directories}) -> windowProjectPaths.push(directories)

            .window(windowHandles[1])
            .treeViewRootDirectories()
            .then ({value: directories}) -> windowProjectPaths.push(directories)

            .call ->
              expect(windowProjectPaths.sort()).toEqual [
                [tempDirPath]
                [otherTempDirPath]
              ].sort()

    it "doesn't reopen any previously opened windows if restorePreviousWindowsOnStart is disabled", ->
      runAtom [tempDirPath], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForExist("atom-workspace")
          .waitForNewWindow(->
            @startAnotherAtom([otherTempDirPath], ATOM_HOME: atomHome)
          , 5000)
          .waitForExist("atom-workspace")

      configPath = path.join(atomHome, 'config.cson')
      config = CSON.readFileSync(configPath)
      config['*'].core = {restorePreviousWindowsOnStart: false}
      CSON.writeFileSync(configPath, config)

      runAtom [], {ATOM_HOME: atomHome}, (client) ->
        windowProjectPaths = []

        client
          .waitForWindowCount(1, 10000)
          .then ({value: windowHandles}) ->
            @window(windowHandles[0])
            .waitForExist("atom-workspace")
            .treeViewRootDirectories()
            .then ({value: directories}) -> windowProjectPaths.push(directories)

            .call ->
              expect(windowProjectPaths).toEqual [
                []
              ]

  describe "opening a remote directory", ->
    it "opens the parent directory and creates an empty text editor", ->
      remoteDirectory = 'remote://server:3437/some/directory/path'
      runAtom [remoteDirectory], {ATOM_HOME: atomHome}, (client) ->
        client
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([remoteDirectory])
