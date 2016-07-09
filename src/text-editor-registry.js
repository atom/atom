/** @babel */

import {Emitter, Disposable, CompositeDisposable} from "event-kit"

const EDITOR_SETTER_NAMES_BY_SETTING_KEY = [
  ['core.fileEncoding', 'setEncoding'],
  ['editor.atomicSoftTabs', 'setAtomicSoftTabs'],
  ['editor.showInvisibles', 'setShowInvisibles'],
  ['editor.tabLength', 'setTabLength'],
  ['editor.invisibles', 'setInvisibles'],
  ['editor.showIndentGuide', 'setShowIndentGuide'],
  ['editor.softWrap', 'setSoftWrapped'],
]

// Experimental: This global registry tracks registered `TextEditors`.
//
// If you want to add functionality to a wider set of text editors than just
// those appearing within workspace panes, use `atom.textEditors.observe` to
// invoke a callback for all current and future registered text editors.
//
// If you want packages to be able to add functionality to your non-pane text
// editors (such as a search field in a custom user interface element), register
// them for observation via `atom.textEditors.add`. **Important:** When you're
// done using your editor, be sure to call `dispose` on the returned disposable
// to avoid leaking editors.
export default class TextEditorRegistry {
  constructor ({config}) {
    this.config = config
    this.subscriptions = new CompositeDisposable()
    this.editors = new Set()
    this.emitter = new Emitter()
    this.scopesWithConfigSubscriptions = new Set()
    this.editorsWithMaintainedConfig = new Set()
  }

  destroy () {
    this.subscriptions.dispose()
    this.editorsWithMaintainedConfig = null
  }

  // Register a `TextEditor`.
  //
  // * `editor` The editor to register.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to remove the
  // added editor. To avoid any memory leaks this should be called when the
  // editor is destroyed.
  add (editor) {
    this.editors.add(editor)
    editor.registered = true
    this.emitter.emit("did-add-editor", editor)

    return new Disposable(() => this.remove(editor))
  }

  // Remove a `TextEditor`.
  //
  // * `editor` The editor to remove.
  //
  // Returns a {Boolean} indicating whether the editor was successfully removed.
  remove (editor) {
    var removed = this.editors.delete(editor)
    editor.registered = false
    return removed
  }

  // Invoke the given callback with all the current and future registered
  // `TextEditors`.
  //
  // * `callback` {Function} to be called with current and future text editors.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observe (callback) {
    this.editors.forEach(callback)
    return this.emitter.on("did-add-editor", callback)
  }

  maintainGrammar (editor) {

  }

  maintainConfig (editor) {
    this.editorsWithMaintainedConfig.add(editor)
    this.subscribeToSettingsForEditorScope(editor)

    const configOptions = {scope: editor.getRootScopeDescriptor()}
    for (const [settingKey, setterName] of EDITOR_SETTER_NAMES_BY_SETTING_KEY) {
      editor[setterName](atom.config.get(settingKey, configOptions))
    }
  }

  subscribeToSettingsForEditorScope (editor) {
    const scopeDescriptor = editor.getRootScopeDescriptor()
    const scopeChain = scopeDescriptor.getScopeChain()

    if (!this.scopesWithConfigSubscriptions.has(scopeChain)) {
      this.scopesWithConfigSubscriptions.add(scopeChain)

      const configOptions = {scope: scopeDescriptor}
      for (const [settingKey, setterName] of EDITOR_SETTER_NAMES_BY_SETTING_KEY) {
        this.subscriptions.add(
          this.config.onDidChange(settingKey, configOptions, ({newValue}) => {
            this.editorsWithMaintainedConfig.forEach(editor => {
              if (editor.getRootScopeDescriptor().getScopeChain() === scopeChain) {
                editor[setterName](newValue)
              }
            })
          })
        )
      }
    }
  }
}
