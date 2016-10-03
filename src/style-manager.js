const fs = require('fs-plus')
const path = require('path')
const {Emitter, Disposable} = require('event-kit')
const StylesElement = require('./styles-element')

// Extended: A singleton instance of this class available via `atom.styles`,
// which you can use to globally query and observe the set of active style
// sheets. The `StyleManager` doesn't add any style elements to the DOM on its
// own, but is instead subscribed to by individual `<atom-styles>` elements,
// which clone and attach style elements in different contexts.
module.exports = class StyleManager {
  constructor ({configDirPath}) {
    this.configDirPath = configDirPath
    this.emitter = new Emitter()
    this.styleElements = []
    this.styleElementsBySourcePath = {}
  }

  /*
  Section: Event Subscription
  */

  // Extended: Invoke `callback` for all current and future style elements.
  //
  // * `callback` {Function} that is called with style elements.
  //   * `styleElement` An `HTMLStyleElement` instance. The `.sheet` property
  //     will be null because this element isn't attached to the DOM. If you want
  //     to attach this element to the DOM, be sure to clone it first by calling
  //     `.cloneNode(true)` on it. The style element will also have the following
  //     non-standard properties:
  //     * `sourcePath` A {String} containing the path from which the style
  //       element was loaded.
  //     * `context` A {String} indicating the target context of the style
  //       element.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to cancel the
  // subscription.
  observeStyleElements (callback) {
    for (let styleElement of this.getStyleElements()) {
      callback(styleElement)
    }

    return this.onDidAddStyleElement(callback)
  }

  // Extended: Invoke `callback` when a style element is added.
  //
  // * `callback` {Function} that is called with style elements.
  //   * `styleElement` An `HTMLStyleElement` instance. The `.sheet` property
  //     will be null because this element isn't attached to the DOM. If you want
  //     to attach this element to the DOM, be sure to clone it first by calling
  //     `.cloneNode(true)` on it. The style element will also have the following
  //     non-standard properties:
  //     * `sourcePath` A {String} containing the path from which the style
  //       element was loaded.
  //     * `context` A {String} indicating the target context of the style
  //       element.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to cancel the
  // subscription.
  onDidAddStyleElement (callback) {
    return this.emitter.on('did-add-style-element', callback)
  }

  // Extended: Invoke `callback` when a style element is removed.
  //
  // * `callback` {Function} that is called with style elements.
  //   * `styleElement` An `HTMLStyleElement` instance.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to cancel the
  // subscription.
  onDidRemoveStyleElement (callback) {
    return this.emitter.on('did-remove-style-element', callback)
  }

  // Extended: Invoke `callback` when an existing style element is updated.
  //
  // * `callback` {Function} that is called with style elements.
  //   * `styleElement` An `HTMLStyleElement` instance. The `.sheet` property
  //      will be null because this element isn't attached to the DOM. The style
  //      element will also have the following non-standard properties:
  //     * `sourcePath` A {String} containing the path from which the style
  //       element was loaded.
  //     * `context` A {String} indicating the target context of the style
  //       element.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to cancel the
  // subscription.
  onDidUpdateStyleElement (callback) {
    return this.emitter.on('did-update-style-element', callback)
  }

  /*
  Section: Reading Style Elements
  */

  // Extended: Get all loaded style elements.
  getStyleElements () {
    return this.styleElements.slice()
  }

  addStyleSheet (source, params = {}) {
    let styleElement
    let updated
    if (params.sourcePath != null && this.styleElementsBySourcePath[params.sourcePath] != null) {
      updated = true
      styleElement = this.styleElementsBySourcePath[params.sourcePath]
    } else {
      updated = false
      styleElement = document.createElement('style')
      if (params.sourcePath != null) {
        styleElement.sourcePath = params.sourcePath
        styleElement.setAttribute('source-path', params.sourcePath)
      }
      if (params.context != null) {
        styleElement.context = params.context
        styleElement.setAttribute('context', params.context)
      }
      if (params.priority != null) {
        styleElement.priority = params.priority
        styleElement.setAttribute('priority', params.priority)
      }
    }

    styleElement.textContent = source
    if (updated) {
      this.emitter.emit('did-update-style-element', styleElement)
    } else {
      this.addStyleElement(styleElement)
    }
    return new Disposable(() => { this.removeStyleElement(styleElement) })
  }

  addStyleElement (styleElement) {
    let insertIndex = this.styleElements.length
    if (styleElement.priority != null) {
      for (let [index, existingElement] of this.styleElements.entries()) {
        if (existingElement.priority > styleElement.priority) {
          insertIndex = index
          break
        }
      }
    }

    this.styleElements.splice(insertIndex, 0, styleElement)
    if (styleElement.sourcePath != null && this.styleElementsBySourcePath[styleElement.sourcePath] == null) {
      this.styleElementsBySourcePath[styleElement.sourcePath] = styleElement
    }
    this.emitter.emit('did-add-style-element', styleElement)
  }

  removeStyleElement (styleElement) {
    const index = this.styleElements.indexOf(styleElement)
    if (index !== -1) {
      this.styleElements.splice(index, 1)
      if (styleElement.sourcePath != null) {
        delete this.styleElementsBySourcePath[styleElement.sourcePath]
      }
      this.emitter.emit('did-remove-style-element', styleElement)
    }
  }

  getSnapshot () {
    return this.styleElements.slice()
  }

  restoreSnapshot (styleElementsToRestore) {
    for (let styleElement of this.getStyleElements()) {
      if (!styleElementsToRestore.includes(styleElement)) {
        this.removeStyleElement(styleElement)
      }
    }

    const existingStyleElements = this.getStyleElements()
    for (let styleElement of styleElementsToRestore) {
      if (!existingStyleElements.includes(styleElement)) {
        this.addStyleElement(styleElement)
      }
    }
  }

  buildStylesElement () {
    var stylesElement = new StylesElement()
    stylesElement.initialize(this)
    return stylesElement
  }

  /*
  Section: Paths
  */

  // Extended: Get the path of the user style sheet in `~/.atom`.
  //
  // Returns a {String}.
  getUserStyleSheetPath () {
    if (this.configDirPath == null) {
      return ''
    } else {
      const stylesheetPath = fs.resolve(path.join(this.configDirPath, 'styles'), ['css', 'less'])
      if (fs.isFileSync(stylesheetPath)) {
        return stylesheetPath
      } else {
        return path.join(this.configDirPath, 'styles.less')
      }
    }
  }
}
