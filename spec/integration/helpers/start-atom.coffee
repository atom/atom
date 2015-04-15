path = require "path"
temp = require("temp").track()
remote = require "remote"
async = require "async"
{map, extend, once, difference} = require "underscore-plus"
{spawn, spawnSync} = require "child_process"
webdriverio = require "../../../build/node_modules/webdriverio"

AtomPath = remote.process.argv[0]
AtomLauncherPath = path.join(__dirname, "..", "helpers", "atom-launcher.sh")
ChromedriverPath = path.resolve(__dirname, '..', '..', '..', 'atom-shell', 'chromedriver', 'chromedriver')
SocketPath = path.join(temp.mkdirSync("socket-dir"), "atom-#{process.env.USER}.sock")
ChromedriverPort = 9515

buildAtomClient = (args, env) ->
  client = webdriverio.remote(
    host: 'localhost'
    port: ChromedriverPort
    desiredCapabilities:
      browserName: "atom"
      chromeOptions:
        binary: AtomLauncherPath
        args: [
          "atom-path=#{AtomPath}"
          "atom-args=#{args.join(" ")}"
          "atom-env=#{map(env, (value, key) -> "#{key}=#{value}").join(" ")}"
          "dev"
          "safe"
          "user-data-dir=#{temp.mkdirSync('atom-user-data-dir')}"
          "socket-path=#{SocketPath}"
        ])

  isRunning = false
  client.on "init", -> isRunning = true
  client.on "end", -> isRunning = false

  client
    .addCommand "waitUntil", (conditionFn, timeout, cb) ->
      timedOut = succeeded = false
      pollingInterval = Math.min(timeout, 100)
      setTimeout((-> timedOut = true), timeout)
      async.until(
        (-> succeeded or timedOut),
        ((next) =>
          setTimeout(=>
            conditionFn.call(this).then(
              ((result) ->
                succeeded = result
                next()),
              ((err) -> next(err))
            )
          , pollingInterval)),
        ((err) -> cb(err, succeeded)))

    .addCommand "waitForWindowCount", (count, timeout, cb) ->
      @waitUntil(->
        @windowHandles().then ({value}) -> value.length is count
      , timeout)
        .then (result) -> expect(result).toBe(true)
        .windowHandles(cb)

    .addCommand "waitForPaneItemCount", (count, timeout, cb) ->
      @waitUntil(->
        @execute(-> atom.workspace?.getActivePane()?.getItems().length)
          .then(({value}) -> value is count)
      , timeout)
        .then (result) ->
          expect(result).toBe(true)
          cb(null)

    .addCommand "treeViewRootDirectories", (cb) ->
      @execute(->
        for element in document.querySelectorAll(".tree-view .project-root > .header .name")
          element.dataset.path
      , cb)

    .addCommand "waitForNewWindow", (fn, timeout, done) ->
      @windowHandles (err, {value: oldWindowHandles}) ->
        return done() unless isRunning
        @call(fn)
          .waitForWindowCount(oldWindowHandles.length + 1, 5000)
          .then ({value: newWindowHandles}) ->
            [newWindowHandle] = difference(newWindowHandles, oldWindowHandles)
            return done() unless newWindowHandle
            @window(newWindowHandle, done)

    .addCommand "startAnotherAtom", (args, env, done) ->
      @call ->
        if isRunning
          spawnSync(AtomPath, args.concat([
            "--dev"
            "--safe"
            "--socket-path=#{SocketPath}"
          ]), env: extend({}, process.env, env))
        done()

module.exports = (args, env, fn) ->
  [chromedriver, chromedriverLogs, chromedriverExit] = []

  runs ->
    chromedriver = spawn(ChromedriverPath, [
      "--verbose",
      "--port=#{ChromedriverPort}",
      "--url-base=/wd/hub"
    ])

    chromedriverLogs = []
    chromedriverExit = new Promise (resolve) ->
      errorCode = null
      chromedriver.on "exit", (code, signal) ->
        errorCode = code unless signal?
      chromedriver.stderr.on "data", (log) ->
        chromedriverLogs.push(log.toString())
      chromedriver.stderr.on "close", ->
        resolve(errorCode)

  waits(100)

  waitsFor("webdriver to finish", (done) ->
    finish = once ->
      client
        .end()
        .then(-> chromedriver.kill())
        .then(chromedriverExit.then(
          (errorCode) ->
            if errorCode?
              jasmine.getEnv().currentSpec.fail """
                Chromedriver exited with code #{errorCode}.
                Logs:\n#{chromedriverLogs.join("\n")}
              """
            done()))

    client = buildAtomClient(args, env)

    client.on "error", (err) ->
      jasmine.getEnv().currentSpec.fail(JSON.stringify(err))
      finish()

    fn(client.init()).then(finish)
  , 30000)
