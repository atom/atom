/** @babel */

import {Emitter, Disposable, CompositeDisposable} from 'event-kit'
import {Point, Range} from 'atom'
import NullGrammar from './null-grammar'

const EDITOR_SETTER_NAMES_BY_SETTING_KEY = [
  ['core.fileEncoding', 'setEncoding'],
  ['editor.atomicSoftTabs', 'setAtomicSoftTabs'],
  ['editor.showInvisibles', 'setShowInvisibles'],
  ['editor.tabLength', 'setTabLength'],
  ['editor.invisibles', 'setInvisibles'],
  ['editor.showIndentGuide', 'setShowIndentGuide'],
  ['editor.softWrap', 'setSoftWrapped'],
  ['editor.softWrapHangingIndent', 'setSoftWrapIndentLength'],
  ['editor.softWrapAtPreferredLineLength', 'setSoftWrapAtPreferredLineLength'],
  ['editor.preferredLineLength', 'setPreferredLineLength'],
  ['editor.backUpBeforeSaving', 'setBackUpBeforeSaving'],
  ['editor.autoIndent', 'setAutoIndent'],
  ['editor.autoIndentOnPaste', 'setAutoIndentOnPaste'],
  ['editor.scrollPastEnd', 'setScrollPastEnd'],
  ['editor.undoGroupingInterval', 'setUndoGroupingInterval'],
  ['editor.nonWordCharacters', 'setNonWordCharacters'],
  ['editor.scrollSensitivity', 'setScrollSensitivity']
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
  constructor ({config, grammarRegistry}) {
    this.config = config
    this.grammarRegistry = grammarRegistry
    this.scopedSettingsDelegate = new ScopedSettingsDelegate(config)
    this.grammarAddedOrUpdated = this.grammarAddedOrUpdated.bind(this)
    this.clear()
  }

  static deserialize (state, atomEnvironment) {
    const registry = new TextEditorRegistry({
      config: atomEnvironment.config,
      grammarRegistry: atomEnvironment.grammars
    })

    registry.editorGrammarOverrides = state.editorGrammarOverrides

    return registry
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

  maintainGrammar (editor) {
    if (this.editorsWithMaintainedGrammar.has(editor)) {
      return
    }

    this.editorsWithMaintainedGrammar.add(editor)
    if (editor.getGrammar() !== NullGrammar) {
      this.editorGrammarOverrides[editor.id] = editor.getGrammar().scopeName
    }

    this.selectGrammarForEditor(editor)
    this.subscriptions.add(editor.onDidChangePath(() => {
      this.editorGrammarScores.delete(editor)
      this.selectGrammarForEditor(editor)
    }))
  }

  setGrammarOverride (editor, scopeName) {
    this.editorGrammarOverrides[editor.id] = scopeName
    this.editorGrammarScores.delete(editor)
    editor.setGrammar(this.grammarRegistry.grammarForScopeName(scopeName))
  }

  getGrammarOverride (editor) {
    return this.editorGrammarOverrides[editor.id]
  }

  clearGrammarOverride (editor) {
    delete this.editorGrammarOverrides[editor.id]
    this.selectGrammarForEditor(editor)
  }

  maintainConfig (editor) {
    if (this.editorsWithMaintainedConfig.has(editor)) {
      return
    }

    this.editorsWithMaintainedConfig.add(editor)
    this.subscribeToSettingsForEditorScope(editor)
    editor.setScopedSettingsDelegate(this.scopedSettingsDelegate)

    const configOptions = {scope: editor.getRootScopeDescriptor()}
    for (const [settingKey, setterName] of EDITOR_SETTER_NAMES_BY_SETTING_KEY) {
      editor[setterName](this.config.get(settingKey, configOptions))
    }

    const updateTabTypes = () => {
      editor.setSoftTabs(shouldEditorUseSoftTabs(
        editor,
        this.config.get('editor.tabType', configOptions),
        this.config.get('editor.softTabs', configOptions)
      ))
    }

    updateTabTypes()
    this.subscriptions.add(editor.onDidTokenize(updateTabTypes))
  }

  // Private

  grammarAddedOrUpdated (grammar) {
    this.editorsWithMaintainedGrammar.forEach(editor => {
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
          this.subscribeToSettingsForEditorScope(editor)
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
              if (editor.getRootScopeDescriptor().isEqual(scopeDescriptor)) {
                editor[setterName](newValue)
              }
            })
          })
        )
      }

      const updateTabTypes = () => {
        const tabType = this.config.get('editor.tabType', configOptions)
        const softTabs = this.config.get('editor.softTabs', configOptions)

        this.editorsWithMaintainedConfig.forEach(editor => {
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
    const commentEndEntry = commentEndEntries.find(entry => {
      return entry.scopeSelector === commentStartEntry.scopeSelector
    })
    return {
      commentStartString: commentStartEntry && commentStartEntry.value,
      commentEndString: commentEndEntry && commentEndEntry.value
    }
  }
}
