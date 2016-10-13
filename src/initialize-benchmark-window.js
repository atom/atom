/** @babel */

import {ipcRenderer, remote} from 'electron'
import path from 'path'
import ipcHelpers from './ipc-helpers'

export default function () {
  const {getWindowLoadSettings} = require('./window-load-settings-helpers')
  const {headless, resourcePath, benchmarkPaths} = getWindowLoadSettings()
  try {
    const Clipboard = require('../src/clipboard')
    const ApplicationDelegate = require('../src/application-delegate')
    const AtomEnvironment = require('../src/atom-environment')
    const TextEditor = require('../src/text-editor')

    const exportsPath = path.join(resourcePath, 'exports')
    require('module').globalPaths.push(exportsPath) // Add 'exports' to module search path.
    process.env.NODE_PATH = exportsPath // Set NODE_PATH env variable since tasks may need it.

    document.title = 'Benchmarks'
    window.addEventListener('keydown', (event) => {
      // Quit: cmd-q / ctrl-q
      if ((event.metaKey || event.ctrlKey) && event.keyCode === 81) {
        ipcRenderer.send('command', 'application:quit')
      }

      // Reload: cmd-r / ctrl-r
      if ((event.metaKey || event.ctrlKey) && event.keyCode === 82) {
        ipcHelpers.call('window-method', 'reload')
      }

      // Toggle Dev Tools: cmd-alt-i (Mac) / ctrl-shift-i (Linux/Windows)
      if (event.keyCode === 73) {
        const isDarwin = process.platform === 'darwin'
        if ((isDarwin && event.metaKey && event.altKey) || (!isDarwin && event.ctrlKey && event.shiftKey)) {
          ipcHelpers.call('window-method', 'toggleDevTools')
        }
      }

      // Close: cmd-w / ctrl-w
      if ((event.metaKey || event.ctrlKey) && event.keyCode === 87) {
        ipcHelpers.call('window-method', 'close')
      }

      // Copy: cmd-c / ctrl-c
      if ((event.metaKey || event.ctrlKey) && event.keyCode === 67) {
        ipcHelpers.call('window-method', 'copy')
      }
    }, true)

    const clipboard = new Clipboard()
    TextEditor.setClipboard(clipboard)

    const applicationDelegate = new ApplicationDelegate()
    global.atom = new AtomEnvironment({
      applicationDelegate, window, document, clipboard,
      configDirPath: process.env.ATOM_HOME, enablePersistence: false
    })

    // Prevent benchmarks from modifying application menus
    global.atom.menu.sendToBrowserProcess = function () { }

    if (!headless) {
      remote.getCurrentWindow().show()
    }

    const benchmarkRunner = require('../benchmarks/benchmark-runner')
    return benchmarkRunner(benchmarkPaths).then((code) => {
      if (headless) {
        exitWithStatusCode(code)
      }
    })
  } catch (e) {
    if (headless) {
      console.error(error.stack || error)
      exitWithStatusCode(1)
    } else {
      throw e
    }
  }
}

function exitWithStatusCode (code) {
  remote.app.emit('will-quit')
  remote.process.exit(status)
}
