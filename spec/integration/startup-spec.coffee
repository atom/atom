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
          .startAnotherWindow([tempFilePath], ATOM_HOME: AtomHome)
          .waitForPaneItemCount(2, 5000)
          .waitForWindowCount(1, 1000)
          .execute(-> atom.workspace.getActiveTextEditor().getText())
          .then(({value}) -> expect(value).toBe "This file was already here.")

          # Opening a different directory creates a second window with no
          # tabs open.
          .startAnotherWindow([otherTempDirPath], ATOM_HOME: AtomHome)
          .waitForWindowCount(2, 5000)
          .then(({value}) -> @window(value[1]))
          .waitForExist("atom-workspace", 5000)
          .then((exists) -> expect(exists).toBe true)
          .waitForPaneItemCount(0, 1000)

    it "saves the state of closed windows", ->
      runAtom [otherTempDirPath], {ATOM_HOME: AtomHome}, (client) ->
        client

          # Opening a file in another window creates another window with a tab
          # open for that file.
          .waitForExist("atom-workspace", 5000)
          .startAnotherWindow([tempFilePath], ATOM_HOME: AtomHome)
          .waitForWindowCount(2, 5000)
          .then(({value}) -> @window(value[1]))
          .waitForExist("atom-text-editor", 5000)
          .click("atom-text-editor")
          .execute(-> atom.workspace.getActiveTextEditor().getText())
          .then(({value}) -> expect(value).toBe "This file was already here.")

          # Closing that window and reopening that directory shows the
          # previously-opened file.
          .execute(-> atom.unloadEditorWindow())
          .close()
          .waitForWindowCount(1, 5000)
          .startAnotherWindow([tempDirPath], ATOM_HOME: AtomHome)
          .waitForWindowCount(2, 5000)
          .then(({value}) -> @window(value[1]))
          .waitForExist("atom-text-editor", 5000)
          .execute(-> atom.workspace.getActiveTextEditor().getText())
          .then(({value}) -> expect(value).toBe "This file was already here.")

    it "allows multiple project directories to be passed as separate arguments", ->
      runAtom [tempDirPath, otherTempDirPath], {ATOM_HOME: AtomHome}, (client) ->
        client
          .waitForExist("atom-workspace", 5000)
          .then((exists) -> expect(exists).toBe true)
          .execute(-> atom.project.getPaths())
          .then(({value}) -> expect(value).toEqual([tempDirPath, otherTempDirPath]))

          # Opening a file in one of the directories reuses the same window
          # and does not change the project paths.
          .startAnotherWindow([tempFilePath], ATOM_HOME: AtomHome)
          .waitForPaneItemCount(1, 5000)
          .execute(-> atom.project.getPaths())
          .then(({value}) -> expect(value).toEqual([tempDirPath, otherTempDirPath]))
