const DefaultFileIcons = require('./default-file-icons')
const {Emitter, Disposable, CompositeDisposable} = require('atom')

let iconServices
module.exports = function () {
  if (!iconServices) iconServices = new IconServices()
  return iconServices
}

class IconServices {
  constructor () {
    this.emitter = new Emitter()
    this.elementIcons = null
    this.elementIconDisposables = new CompositeDisposable()
    this.fileIcons = DefaultFileIcons
  }

  onDidChange (callback) {
    return this.emitter.on('did-change', callback)
  }

  resetElementIcons () {
    this.setElementIcons(null)
  }

  resetFileIcons () {
    this.setFileIcons(DefaultFileIcons)
  }

  setElementIcons (service) {
    if (service !== this.elementIcons) {
      if (this.elementIconDisposables != null) {
        this.elementIconDisposables.dispose()
      }
      if (service) { this.elementIconDisposables = new CompositeDisposable() }
      this.elementIcons = service
      return this.emitter.emit('did-change')
    }
  }

  setFileIcons (service) {
    if (service !== this.fileIcons) {
      this.fileIcons = service
      return this.emitter.emit('did-change')
    }
  }

  updateIcon (view, filePath) {
    if (this.elementIcons) {
      if (view.refs && view.refs.icon instanceof Element) {
        if (view.iconDisposable) {
          view.iconDisposable.dispose()
          this.elementIconDisposables.remove(view.iconDisposable)
        }
        view.iconDisposable = this.elementIcons(view.refs.icon, filePath)
        this.elementIconDisposables.add(view.iconDisposable)
      }
    } else {
      let iconClass = this.fileIcons.iconClassForPath(filePath, 'find-and-replace') || ''
      if (Array.isArray(iconClass)) {
        iconClass = iconClass.join(' ')
      }
      view.refs.icon.className = iconClass + ' icon'
    }
  }
}
