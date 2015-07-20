# These tests are excluded by default. To run them from the command line:
#
# ATOM_INTEGRATION_TESTS_ENABLED=true apm test
return unless process.env.ATOM_INTEGRATION_TESTS_ENABLED
# Integration tests require a fast machine and, for now, we cannot afford to
# run them on Travis.
return if process.env.TRAVIS

fs = require "fs"
path = require "path"
temp = require("temp").track()
runAtom = require "./helpers/start-atom"

describe "Starting Atom", ->
  [tempDirPath, otherTempDirPath, atomHome] = []

  beforeEach ->
    jasmine.useRealClock()

    atomHome = temp.mkdirSync('atom-home')
    fs.writeFileSync(path.join(atomHome, 'config.cson'), fs.readFileSync(path.join(__dirname, 'fixtures', 'atom-home', 'config.cson')))
    tempDirPath = temp.mkdirSync("empty-dir")
    otherTempDirPath = temp.mkdirSync("another-temp-dir")

  describe "opening a new file", ->
    it "opens the parent directory and creates an empty text editor", ->
      runAtom [path.join(tempDirPath, "new-file")], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForWindowCount(1, 1000)
          .waitForExist("atom-workspace", 5000)
          .waitForPaneItemCount(1, 1000)

          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([tempDirPath])

          .waitForExist("atom-text-editor", 5000)
          .then (exists) -> expect(exists).toBe true
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
          .waitForWindowCount(1, 1000)
          .waitForExist("atom-workspace", 5000)
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
          .waitForWindowCount(1, 1000)
          .waitForExist("atom-workspace", 5000)
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
          .waitForWindowCount(1, 1000)
          .waitForExist("atom-workspace", 5000)
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
          .waitForWindowCount(1, 1000)
          .waitForExist("atom-workspace", 5000)
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
          .waitForExist("atom-workspace", 5000)
          .waitForPaneItemCount(0, 1000)
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([otherTempDirPath])

  describe "reopening a directory that was previously opened", ->
    it "remembers the state of the window", ->
      runAtom [tempDirPath], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForExist("atom-workspace", 5000)
          .waitForPaneItemCount(0, 3000)
          .execute -> atom.workspace.open()
          .waitForPaneItemCount(1, 3000)

      runAtom [tempDirPath], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForExist("atom-workspace", 5000)
          .waitForPaneItemCount(1, 5000)

  describe "opening multiple directories simultaneously", ->
    it "shows them all in the tree-view", ->
      nestedDir = path.join(otherTempDirPath, "nested-dir")
      fs.mkdirSync(nestedDir)

      runAtom [tempDirPath, otherTempDirPath], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForExist("atom-workspace", 5000)
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([tempDirPath, otherTempDirPath])

          # Opening one of those directories again reuses the same window and
          # does not change the project paths.
          .startAnotherAtom([nestedDir], ATOM_HOME: atomHome)
          .waitForExist("atom-workspace", 5000)
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([tempDirPath, otherTempDirPath])

  describe "when there is an existing window with no project path", ->
    it "reuses that window to open a directory", ->
      runAtom [], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForExist("atom-workspace")
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
          .waitForExist("atom-workspace")
          .waitForPaneItemCount(1, 5000)

          # Opening with no file paths always creates a new window, even if
          # existing windows have no project paths.
          .waitForNewWindow(->
            @startAnotherAtom([], ATOM_HOME: atomHome)
          , 5000)
          .waitForExist("atom-workspace")
          .waitForPaneItemCount(1, 5000)

    it "reopens any previously opened windows", ->
      runAtom [tempDirPath], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForExist("atom-workspace")
          .waitForNewWindow(->
            @startAnotherAtom([otherTempDirPath], ATOM_HOME: atomHome)
          , 5000)
          .waitForExist("atom-workspace")

      runAtom [], {ATOM_HOME: atomHome}, (client) ->
        windowProjectPaths = []

        client
          .waitForWindowCount(2, 10000)
          .then ({value: windowHandles}) ->
            @window(windowHandles[0])
            .waitForExist("atom-workspace")
            .treeViewRootDirectories()
            .then ({value: directories}) -> windowProjectPaths.push(directories)

            .window(windowHandles[1])
            .waitForExist("atom-workspace")
            .treeViewRootDirectories()
            .then ({value: directories}) -> windowProjectPaths.push(directories)

            .call ->
              expect(windowProjectPaths.sort()).toEqual [
                [tempDirPath]
                [otherTempDirPath]
              ].sort()

  describe "opening a remote directory", ->
    it "opens the parent directory and creates an empty text editor", ->
      remoteDirectory = 'remote://server:3437/some/directory/path'
      runAtom [remoteDirectory], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForWindowCount(1, 1000)
          .waitForExist("atom-workspace", 5000)
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([remoteDirectory])
