const _ = require('underscore-plus');
const { Emitter, Disposable, CompositeDisposable } = require('event-kit');
const TextEditor = require('./text-editor');
const ScopeDescriptor = require('./scope-descriptor');

const EDITOR_PARAMS_BY_SETTING_KEY = [
  ['core.fileEncoding', 'encoding'],
  ['core.fileEncodingAutoDetect', 'detectEncoding'],
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
  ['editor.maxScreenLineLength', 'maxScreenLineLength'],
  ['editor.autoIndent', 'autoIndent'],
  ['editor.autoIndentOnPaste', 'autoIndentOnPaste'],
  ['editor.scrollPastEnd', 'scrollPastEnd'],
  ['editor.undoGroupingInterval', 'undoGroupingInterval'],
  ['editor.scrollSensitivity', 'scrollSensitivity']
];

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
module.exports = class TextEditorRegistry {
  constructor({ config, assert, packageManager }) {
    this.config = config;
    this.assert = assert;
    this.packageManager = packageManager;
    this.clear();
  }

  deserialize(state) {
    this.editorGrammarOverrides = state.editorGrammarOverrides;
  }

  serialize() {
    return {
      editorGrammarOverrides: Object.assign({}, this.editorGrammarOverrides)
    };
  }

  clear() {
    if (this.subscriptions) {
      this.subscriptions.dispose();
    }

    this.subscriptions = new CompositeDisposable();
    this.editors = new Set();
    this.emitter = new Emitter();
    this.scopesWithConfigSubscriptions = new Set();
    this.editorsWithMaintainedConfig = new Set();
    this.editorsWithMaintainedGrammar = new Set();
    this.editorGrammarOverrides = {};
    this.editorGrammarScores = new WeakMap();
  }

  destroy() {
    this.subscriptions.dispose();
    this.editorsWithMaintainedConfig = null;
  }

  // Register a `TextEditor`.
  //
  // * `editor` The editor to register.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to remove the
  // added editor. To avoid any memory leaks this should be called when the
  // editor is destroyed.
  add(editor) {
    this.editors.add(editor);
    editor.registered = true;
    this.emitter.emit('did-add-editor', editor);

    return new Disposable(() => this.remove(editor));
  }

  build(params) {
    params = Object.assign({ assert: this.assert }, params);

    let scope = null;
    if (params.buffer) {
      const { grammar } = params.buffer.getLanguageMode();
      if (grammar) {
        scope = new ScopeDescriptor({ scopes: [grammar.scopeName] });
      }
    }

    Object.assign(params, this.textEditorParamsForScope(scope));

    return new TextEditor(params);
  }

  // Remove a `TextEditor`.
  //
  // * `editor` The editor to remove.
  //
  // Returns a {Boolean} indicating whether the editor was successfully removed.
  remove(editor) {
    var removed = this.editors.delete(editor);
    editor.registered = false;
    return removed;
  }

  // Invoke the given callback with all the current and future registered
  // `TextEditors`.
  //
  // * `callback` {Function} to be called with current and future text editors.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observe(callback) {
    this.editors.forEach(callback);
    return this.emitter.on('did-add-editor', callback);
  }

  // Keep a {TextEditor}'s configuration in sync with Atom's settings.
  //
  // * `editor` The editor whose configuration will be maintained.
  //
  // Returns a {Disposable} that can be used to stop updating the editor's
  // configuration.
  maintainConfig(editor) {
    if (this.editorsWithMaintainedConfig.has(editor)) {
      return new Disposable(noop);
    }
    this.editorsWithMaintainedConfig.add(editor);

    this.updateAndMonitorEditorSettings(editor);
    const languageChangeSubscription = editor.buffer.onDidChangeLanguageMode(
      (newLanguageMode, oldLanguageMode) => {
        this.updateAndMonitorEditorSettings(editor, oldLanguageMode);
      }
    );
    this.subscriptions.add(languageChangeSubscription);

    const updateTabTypes = () => {
      const configOptions = { scope: editor.getRootScopeDescriptor() };
      editor.setSoftTabs(
        shouldEditorUseSoftTabs(
          editor,
          this.config.get('editor.tabType', configOptions),
          this.config.get('editor.softTabs', configOptions)
        )
      );
    };

    updateTabTypes();
    const tokenizeSubscription = editor.onDidTokenize(updateTabTypes);
    this.subscriptions.add(tokenizeSubscription);

    return new Disposable(() => {
      this.editorsWithMaintainedConfig.delete(editor);
      tokenizeSubscription.dispose();
      languageChangeSubscription.dispose();
      this.subscriptions.remove(languageChangeSubscription);
      this.subscriptions.remove(tokenizeSubscription);
    });
  }

  // Deprecated: set a {TextEditor}'s grammar based on its path and content,
  // and continue to update its grammar as grammars are added or updated, or
  // the editor's file path changes.
  //
  // * `editor` The editor whose grammar will be maintained.
  //
  // Returns a {Disposable} that can be used to stop updating the editor's
  // grammar.
  maintainGrammar(editor) {
    atom.grammars.maintainLanguageMode(editor.getBuffer());
  }

  // Deprecated: Force a {TextEditor} to use a different grammar than the
  // one that would otherwise be selected for it.
  //
  // * `editor` The editor whose gramamr will be set.
  // * `languageId` The {String} language ID for the desired {Grammar}.
  setGrammarOverride(editor, languageId) {
    atom.grammars.assignLanguageMode(editor.getBuffer(), languageId);
  }

  // Deprecated: Retrieve the grammar scope name that has been set as a
  // grammar override for the given {TextEditor}.
  //
  // * `editor` The editor.
  //
  // Returns a {String} scope name, or `null` if no override has been set
  // for the given editor.
  getGrammarOverride(editor) {
    return atom.grammars.getAssignedLanguageId(editor.getBuffer());
  }

  // Deprecated: Remove any grammar override that has been set for the given {TextEditor}.
  //
  // * `editor` The editor.
  clearGrammarOverride(editor) {
    atom.grammars.autoAssignLanguageMode(editor.getBuffer());
  }

  async updateAndMonitorEditorSettings(editor, oldLanguageMode) {
    await this.packageManager.getActivatePromise();
    this.updateEditorSettingsForLanguageMode(editor, oldLanguageMode);
    this.subscribeToSettingsForEditorScope(editor);
  }

  updateEditorSettingsForLanguageMode(editor, oldLanguageMode) {
    const newLanguageMode = editor.buffer.getLanguageMode();

    if (oldLanguageMode) {
      const newSettings = this.textEditorParamsForScope(
        newLanguageMode.rootScopeDescriptor
      );
      const oldSettings = this.textEditorParamsForScope(
        oldLanguageMode.rootScopeDescriptor
      );

      const updatedSettings = {};
      for (const [, paramName] of EDITOR_PARAMS_BY_SETTING_KEY) {
        // Update the setting only if it has changed between the two language
        // modes.  This prevents user-modified settings in an editor (like
        // 'softWrapped') from being reset when the language mode changes.
        if (!_.isEqual(newSettings[paramName], oldSettings[paramName])) {
          updatedSettings[paramName] = newSettings[paramName];
        }
      }

      if (_.size(updatedSettings) > 0) {
        editor.update(updatedSettings);
      }
    } else {
      editor.update(
        this.textEditorParamsForScope(newLanguageMode.rootScopeDescriptor)
      );
    }
  }

  subscribeToSettingsForEditorScope(editor) {
    if (!this.editorsWithMaintainedConfig) return;

    const scopeDescriptor = editor.getRootScopeDescriptor();
    const scopeChain = scopeDescriptor.getScopeChain();

    if (!this.scopesWithConfigSubscriptions.has(scopeChain)) {
      this.scopesWithConfigSubscriptions.add(scopeChain);
      const configOptions = { scope: scopeDescriptor };

      for (const [settingKey, paramName] of EDITOR_PARAMS_BY_SETTING_KEY) {
        this.subscriptions.add(
          this.config.onDidChange(settingKey, configOptions, ({ newValue }) => {
            this.editorsWithMaintainedConfig.forEach(editor => {
              if (editor.getRootScopeDescriptor().isEqual(scopeDescriptor)) {
                editor.update({ [paramName]: newValue });
              }
            });
          })
        );
      }

      const updateTabTypes = () => {
        const tabType = this.config.get('editor.tabType', configOptions);
        const softTabs = this.config.get('editor.softTabs', configOptions);
        this.editorsWithMaintainedConfig.forEach(editor => {
          if (editor.getRootScopeDescriptor().isEqual(scopeDescriptor)) {
            editor.setSoftTabs(
              shouldEditorUseSoftTabs(editor, tabType, softTabs)
            );
          }
        });
      };

      this.subscriptions.add(
        this.config.onDidChange(
          'editor.tabType',
          configOptions,
          updateTabTypes
        ),
        this.config.onDidChange(
          'editor.softTabs',
          configOptions,
          updateTabTypes
        )
      );
    }
  }

  textEditorParamsForScope(scopeDescriptor) {
    const result = {};
    const configOptions = { scope: scopeDescriptor };
    for (const [settingKey, paramName] of EDITOR_PARAMS_BY_SETTING_KEY) {
      result[paramName] = this.config.get(settingKey, configOptions);
    }
    return result;
  }
};

function shouldEditorUseSoftTabs(editor, tabType, softTabs) {
  switch (tabType) {
    case 'hard':
      return false;
    case 'soft':
      return true;
    case 'auto':
      switch (editor.usesSoftTabs()) {
        case true:
          return true;
        case false:
          return false;
        default:
          return softTabs;
      }
  }
}

function noop() {}
