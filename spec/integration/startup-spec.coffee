os = require "os"
fs = require "fs"
path = require "path"
remote = require "remote"
temp = require("temp").track()
{spawn, spawnSync} = require "child_process"
{Builder, By} = require "../../build/node_modules/selenium-webdriver"

AtomPath = remote.process.argv[0]
AtomLauncherPath = path.join(__dirname, "helpers", "atom-launcher.sh")
SocketPath = path.join(os.tmpdir(), "atom-integration-test.sock")
ChromeDriverPort = 9515

describe "Starting Atom", ->
  if spawnSync("type", ["-P", "chromedriver"]).status isnt 0
    console.log "Skipping integration tests because the `chromedriver` executable was not found."
    return

  [chromeDriver, driver, tempDirPath] = []

  beforeEach ->
    tempDirPath = temp.mkdirSync("empty-dir")
    chromeDriver = spawn "chromedriver", ["--verbose", "--port=#{ChromeDriverPort}"]

    # Uncomment to see chromedriver debug output
    # chromeDriver.stderr.on "data", (d) -> console.log(d.toString())

  afterEach ->
    waitsForPromise -> driver.quit().thenFinally(-> chromeDriver.kill())

  startAtom = (args=[]) ->
    driver = new Builder()
      .usingServer("http://localhost:#{ChromeDriverPort}")
      .withCapabilities(
        chromeOptions:
          binary: AtomLauncherPath
          args: [
            "atom-path=#{AtomPath}"
            "atom-args=#{args.join(" ")}"
            "dev"
            "safe"
            "user-data-dir=#{temp.mkdirSync('integration-spec-')}"
            "socket-path=#{SocketPath}"
          ]
      )
      .forBrowser('atom')
      .build()

    waitsForPromise ->
      driver.wait ->
        driver.getTitle().then (title) -> title.indexOf("Atom") >= 0

  startAnotherAtom = (args=[]) ->
    spawnSync(AtomPath, args.concat([
      "--dev",
      "--safe",
      "--socket-path=#{SocketPath}"
    ]))

  describe "when given the name of a file that doesn't exist", ->
    tempFilePath = null

    beforeEach ->
      tempFilePath = path.join(tempDirPath, "an-existing-file")
      fs.writeFileSync(tempFilePath, "This was already here.")
      startAtom([path.join(tempDirPath, "new-file")])

    it "opens a new window with an empty text editor", ->
      waitsForPromise ->
        driver.getAllWindowHandles().then (handles) ->
          expect(handles.length).toBe 1
        driver.executeScript(-> atom.workspace.getActivePane().getItems().length).then (length) ->
          expect(length).toBe 1
        driver.executeScript(-> atom.workspace.getActiveTextEditor().getText()).then (text) ->
          expect(text).toBe("")
        driver.findElement(By.tagName("atom-text-editor")).sendKeys("Hello world!")
        driver.executeScript(-> atom.workspace.getActiveTextEditor().getText()).then (text) ->
          expect(text).toBe "Hello world!"

      # Opening another existing file in the same directory reuses the window,
      # and opens a new tab for the file.
      waitsForPromise ->
        startAnotherAtom([tempFilePath])
        driver.wait ->
          driver.executeScript(-> atom.workspace.getActivePane().getItems().length).then (length) ->
            length is 2
        driver.executeScript(-> atom.workspace.getActiveTextEditor().getText()).then (text) ->
          expect(text).toBe "This was already here."

      # Opening a different directory creates a new window.
      waitsForPromise ->
        startAnotherAtom([temp.mkdirSync("another-empty-dir")])
        driver.wait ->
          driver.getAllWindowHandles().then (handles) ->
            handles.length is 2

  describe "when given the name of a directory that exists", ->
    beforeEach ->
      startAtom([tempDirPath])

    it "opens a new window no text editors open", ->
      waitsForPromise ->
        driver.executeScript(-> atom.workspace.getActiveTextEditor()).then (editor) ->
          expect(editor).toBeNull()
