# These tests are excluded by default. To run them from the command line:
#
# ATOM_INTEGRATION_TESTS_ENABLED=true apm test
return unless process.env.ATOM_INTEGRATION_TESTS_ENABLED
# Integration tests require a fast machine and, for now, we cannot afford to
# run them on Travis.
return if process.env.CI

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
