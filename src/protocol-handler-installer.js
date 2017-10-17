const {remote} = require('electron')

const SETTING = 'core.uriHandlerRegistration'
const PROMPT = 'prompt'
const ALWAYS = 'always'
const NEVER = 'never'

module.exports =
class ProtocolHandlerInstaller {
  isSupported () {
    return ['win32', 'darwin'].includes(process.platform)
  }

  isDefaultProtocolClient () {
    return remote.app.isDefaultProtocolClient('atom', process.execPath, ['--uri-handler'])
  }

  setAsDefaultProtocolClient () {
    // This Electron API is only available on Windows and macOS. There might be some
    // hacks to make it work on Linux; see https://github.com/electron/electron/issues/6440
    return this.isSupported() && remote.app.setAsDefaultProtocolClient('atom', process.execPath, ['--uri-handler'])
  }

  initialize (config, notifications) {
    if (!this.isSupported()) {
      return
    }

    if (!this.isDefaultProtocolClient()) {
      const behaviorWhenNotProtocolClient = config.get(SETTING)
      switch (behaviorWhenNotProtocolClient) {
        case PROMPT:
          this.promptToBecomeProtocolClient(config, notifications)
          break
        case ALWAYS:
          this.setAsDefaultProtocolClient()
          break
        case NEVER:
        default:
          // Do nothing
      }
    }
  }

  promptToBecomeProtocolClient (config, notifications) {
    let notification

    const withSetting = (value, fn) => {
      return function () {
        config.set(SETTING, value)
        fn()
      }
    }

    const accept = () => {
      notification.dismiss()
      this.setAsDefaultProtocolClient()
    }
    const decline = () => {
      notification.dismiss()
    }

    notification = notifications.addInfo('Register as default atom:// URI handler?', {
      dismissable: true,
      icon: 'link',
      description: 'Atom is not currently set as the defaut handler for atom:// URIs. Would you like Atom to handle ' +
        'atom:// URIs?',
      buttons: [
        {
          text: 'Yes',
          className: 'btn btn-info btn-primary',
          onDidClick: accept
        },
        {
          text: 'Yes, Always',
          className: 'btn btn-info',
          onDidClick: withSetting(ALWAYS, accept)
        },
        {
          text: 'No',
          className: 'btn btn-info',
          onDidClick: decline
        },
        {
          text: 'No, Never',
          className: 'btn btn-info',
          onDidClick: withSetting(NEVER, decline)
        }
      ]
    })
  }
}
