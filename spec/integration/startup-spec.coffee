# These tests are excluded by default. To run them from the command line:
#
# ATOM_INTEGRATION_TESTS_ENABLED=true apm test
return unless process.env.ATOM_INTEGRATION_TESTS_ENABLED

fs = require "fs"
path = require "path"
temp = require("temp").track()
AtomHome = temp.mkdirSync('atom-home')
fs.writeFileSync(path.join(AtomHome, 'config.cson'), fs.readFileSync(path.join(__dirname, 'fixtures', 'atom-home', 'config.cson')))
runAtom = require("./helpers/start-atom")

describe "Starting Atom", ->
  beforeEach ->
    jasmine.useRealClock()

  describe "opening paths via commmand-line arguments", ->
    [tempDirPath, tempFilePath, otherTempDirPath] = []

    beforeEach ->
      tempDirPath = temp.mkdirSync("empty-dir")
      otherTempDirPath = temp.mkdirSync("another-temp-dir")
      tempFilePath = path.join(tempDirPath, "an-existing-file")
      fs.writeFileSync(tempFilePath, "This file was already here.")

    it "reuses existing windows when directories are reopened", ->
      runAtom [path.join(tempDirPath, "new-file")], {ATOM_HOME: AtomHome}, (client) ->
        client

          # Opening a new file creates one window with one empty text editor.
          .waitForExist("atom-text-editor", 5000)
          .then((exists) -> expect(exists).toBe true)
          .waitForWindowCount(1, 1000)
          .waitForPaneItemCount(1, 1000)
          .execute(-> atom.project.getPaths())
          .then(({value}) -> expect(value).toEqual([tempDirPath]))

          # Typing in the editor changes its text.
          .execute(-> atom.workspace.getActiveTextEditor().getText())
          .then(({value}) -> expect(value).toBe "")
          .click("atom-text-editor")
          .keys("Hello!")
          .execute(-> atom.workspace.getActiveTextEditor().getText())
          .then(({value}) -> expect(value).toBe "Hello!")

          # Opening an existing file in the same directory reuses the window and
          # adds a new tab for the file.
          .startAnotherAtom([tempFilePath], ATOM_HOME: AtomHome)
          .waitForExist("atom-workspace")
          .waitForPaneItemCount(2, 5000)
          .waitForWindowCount(1, 1000)
          .execute(-> atom.workspace.getActiveTextEditor().getText())
          .then(({value}) -> expect(value).toBe "This file was already here.")

          # Opening a different directory creates a second window with no
          # tabs open.
          .waitForNewWindow(->
            @startAnotherAtom([otherTempDirPath], ATOM_HOME: AtomHome)
          , 5000)
          .waitForExist("atom-workspace", 5000)
          .waitForPaneItemCount(0, 1000)

    it "saves the state of closed windows", ->
      runAtom [tempDirPath], {ATOM_HOME: AtomHome}, (client) ->
        client

          # In a second window, opening a new buffer creates a new tab.
          .waitForExist("atom-workspace", 5000)
          .waitForNewWindow(->
            @startAnotherAtom([otherTempDirPath], ATOM_HOME: AtomHome)
          , 5000)
          .waitForExist("atom-workspace", 5000)
          .waitForPaneItemCount(0, 3000)
          .execute(-> atom.workspace.open())
          .waitForPaneItemCount(1, 3000)

          # Closing that window and reopening that directory shows the
          # previously-created new buffer.
          .execute(-> atom.unloadEditorWindow())
          .close()
          .waitForWindowCount(1, 5000)
          .waitForNewWindow(->
            @startAnotherAtom([otherTempDirPath], ATOM_HOME: AtomHome)
          , 5000)
          .waitForExist("atom-workspace", 5000)
          .waitForPaneItemCount(1, 5000)

    it "allows multiple project directories to be passed as separate arguments", ->
      runAtom [tempDirPath, otherTempDirPath, "--multi-folder"], {ATOM_HOME: AtomHome}, (client) ->
        client
          .waitForExist("atom-workspace", 5000)
          .then((exists) -> expect(exists).toBe true)
          .execute(-> atom.project.getPaths())
          .then(({value}) -> expect(value).toEqual([tempDirPath, otherTempDirPath]))

          # Opening a file in one of the directories reuses the same window
          # and does not change the project paths.
          .startAnotherAtom([tempFilePath], ATOM_HOME: AtomHome)
          .waitForExist("atom-workspace", 5000)
          .waitForPaneItemCount(1, 5000)
          .execute(-> atom.project.getPaths())
          .then(({value}) -> expect(value).toEqual([tempDirPath, otherTempDirPath]))

    it "opens each path in its own window unless the --multi-folder flag is passed", ->
      runAtom [tempDirPath, otherTempDirPath], {ATOM_HOME: AtomHome}, (client) ->
        projectPaths = []

        client
          .waitForWindowCount(2, 5000)
          .windowHandles()
          .then ({value: windowHandles}) ->
            @window(windowHandles[0])
              .execute(-> atom.project.getPaths())
              .then ({value}) ->
                expect(value).toHaveLength(1)
                projectPaths.push(value[0])
              .window(windowHandles[1])
              .execute(-> atom.project.getPaths())
              .then ({value}) ->
                expect(value).toHaveLength(1)
                projectPaths.push(value[0])
              .then ->
                expect(projectPaths.sort()).toEqual([tempDirPath, otherTempDirPath].sort())

    it "opens the path in the current window if it doesn't have a project path yet", ->
      runAtom [], {ATOM_HOME: AtomHome}, (client) ->
        client
          .waitForExist("atom-workspace")
          .startAnotherAtom([tempDirPath], ATOM_HOME: AtomHome)
          .waitUntil((->
            @title()
              .then(({value}) -> value.indexOf(path.basename(tempDirPath)) >= 0)), 5000)
          .waitForWindowCount(1, 5000)

    it "always opens with a single untitled buffer when launched w/ no path", ->
      runAtom [], {ATOM_HOME: AtomHome}, (client) ->
        client
          .waitForExist("atom-workspace")
          .waitForPaneItemCount(1, 5000)

      runAtom [], {ATOM_HOME: AtomHome}, (client) ->
        client
          .waitForExist("atom-workspace")
          .waitForPaneItemCount(1, 5000)

          # Opening with no file paths always creates a new window, even if
          # existing windows have no project paths.
          .waitForNewWindow(->
            @startAnotherAtom([], ATOM_HOME: AtomHome)
          , 5000)
