const {CompositeDisposable} = require('event-kit')

const {remote} = require('electron')

module.exports =
class ProtocolHandlerInstaller {
  constructor () {
    this.subscriptions = new CompositeDisposable()
    this.supported = ['win32', 'darwin'].includes(process.platform)
  }

  initialize (config) {
    this.config = config

    this.subscriptions.add(
      this.config.observe('core.defaultProtocolHandler', this.onValueChange.bind(this))
    )
  }

  onValueChange (shouldBeProtocolHandler) {
    this.isProtocolHandler = remote.app.isDefaultProtocolClient('atom', process.execPath, ['--url-handler'])
    if (!this.isProtocolHandler && shouldBeProtocolHandler) {
      this.installProtocolHandler()
    } else if (this.isProtocolHandler && !shouldBeProtocolHandler) {
      this.uninstallProtocolHandler()
    }
  }

  installProtocolHandler () {
    // This Electron API is only available on Windows and macOS. There might be some
    // hacks to make it work on Linux; see https://github.com/electron/electron/issues/6440
    if (this.supported) {
      return remote.app.setAsDefaultProtocolClient('atom', process.execPath, ['--url-handler'])
    }
  }

  uninstallProtocolHandler () {
    // On macOS, this sets the first supported application that is not Atom
    // as the new default protocol client; if there are none, it seems we remain
    // the default client. See https://github.com/electron/electron/pull/5440
    if (this.supported) {
      return remote.app.removeAsDefaultProtocolClient('atom', process.execPath, ['--url-handler'])
    }
  }

  destroy () {
    this.subscriptions.dispose()
  }
}
