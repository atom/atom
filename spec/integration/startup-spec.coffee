# These tests are excluded by default. To run them from the command line:
#
# ATOM_INTEGRATION_TESTS_ENABLED=true apm test
return unless process.env.ATOM_INTEGRATION_TESTS_ENABLED

fs = require "fs"
path = require "path"
temp = require("temp").track()
AtomHome = path.join(__dirname, "fixtures", "atom-home")
{startAtom, startAnotherAtom, driverTest} = require("./helpers/start-atom")

describe "Starting Atom", ->
  beforeEach ->
    jasmine.useRealClock()

  describe "opening paths via commmand-line arguments", ->
    [tempDirPath, tempFilePath] = []

    beforeEach ->
      tempDirPath = temp.mkdirSync("empty-dir")
      tempFilePath = path.join(tempDirPath, "an-existing-file")
      fs.writeFileSync(tempFilePath, "This was already here.")

    it "reuses existing windows when directories are reopened", ->
      driverTest ->

        # Opening a new file creates one window with one empty text editor.
        startAtom([path.join(tempDirPath, "new-file")], ATOM_HOME: AtomHome)
          .waitForExist("atom-text-editor", 5000)
          .then((exists) -> expect(exists).toBe true)
          .windowHandles()
          .then(({value}) -> expect(value.length).toBe 1)
          .execute(-> atom.workspace.getActivePane().getItems().length)
          .then(({value}) -> expect(value).toBe 1)

          # Typing in the editor changes its text.
          .execute(-> atom.workspace.getActiveTextEditor().getText())
          .then(({value}) -> expect(value).toBe "")
          .click("atom-text-editor")
          .keys("Hello!")
          .execute(-> atom.workspace.getActiveTextEditor().getText())
          .then(({value}) -> expect(value).toBe "Hello!")

          # Opening an existing file in the same directory reuses the window and
          # adds a new tab for the file.
          .call(-> startAnotherAtom([tempFilePath], ATOM_HOME: AtomHome))
          .waitForCondition(
            (-> @execute((-> atom.workspace.getActivePane().getItems().length)).then ({value}) -> value is 2),
            5000)
          .then((result) -> expect(result).toBe(true))
          .execute(-> atom.workspace.getActiveTextEditor().getText())
          .then(({value}) -> expect(value).toBe "This was already here.")

          # Opening a different directory creates a second window with no
          # tabs open.
          .call(-> startAnotherAtom([temp.mkdirSync("another-empty-dir")], ATOM_HOME: AtomHome))
          .waitForCondition(
            (-> @windowHandles().then(({value}) -> value.length is 2)),
            5000)
          .then((result) -> expect(result).toBe(true))
          .windowHandles()
          .then(({value}) ->
            @window(value[1])
            .waitForExist("atom-workspace", 5000)
            .then((exists) -> expect(exists).toBe true)
            .execute(-> atom.workspace.getActivePane().getItems().length)
            .then(({value}) -> expect(value).toBe 0))
