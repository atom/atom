fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()
runAtom = require './helpers/start-atom'

describe "Smoke Test", ->
  atomHome = temp.mkdirSync('atom-home')

  beforeEach ->
    jasmine.useRealClock()
    fs.writeFileSync(path.join(atomHome, 'config.cson'), fs.readFileSync(path.join(__dirname, 'fixtures', 'atom-home', 'config.cson')))

  it "can open a file in Atom and perform basic operations on it", ->
    tempDirPath = temp.mkdirSync("empty-dir")
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
