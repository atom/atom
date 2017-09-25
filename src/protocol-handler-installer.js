const {CompositeDisposable} = require('event-kit')

const {remote} = require('electron')

function isSupported () {
  return ['win32', 'darwin'].includes(process.platform)
}

function isDefaultProtocolClient () {
  return remote.app.isDefaultProtocolClient('atom', process.execPath, ['--url-handler'])
}

function setAsDefaultProtocolClient () {
  // This Electron API is only available on Windows and macOS. There might be some
  // hacks to make it work on Linux; see https://github.com/electron/electron/issues/6440
  return isSupported() && remote.app.setAsDefaultProtocolClient('atom', process.execPath, ['--url-handler'])
}

module.exports =
class ProtocolHandlerInstaller {
  constructor () {
    this.subscriptions = new CompositeDisposable()
  }

  initialize (config, notifications) {
    this.config = config
    this.notifications = notifications

    this.subscriptions.add(this.config.observe('core.uriHandlerRegistration', this.onValueChange.bind(this)))
  }

  onValueChange () {
    if (!isDefaultProtocolClient()) {
      const behaviorWhenNotProtocolClient = this.config.get('core.uriHandlerRegistration')
      switch (behaviorWhenNotProtocolClient) {
        case 'prompt':
          this.promptToBecomeProtocolClient()
          break
        case 'always':
          setAsDefaultProtocolClient()
          break
        case 'never':
        default:
          // Do nothing
      }
    }
  }

  promptToBecomeProtocolClient () {
    let notification

    const accept = () => {
      notification.dismiss()
      setAsDefaultProtocolClient()
    }
    const acceptAlways = () => {
      this.config.set('core.uriHandlerRegistration', 'always')
      return accept()
    }
    const decline = () => {
      notification.dismiss()
    }
    const declineAlways = () => {
      this.config.set('core.uriHandlerRegistration', 'never')
      return decline()
    }

    notification = this.notifications.addInfo('Register as default atom:// URI handler?', {
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
          onDidClick: acceptAlways
        },
        {
          text: 'No',
          className: 'btn btn-info',
          onDidClick: decline
        },
        {
          text: 'No, Never',
          className: 'btn btn-info',
          onDidClick: declineAlways
        }
      ]
    })
  }

  destroy () {
    this.subscriptions.dispose()
  }
}
