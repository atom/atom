path = require "path"
temp = require("temp").track()
remote = require "remote"
{map, extend} = require "underscore-plus"
{spawn, spawnSync} = require "child_process"
webdriverio = require "../../../build/node_modules/webdriverio"
async = require "async"

AtomPath = remote.process.argv[0]
AtomLauncherPath = path.join(__dirname, "..", "helpers", "atom-launcher.sh")
SocketPath = path.join(temp.mkdirSync("socket-dir"), "atom.sock")
ChromedriverPort = 9515

module.exports =
  driverTest: (fn) ->
    chromedriver = spawn("chromedriver", [
      "--verbose",
      "--port=#{ChromedriverPort}",
      "--url-base=/wd/hub"
    ])

    logs = []
    errorCode = null
    chromedriver.on "exit", (code, signal) ->
      errorCode = code unless signal?
    chromedriver.stderr.on "data", (log) ->
      logs.push(log.toString())
    chromedriver.stderr.on "close", ->
      if errorCode?
        jasmine.getEnv().currentSpec.fail "Chromedriver exited. code: #{errorCode}. Logs: #{logs.join("\n")}"

    waitsFor "webdriver steps to complete", (done) ->
      fn()
        .catch((error) -> jasmine.getEnv().currentSpec.fail(err.message))
        .end()
        .call(done)
    , 30000

    runs -> chromedriver.kill()

  # Start Atom using chromedriver.
  startAtom: (args, env={}) ->
    webdriverio.remote(
      host: 'localhost'
      port: ChromedriverPort
      desiredCapabilities:
        browserName: "atom"
        chromeOptions:
          binary: AtomLauncherPath
          args: [
            "atom-path=#{AtomPath}"
            "dev"
            "safe"
            "user-data-dir=#{temp.mkdirSync('integration-spec-')}"
            "socket-path=#{SocketPath}"
          ]
          .concat(map args, (arg) -> "atom-arg=#{arg}")
          .concat(map env, (value, key) -> "atom-env=#{key}=#{value}"))
      .init()
      .addCommand "waitForCondition", (conditionFn, timeout, cb) ->
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
          ((err) -> cb(err, succeeded))
        )

  # Once one `Atom` window is open, subsequent invocations of `Atom` will exit
  # immediately.
  startAnotherAtom: (args, env={}) ->
    spawnSync(AtomPath, args.concat([
      "--dev"
      "--safe"
      "--socket-path=#{SocketPath}"
    ]), env: extend({}, process.env, env))
