const path = require('path')
const http = require('http')
const temp = require('temp').track()
// const os = require('os')
const remote = require('remote')
// const async = require('async')
const {map, once} = require('underscore-plus')
const {spawn} = require('child_process')
const webdriverio = require('../../../script/node_modules/webdriverio')

const AtomPath = remote.process.argv[0]
const AtomLauncherPath = path.join(__dirname, '..', 'helpers', 'atom-launcher.sh')
const ChromedriverPath = path.resolve(__dirname, '..', '..', '..', 'script', 'node_modules', 'electron-chromedriver', 'bin', 'chromedriver')
const ChromedriverPort = 9515
const ChromedriverURLBase = '/wd/hub'
const ChromedriverStatusURL = `http://localhost:${ChromedriverPort}${ChromedriverURLBase}/status`

let userDataDir = null

const chromeDriverUp = done => {
  const checkStatus = () =>
    http.get(ChromedriverStatusURL, function(response) {
      if (response.statusCode === 200) {
        done()
      } else {
        chromeDriverUp(done)
      }
    }).on('error', () => chromeDriverUp(done))

  setTimeout(checkStatus, 100)
}

const chromeDriverDown = done => {
  const checkStatus = () =>
    http.get(ChromedriverStatusURL, response => chromeDriverDown(done)).on('error', done)

  setTimeout(checkStatus, 100)
}

const buildAtomClient = async (args, env) => {
  userDataDir = temp.mkdirSync('atom-user-data-dir')
  let client
  try {
    client = await webdriverio.remote({
      host: 'localhost',
      port: ChromedriverPort,
      capabilities: {
        browserName: 'atom',
        chromeOptions: {
          binary: AtomLauncherPath,
          args: [
            `atom-path=${AtomPath}`,
            `atom-args=${args.join(' ')}`,
            `atom-env=${map(env, (value, key) => `${key}=${value}`).join(' ')}`,
            'dev',
            'safe',
            `user-data-dir=${userDataDir}`
          ]
        }
      }
    })
  } catch (error) {
    console.log(error)
  }

  client.addCommand('waitForPaneItemCount', async function (count, timeout) {
    await this.waitUntil(() => this.execute(() => atom.workspace.getActivePane().getItems().length), timeout)
  })
  client.addCommand('treeViewRootDirectories', async function () {
    const treeViewElement = await this.$('.tree-view')
    await treeViewElement.waitForExist(10000)
    return this.execute(() =>
      Array.from(document.querySelectorAll('.tree-view .project-root > .header .name'))
        .map(element => element.dataset.path)
    )
  })
  client.addCommand('dispatchCommand', async function (command) {
    return this.execute(async (command) => await atom.commands.dispatch(document.activeElement, command), command)
  })

  return client
}

module.exports = function(args, env, fn) {
  let [chromedriver, chromedriverLogs, chromedriverExit] = []

  runs(() => {
    chromedriver = spawn(ChromedriverPath, [
      '--verbose',
      `--port=${ChromedriverPort}`,
      `--url-base=${ChromedriverURLBase}`
    ])

    chromedriverLogs = []
    chromedriverExit = new Promise(resolve => {
      let errorCode = null
      chromedriver.on('exit', (code, signal) => {
        if (signal == null) {
          errorCode = code
        }
      })
      chromedriver.stdout.on('data', log => console.log(log.toString()))
      chromedriver.stderr.on('data', log => console.log(log.toString()))
      // chromedriver.stderr.on('data', log => chromedriverLogs.push(log.toString()))
      chromedriver.stderr.on('close', () => resolve(errorCode))
    })
  })

  waitsFor('webdriver to start', chromeDriverUp, 15000)

  waitsFor('tests to run', async done => {
    const client = await buildAtomClient(args, env)

    const finish = once(async () => {
      chromedriver.kill()

      console.log('>>> Waiting for exit code')
      const errorCode = await chromedriverExit
      if (errorCode != null) {
        jasmine.getEnv().currentSpec.fail(`\
Chromedriver exited with code ${errorCode}.
Logs:\n${chromedriverLogs.join('\n')}\
`
        )
      }
      done()
    })

    // client.on('error', err => {
    //   jasmine.getEnv().currentSpec.fail(new Error(__guard__(__guard__(err.response != null ? err.response.body : undefined, x1 => x1.value), x => x.message)))
    //   finish()
    // })

    console.log('>>> Waiting for window to exist')
    try {
      await client.waitUntil(async function () {
        const handles = await this.getWindowHandles()
        return handles.length > 0
      }, 10000)
    } catch (error) {
      console.log(error)
    }

    console.log('>>> Waiting for workspace to exist')
    try {
      const workspaceElement = await client.$('atom-workspace')
      await workspaceElement.waitForExist(10000)
    } catch (error) {
      console.log(error)
    }

    console.log('>>> Waiting for test to run')
    try {
      await fn(client)
    } catch (error) {
      console.log('!!!!!!!!!')
      console.log(error)
    }
    finish()
  }
  , 30000)

  waitsFor('webdriver to stop', chromeDriverDown, 15000)
}

// function __guard__(value, transform) {
//   return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined
// }
