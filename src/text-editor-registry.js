/** @babel */

import {Emitter, Disposable, CompositeDisposable} from 'event-kit'
import {Point, Range} from 'atom'
import TextEditor from './text-editor'
import ScopeDescriptor from './scope-descriptor'

const EDITOR_PARAMS_BY_SETTING_KEY = [
  ['core.fileEncoding', 'encoding'],
  ['editor.atomicSoftTabs', 'atomicSoftTabs'],
  ['editor.showInvisibles', 'showInvisibles'],
  ['editor.tabLength', 'tabLength'],
  ['editor.invisibles', 'invisibles'],
  ['editor.showCursorOnSelection', 'showCursorOnSelection'],
  ['editor.showIndentGuide', 'showIndentGuide'],
  ['editor.showLineNumbers', 'showLineNumbers'],
  ['editor.softWrap', 'softWrapped'],
  ['editor.softWrapHangingIndent', 'softWrapHangingIndentLength'],
  ['editor.softWrapAtPreferredLineLength', 'softWrapAtPreferredLineLength'],
  ['editor.preferredLineLength', 'preferredLineLength'],
  ['editor.autoIndent', 'autoIndent'],
  ['editor.autoIndentOnPaste', 'autoIndentOnPaste'],
  ['editor.scrollPastEnd', 'scrollPastEnd'],
  ['editor.undoGroupingInterval', 'undoGroupingInterval'],
  ['editor.nonWordCharacters', 'nonWordCharacters'],
  ['editor.scrollSensitivity', 'scrollSensitivity']
]

const GRAMMAR_SELECTION_RANGE = Range(Point.ZERO, Point(10, 0)).freeze()

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
  constructor ({config, grammarRegistry, assert, packageManager}) {
    this.assert = assert
    this.config = config
    this.grammarRegistry = grammarRegistry
    this.scopedSettingsDelegate = new ScopedSettingsDelegate(config)
    this.grammarAddedOrUpdated = this.grammarAddedOrUpdated.bind(this)
    this.clear()

    this.initialPackageActivationPromise = new Promise((resolve) => {
      // TODO: Remove this usage of a private property of PackageManager.
      // Should PackageManager just expose a promise-based API like this?
      if (packageManager.deferredActivationHooks) {
        packageManager.onDidActivateInitialPackages(resolve)
      } else {
        resolve()
      }
    })
  }

  deserialize (state) {
    this.editorGrammarOverrides = state.editorGrammarOverrides
  }

  serialize () {
    return {
      editorGrammarOverrides: Object.assign({}, this.editorGrammarOverrides)
    }
  }

  clear () {
    if (this.subscriptions) {
      this.subscriptions.dispose()
    }

    this.subscriptions = new CompositeDisposable()
    this.editors = new Set()
    this.emitter = new Emitter()
    this.scopesWithConfigSubscriptions = new Set()
    this.editorsWithMaintainedConfig = new Set()
    this.editorsWithMaintainedGrammar = new Set()
    this.editorGrammarOverrides = {}
    this.editorGrammarScores = new WeakMap()
    this.subscriptions.add(
      this.grammarRegistry.onDidAddGrammar(this.grammarAddedOrUpdated),
      this.grammarRegistry.onDidUpdateGrammar(this.grammarAddedOrUpdated)
    )
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
    this.emitter.emit('did-add-editor', editor)

    return new Disposable(() => this.remove(editor))
  }

  build (params) {
    params = Object.assign({assert: this.assert}, params)

    let scope = null
    if (params.buffer) {
      const filePath = params.buffer.getPath()
      const headContent = params.buffer.getTextInRange(GRAMMAR_SELECTION_RANGE)
      params.grammar = this.grammarRegistry.selectGrammar(filePath, headContent)
      scope = new ScopeDescriptor({scopes: [params.grammar.scopeName]})
    }

    Object.assign(params, this.textEditorParamsForScope(scope))

    return new TextEditor(params)
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
    return this.emitter.on('did-add-editor', callback)
  }

  // Keep a {TextEditor}'s configuration in sync with Atom's settings.
  //
  // * `editor` The editor whose configuration will be maintained.
  //
  // Returns a {Disposable} that can be used to stop updating the editor's
  // configuration.
  maintainConfig (editor) {
    if (this.editorsWithMaintainedConfig.has(editor)) {
      return new Disposable(noop)
    }
    this.editorsWithMaintainedConfig.add(editor)

    editor.setScopedSettingsDelegate(this.scopedSettingsDelegate)

    this.subscribeToSettingsForEditorScope(editor)
    const grammarChangeSubscription = editor.onDidChangeGrammar(() => {
      this.subscribeToSettingsForEditorScope(editor)
    })
    this.subscriptions.add(grammarChangeSubscription)

    const updateTabTypes = () => {
      const configOptions = {scope: editor.getRootScopeDescriptor()}
      editor.setSoftTabs(shouldEditorUseSoftTabs(
        editor,
        this.config.get('editor.tabType', configOptions),
        this.config.get('editor.softTabs', configOptions)
      ))
    }

    updateTabTypes()
    const tokenizeSubscription = editor.onDidTokenize(updateTabTypes)
    this.subscriptions.add(tokenizeSubscription)

    return new Disposable(() => {
      this.editorsWithMaintainedConfig.delete(editor)
      editor.setScopedSettingsDelegate(null)
      tokenizeSubscription.dispose()
      grammarChangeSubscription.dispose()
      this.subscriptions.remove(grammarChangeSubscription)
      this.subscriptions.remove(tokenizeSubscription)
    })
  }

  // Set a {TextEditor}'s grammar based on its path and content, and continue
  // to update its grammar as gramamrs are added or updated, or the editor's
  // file path changes.
  //
  // * `editor` The editor whose grammar will be maintained.
  //
  // Returns a {Disposable} that can be used to stop updating the editor's
  // grammar.
  maintainGrammar (editor) {
    if (this.editorsWithMaintainedGrammar.has(editor)) {
      return new Disposable(noop)
    }

    this.editorsWithMaintainedGrammar.add(editor)

    const buffer = editor.getBuffer()
    for (let existingEditor of this.editorsWithMaintainedGrammar) {
      if (existingEditor.getBuffer() === buffer) {
        const existingOverride = this.editorGrammarOverrides[existingEditor.id]
        if (existingOverride) {
          this.editorGrammarOverrides[editor.id] = existingOverride
        }
        break
      }
    }

    this.selectGrammarForEditor(editor)

    const pathChangeSubscription = editor.onDidChangePath(() => {
      this.editorGrammarScores.delete(editor)
      this.selectGrammarForEditor(editor)
    })

    this.subscriptions.add(pathChangeSubscription)

    return new Disposable(() => {
      delete this.editorGrammarOverrides[editor.id]
      this.editorsWithMaintainedGrammar.delete(editor)
      this.subscriptions.remove(pathChangeSubscription)
      pathChangeSubscription.dispose()
    })
  }

  // Force a {TextEditor} to use a different grammar than the one that would
  // otherwise be selected for it.
  //
  // * `editor` The editor whose gramamr will be set.
  // * `scopeName` The {String} root scope name for the desired {Grammar}.
  setGrammarOverride (editor, scopeName) {
    this.editorGrammarOverrides[editor.id] = scopeName
    this.editorGrammarScores.delete(editor)
    editor.setGrammar(this.grammarRegistry.grammarForScopeName(scopeName))
  }

  // Retrieve the grammar scope name that has been set as a grammar override
  // for the given {TextEditor}.
  //
  // * `editor` The editor.
  //
  // Returns a {String} scope name, or `null` if no override has been set
  // for the given editor.
  getGrammarOverride (editor) {
    return this.editorGrammarOverrides[editor.id]
  }

  // Remove any grammar override that has been set for the given {TextEditor}.
  //
  // * `editor` The editor.
  clearGrammarOverride (editor) {
    delete this.editorGrammarOverrides[editor.id]
    this.selectGrammarForEditor(editor)
  }

  // Private

  grammarAddedOrUpdated (grammar) {
    this.editorsWithMaintainedGrammar.forEach((editor) => {
      if (grammar.injectionSelector) {
        if (editor.tokenizedBuffer.hasTokenForSelector(grammar.injectionSelector)) {
          editor.tokenizedBuffer.retokenizeLines()
        }
        return
      }

      const grammarOverride = this.editorGrammarOverrides[editor.id]
      if (grammarOverride) {
        if (grammar.scopeName === grammarOverride) {
          editor.setGrammar(grammar)
        }
      } else {
        const score = this.grammarRegistry.getGrammarScore(
          grammar,
          editor.getPath(),
          editor.getTextInBufferRange(GRAMMAR_SELECTION_RANGE)
        )

        let currentScore = this.editorGrammarScores.get(editor)
        if (currentScore == null || score > currentScore) {
          editor.setGrammar(grammar, score)
          this.editorGrammarScores.set(editor, score)
        }
      }
    })
  }

  selectGrammarForEditor (editor) {
    const grammarOverride = this.editorGrammarOverrides[editor.id]

    if (grammarOverride) {
      const grammar = this.grammarRegistry.grammarForScopeName(grammarOverride)
      editor.setGrammar(grammar)
      return
    }

    const {grammar, score} = this.grammarRegistry.selectGrammarWithScore(
      editor.getPath(),
      editor.getTextInBufferRange(GRAMMAR_SELECTION_RANGE)
    )

    if (!grammar) {
      throw new Error(`No grammar found for path: ${editor.getPath()}`)
    }

    const currentScore = this.editorGrammarScores.get(editor)
    if (currentScore == null || score > currentScore) {
      editor.setGrammar(grammar)
      this.editorGrammarScores.set(editor, score)
    }
  }

  async subscribeToSettingsForEditorScope (editor) {
    await this.initialPackageActivationPromise

    const scopeDescriptor = editor.getRootScopeDescriptor()
    const scopeChain = scopeDescriptor.getScopeChain()

    editor.update(this.textEditorParamsForScope(scopeDescriptor))

    if (!this.scopesWithConfigSubscriptions.has(scopeChain)) {
      this.scopesWithConfigSubscriptions.add(scopeChain)
      const configOptions = {scope: scopeDescriptor}

      for (const [settingKey, paramName] of EDITOR_PARAMS_BY_SETTING_KEY) {
        this.subscriptions.add(
          this.config.onDidChange(settingKey, configOptions, ({newValue}) => {
            this.editorsWithMaintainedConfig.forEach((editor) => {
              if (editor.getRootScopeDescriptor().isEqual(scopeDescriptor)) {
                editor.update({[paramName]: newValue})
              }
            })
          })
        )
      }

      const updateTabTypes = () => {
        const tabType = this.config.get('editor.tabType', configOptions)
        const softTabs = this.config.get('editor.softTabs', configOptions)
        this.editorsWithMaintainedConfig.forEach((editor) => {
          if (editor.getRootScopeDescriptor().isEqual(scopeDescriptor)) {
            editor.setSoftTabs(shouldEditorUseSoftTabs(editor, tabType, softTabs))
          }
        })
      }

      this.subscriptions.add(
        this.config.onDidChange('editor.tabType', configOptions, updateTabTypes),
        this.config.onDidChange('editor.softTabs', configOptions, updateTabTypes)
      )
    }
  }

  textEditorParamsForScope (scopeDescriptor) {
    const result = {}
    const configOptions = {scope: scopeDescriptor}
    for (const [settingKey, paramName] of EDITOR_PARAMS_BY_SETTING_KEY) {
      result[paramName] = this.config.get(settingKey, configOptions)
    }
    return result
  }
}

function shouldEditorUseSoftTabs (editor, tabType, softTabs) {
  switch (tabType) {
    case 'hard':
      return false
    case 'soft':
      return true
    case 'auto':
      switch (editor.usesSoftTabs()) {
        case true:
          return true
        case false:
          return false
        default:
          return softTabs
      }
  }
}

function noop () {}

class ScopedSettingsDelegate {
  constructor (config) {
    this.config = config
  }

  getNonWordCharacters (scope) {
    return this.config.get('editor.nonWordCharacters', {scope: scope})
  }

  getIncreaseIndentPattern (scope) {
    return this.config.get('editor.increaseIndentPattern', {scope: scope})
  }

  getDecreaseIndentPattern (scope) {
    return this.config.get('editor.decreaseIndentPattern', {scope: scope})
  }

  getDecreaseNextIndentPattern (scope) {
    return this.config.get('editor.decreaseNextIndentPattern', {scope: scope})
  }

  getFoldEndPattern (scope) {
    return this.config.get('editor.foldEndPattern', {scope: scope})
  }

  getCommentStrings (scope) {
    const commentStartEntries = this.config.getAll('editor.commentStart', {scope})
    const commentEndEntries = this.config.getAll('editor.commentEnd', {scope})
    const commentStartEntry = commentStartEntries[0]
    const commentEndEntry = commentEndEntries.find((entry) => {
      return entry.scopeSelector === commentStartEntry.scopeSelector
    })
    return {
      commentStartString: commentStartEntry && commentStartEntry.value,
      commentEndString: commentEndEntry && commentEndEntry.value
    }
  }
}
