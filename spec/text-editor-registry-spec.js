const TextEditorRegistry = require('../src/text-editor-registry');
const TextEditor = require('../src/text-editor');
const TextBuffer = require('text-buffer');
const { Point, Range } = TextBuffer;
const dedent = require('dedent');
const NullGrammar = require('../src/null-grammar');

describe('TextEditorRegistry', function() {
  let registry, editor, initialPackageActivation;

  beforeEach(function() {
    initialPackageActivation = Promise.resolve();

    registry = new TextEditorRegistry({
      assert: atom.assert,
      config: atom.config,
      grammarRegistry: atom.grammars,
      packageManager: {
        getActivatePromise() {
          return initialPackageActivation;
        }
      }
    });

    editor = new TextEditor({ autoHeight: false });
    expect(
      atom.grammars.assignLanguageMode(editor, 'text.plain.null-grammar')
    ).toBe(true);
  });

  afterEach(function() {
    registry.destroy();
  });

  describe('.add', function() {
    it('adds an editor to the list of registered editors', function() {
      registry.add(editor);
      expect(editor.registered).toBe(true);
      expect(registry.editors.size).toBe(1);
      expect(registry.editors.has(editor)).toBe(true);
    });

    it('returns a Disposable that can unregister the editor', function() {
      const disposable = registry.add(editor);
      expect(registry.editors.size).toBe(1);
      disposable.dispose();
      expect(registry.editors.size).toBe(0);
      expect(editor.registered).toBe(false);
      expect(retainedEditorCount(registry)).toBe(0);
    });
  });

  describe('.observe', function() {
    it('calls the callback for current and future editors until unsubscribed', function() {
      const spy = jasmine.createSpy();
      const [editor1, editor2, editor3] = [{}, {}, {}];
      registry.add(editor1);
      const subscription = registry.observe(spy);
      expect(spy.calls.length).toBe(1);

      registry.add(editor2);
      expect(spy.calls.length).toBe(2);
      expect(spy.argsForCall[0][0]).toBe(editor1);
      expect(spy.argsForCall[1][0]).toBe(editor2);
      subscription.dispose();

      registry.add(editor3);
      expect(spy.calls.length).toBe(2);
    });
  });

  describe('.build', function() {
    it('constructs a TextEditor with the right parameters based on its path and text', function() {
      atom.config.set('editor.tabLength', 8, { scope: '.source.js' });

      const languageMode = {
        grammar: NullGrammar,
        onDidChangeHighlighting: jasmine.createSpy()
      };

      const buffer = new TextBuffer({ filePath: 'test.js' });
      buffer.setLanguageMode(languageMode);

      const editor = registry.build({
        buffer
      });

      expect(editor.getTabLength()).toBe(8);
      expect(editor.getGrammar()).toEqual(NullGrammar);
      expect(languageMode.onDidChangeHighlighting.calls.length).toBe(1);
    });
  });

  describe('.getActiveTextEditor', function() {
    it('gets the currently focused text editor', function() {
      const disposable = registry.add(editor);
      var editorElement = editor.getElement();
      jasmine.attachToDOM(editorElement);
      editorElement.focus();
      expect(registry.getActiveTextEditor()).toBe(editor);
      disposable.dispose();
    });
  });

  describe('.maintainConfig(editor)', function() {
    it('does not update the editor when config settings change for unrelated scope selectors', async function() {
      await atom.packages.activatePackage('language-javascript');

      const editor2 = new TextEditor();

      atom.grammars.assignLanguageMode(editor2, 'source.js');

      registry.maintainConfig(editor);
      registry.maintainConfig(editor2);
      await initialPackageActivation;

      expect(editor.getRootScopeDescriptor().getScopesArray()).toEqual([
        'text.plain.null-grammar'
      ]);
      expect(editor2.getRootScopeDescriptor().getScopesArray()).toEqual([
        'source.js'
      ]);

      expect(editor.getEncoding()).toBe('utf8');
      expect(editor2.getEncoding()).toBe('utf8');

      atom.config.set('core.fileEncoding', 'utf16le', {
        scopeSelector: '.text.plain.null-grammar'
      });
      atom.config.set('core.fileEncoding', 'utf16be', {
        scopeSelector: '.source.js'
      });

      expect(editor.getEncoding()).toBe('utf16le');
      expect(editor2.getEncoding()).toBe('utf16be');
    });

    it('does not update the editor before the initial packages have loaded', async function() {
      let resolveActivatePromise;
      initialPackageActivation = new Promise(resolve => {
        resolveActivatePromise = resolve;
      });

      atom.config.set('core.fileEncoding', 'utf16le');

      registry.maintainConfig(editor);
      await Promise.resolve();
      expect(editor.getEncoding()).toBe('utf8');

      atom.config.set('core.fileEncoding', 'utf16be');
      await Promise.resolve();
      expect(editor.getEncoding()).toBe('utf8');

      resolveActivatePromise();
      await initialPackageActivation;
      expect(editor.getEncoding()).toBe('utf16be');
    });

    it("updates the editor's settings when its grammar changes", async function() {
      await atom.packages.activatePackage('language-javascript');

      registry.maintainConfig(editor);
      await initialPackageActivation;

      atom.config.set('core.fileEncoding', 'utf16be', {
        scopeSelector: '.source.js'
      });
      expect(editor.getEncoding()).toBe('utf8');

      atom.config.set('core.fileEncoding', 'utf16le', {
        scopeSelector: '.source.js'
      });
      expect(editor.getEncoding()).toBe('utf8');

      atom.grammars.assignLanguageMode(editor, 'source.js');
      await initialPackageActivation;
      expect(editor.getEncoding()).toBe('utf16le');

      atom.config.set('core.fileEncoding', 'utf16be', {
        scopeSelector: '.source.js'
      });
      expect(editor.getEncoding()).toBe('utf16be');

      atom.grammars.assignLanguageMode(editor, 'text.plain.null-grammar');
      await initialPackageActivation;
      expect(editor.getEncoding()).toBe('utf8');
    });

    it("preserves editor settings that haven't changed between previous and current language modes", async function() {
      await atom.packages.activatePackage('language-javascript');

      registry.maintainConfig(editor);
      await initialPackageActivation;

      expect(editor.getEncoding()).toBe('utf8');
      editor.setEncoding('utf16le');
      expect(editor.getEncoding()).toBe('utf16le');

      expect(editor.isSoftWrapped()).toBe(false);
      editor.setSoftWrapped(true);
      expect(editor.isSoftWrapped()).toBe(true);

      atom.grammars.assignLanguageMode(editor, 'source.js');
      await initialPackageActivation;
      expect(editor.getEncoding()).toBe('utf16le');
      expect(editor.isSoftWrapped()).toBe(true);
    });

    it('updates editor settings that have changed between previous and current language modes', async function() {
      await atom.packages.activatePackage('language-javascript');

      registry.maintainConfig(editor);
      await initialPackageActivation;

      expect(editor.getEncoding()).toBe('utf8');
      atom.config.set('core.fileEncoding', 'utf16be', {
        scopeSelector: '.text.plain.null-grammar'
      });
      atom.config.set('core.fileEncoding', 'utf16le', {
        scopeSelector: '.source.js'
      });
      expect(editor.getEncoding()).toBe('utf16be');

      editor.setEncoding('utf8');
      expect(editor.getEncoding()).toBe('utf8');

      atom.grammars.assignLanguageMode(editor, 'source.js');
      await initialPackageActivation;
      expect(editor.getEncoding()).toBe('utf16le');
    });

    it("returns a disposable that can be used to stop the registry from updating the editor's config", async function() {
      await atom.packages.activatePackage('language-javascript');

      const previousSubscriptionCount = getSubscriptionCount(editor);
      const disposable = registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(getSubscriptionCount(editor)).toBeGreaterThan(
        previousSubscriptionCount
      );
      expect(registry.editorsWithMaintainedConfig.size).toBe(1);

      atom.config.set('core.fileEncoding', 'utf16be');
      expect(editor.getEncoding()).toBe('utf16be');
      atom.config.set('core.fileEncoding', 'utf8');
      expect(editor.getEncoding()).toBe('utf8');

      disposable.dispose();

      atom.config.set('core.fileEncoding', 'utf16be');
      expect(editor.getEncoding()).toBe('utf8');
      expect(getSubscriptionCount(editor)).toBe(previousSubscriptionCount);
      expect(retainedEditorCount(registry)).toBe(0);
    });

    it('sets the encoding based on the config', async function() {
      editor.update({ encoding: 'utf8' });
      expect(editor.getEncoding()).toBe('utf8');

      atom.config.set('core.fileEncoding', 'utf16le');
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getEncoding()).toBe('utf16le');

      atom.config.set('core.fileEncoding', 'utf8');
      expect(editor.getEncoding()).toBe('utf8');
    });

    it('sets the tab length based on the config', async function() {
      editor.update({ tabLength: 4 });
      expect(editor.getTabLength()).toBe(4);

      atom.config.set('editor.tabLength', 8);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getTabLength()).toBe(8);

      atom.config.set('editor.tabLength', 4);
      expect(editor.getTabLength()).toBe(4);
    });

    it('enables soft tabs when the tabType config setting is "soft"', async function() {
      atom.config.set('editor.tabType', 'soft');
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getSoftTabs()).toBe(true);
    });

    it('disables soft tabs when the tabType config setting is "hard"', async function() {
      atom.config.set('editor.tabType', 'hard');
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getSoftTabs()).toBe(false);
    });

    describe('when the "tabType" config setting is "auto"', function() {
      it("enables or disables soft tabs based on the editor's content", async function() {
        await initialPackageActivation;
        await atom.packages.activatePackage('language-javascript');
        atom.grammars.assignLanguageMode(editor, 'source.js');
        atom.config.set('editor.tabType', 'auto');
        await initialPackageActivation;

        editor.setText(dedent`
          {
            hello;
          }
        `);
        let disposable = registry.maintainConfig(editor);
        expect(editor.getSoftTabs()).toBe(true);

        /* eslint-disable no-tabs */
        editor.setText(dedent`
          {
          	hello;
          }
        `);
        /* eslint-enable no-tabs */
        disposable.dispose();
        disposable = registry.maintainConfig(editor);
        expect(editor.getSoftTabs()).toBe(false);

        editor.setTextInBufferRange(
          new Range(Point.ZERO, Point.ZERO),
          dedent`
          /*
           * Comment with a leading space.
           */
        ` + '\n'
        );
        disposable.dispose();
        disposable = registry.maintainConfig(editor);
        expect(editor.getSoftTabs()).toBe(false);

        /* eslint-disable no-tabs */
        editor.setText(dedent`
          /*
           * Comment with a leading space.
           */

          {
          	hello;
          }
        `);
        /* eslint-enable no-tabs */
        disposable.dispose();
        disposable = registry.maintainConfig(editor);
        expect(editor.getSoftTabs()).toBe(false);

        editor.setText(dedent`
          /*
           * Comment with a leading space.
           */

          {
            hello;
          }
        `);
        disposable.dispose();
        disposable = registry.maintainConfig(editor);
        expect(editor.getSoftTabs()).toBe(true);
      });
    });

    describe('when the "tabType" config setting is "auto"', function() {
      it('enables or disables soft tabs based on the "softTabs" config setting', async function() {
        registry.maintainConfig(editor);
        await initialPackageActivation;

        editor.setText('abc\ndef');
        atom.config.set('editor.softTabs', true);
        atom.config.set('editor.tabType', 'auto');
        expect(editor.getSoftTabs()).toBe(true);

        atom.config.set('editor.softTabs', false);
        expect(editor.getSoftTabs()).toBe(false);
      });
    });

    it('enables or disables soft tabs based on the config', async function() {
      editor.update({ softTabs: true });
      expect(editor.getSoftTabs()).toBe(true);

      atom.config.set('editor.tabType', 'hard');
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getSoftTabs()).toBe(false);

      atom.config.set('editor.tabType', 'soft');
      expect(editor.getSoftTabs()).toBe(true);

      atom.config.set('editor.tabType', 'auto');
      atom.config.set('editor.softTabs', true);
      expect(editor.getSoftTabs()).toBe(true);
    });

    it('enables or disables atomic soft tabs based on the config', async function() {
      editor.update({ atomicSoftTabs: true });
      expect(editor.hasAtomicSoftTabs()).toBe(true);

      atom.config.set('editor.atomicSoftTabs', false);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.hasAtomicSoftTabs()).toBe(false);

      atom.config.set('editor.atomicSoftTabs', true);
      expect(editor.hasAtomicSoftTabs()).toBe(true);
    });

    it('enables or disables cursor on selection visibility based on the config', async function() {
      editor.update({ showCursorOnSelection: true });
      expect(editor.getShowCursorOnSelection()).toBe(true);

      atom.config.set('editor.showCursorOnSelection', false);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getShowCursorOnSelection()).toBe(false);

      atom.config.set('editor.showCursorOnSelection', true);
      expect(editor.getShowCursorOnSelection()).toBe(true);
    });

    it('enables or disables line numbers based on the config', async function() {
      editor.update({ showLineNumbers: true });
      expect(editor.showLineNumbers).toBe(true);

      atom.config.set('editor.showLineNumbers', false);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.showLineNumbers).toBe(false);

      atom.config.set('editor.showLineNumbers', true);
      expect(editor.showLineNumbers).toBe(true);
    });

    it('sets the invisibles based on the config', async function() {
      const invisibles1 = { tab: 'a', cr: false, eol: false, space: false };
      const invisibles2 = { tab: 'b', cr: false, eol: false, space: false };

      editor.update({
        showInvisibles: true,
        invisibles: invisibles1
      });
      expect(editor.getInvisibles()).toEqual(invisibles1);

      atom.config.set('editor.showInvisibles', true);
      atom.config.set('editor.invisibles', invisibles2);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getInvisibles()).toEqual(invisibles2);

      atom.config.set('editor.invisibles', invisibles1);
      expect(editor.getInvisibles()).toEqual(invisibles1);

      atom.config.set('editor.showInvisibles', false);
      expect(editor.getInvisibles()).toEqual({});
    });

    it('enables or disables the indent guide based on the config', async function() {
      editor.update({ showIndentGuide: true });
      expect(editor.doesShowIndentGuide()).toBe(true);

      atom.config.set('editor.showIndentGuide', false);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.doesShowIndentGuide()).toBe(false);

      atom.config.set('editor.showIndentGuide', true);
      expect(editor.doesShowIndentGuide()).toBe(true);
    });

    it('enables or disables soft wrap based on the config', async function() {
      editor.update({ softWrapped: true });
      expect(editor.isSoftWrapped()).toBe(true);

      atom.config.set('editor.softWrap', false);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.isSoftWrapped()).toBe(false);

      atom.config.set('editor.softWrap', true);
      expect(editor.isSoftWrapped()).toBe(true);
    });

    it('sets the soft wrap indent length based on the config', async function() {
      editor.update({ softWrapHangingIndentLength: 4 });
      expect(editor.getSoftWrapHangingIndentLength()).toBe(4);

      atom.config.set('editor.softWrapHangingIndent', 2);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getSoftWrapHangingIndentLength()).toBe(2);

      atom.config.set('editor.softWrapHangingIndent', 4);
      expect(editor.getSoftWrapHangingIndentLength()).toBe(4);
    });

    it('enables or disables preferred line length-based soft wrap based on the config', async function() {
      editor.update({
        softWrapped: true,
        preferredLineLength: 80,
        editorWidthInChars: 120,
        softWrapAtPreferredLineLength: true
      });

      expect(editor.getSoftWrapColumn()).toBe(80);

      atom.config.set('editor.softWrap', true);
      atom.config.set('editor.softWrapAtPreferredLineLength', false);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getSoftWrapColumn()).toBe(120);

      atom.config.set('editor.softWrapAtPreferredLineLength', true);
      expect(editor.getSoftWrapColumn()).toBe(80);
    });

    it('allows for custom definition of maximum soft wrap based on config', async function() {
      editor.update({
        softWrapped: false,
        maxScreenLineLength: 1500
      });

      expect(editor.getSoftWrapColumn()).toBe(1500);

      atom.config.set('editor.softWrap', false);
      atom.config.set('editor.maxScreenLineLength', 500);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getSoftWrapColumn()).toBe(500);
    });

    it('sets the preferred line length based on the config', async function() {
      editor.update({ preferredLineLength: 80 });
      expect(editor.getPreferredLineLength()).toBe(80);

      atom.config.set('editor.preferredLineLength', 110);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getPreferredLineLength()).toBe(110);

      atom.config.set('editor.preferredLineLength', 80);
      expect(editor.getPreferredLineLength()).toBe(80);
    });

    it('enables or disables auto-indent based on the config', async function() {
      editor.update({ autoIndent: true });
      expect(editor.shouldAutoIndent()).toBe(true);

      atom.config.set('editor.autoIndent', false);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.shouldAutoIndent()).toBe(false);

      atom.config.set('editor.autoIndent', true);
      expect(editor.shouldAutoIndent()).toBe(true);
    });

    it('enables or disables auto-indent-on-paste based on the config', async function() {
      editor.update({ autoIndentOnPaste: true });
      expect(editor.shouldAutoIndentOnPaste()).toBe(true);

      atom.config.set('editor.autoIndentOnPaste', false);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.shouldAutoIndentOnPaste()).toBe(false);

      atom.config.set('editor.autoIndentOnPaste', true);
      expect(editor.shouldAutoIndentOnPaste()).toBe(true);
    });

    it('enables or disables scrolling past the end of the buffer based on the config', async function() {
      editor.update({ scrollPastEnd: true });
      expect(editor.getScrollPastEnd()).toBe(true);

      atom.config.set('editor.scrollPastEnd', false);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getScrollPastEnd()).toBe(false);

      atom.config.set('editor.scrollPastEnd', true);
      expect(editor.getScrollPastEnd()).toBe(true);
    });

    it('sets the undo grouping interval based on the config', async function() {
      editor.update({ undoGroupingInterval: 300 });
      expect(editor.getUndoGroupingInterval()).toBe(300);

      atom.config.set('editor.undoGroupingInterval', 600);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getUndoGroupingInterval()).toBe(600);

      atom.config.set('editor.undoGroupingInterval', 300);
      expect(editor.getUndoGroupingInterval()).toBe(300);
    });

    it('sets the scroll sensitivity based on the config', async function() {
      editor.update({ scrollSensitivity: 50 });
      expect(editor.getScrollSensitivity()).toBe(50);

      atom.config.set('editor.scrollSensitivity', 60);
      registry.maintainConfig(editor);
      await initialPackageActivation;
      expect(editor.getScrollSensitivity()).toBe(60);

      atom.config.set('editor.scrollSensitivity', 70);
      expect(editor.getScrollSensitivity()).toBe(70);
    });

    describe('when called twice with a given editor', function() {
      it('does nothing the second time', async function() {
        editor.update({ scrollSensitivity: 50 });

        const disposable1 = registry.maintainConfig(editor);
        const disposable2 = registry.maintainConfig(editor);
        await initialPackageActivation;

        atom.config.set('editor.scrollSensitivity', 60);
        expect(editor.getScrollSensitivity()).toBe(60);

        disposable2.dispose();
        atom.config.set('editor.scrollSensitivity', 70);
        expect(editor.getScrollSensitivity()).toBe(70);

        disposable1.dispose();
        atom.config.set('editor.scrollSensitivity', 80);
        expect(editor.getScrollSensitivity()).toBe(70);
      });
    });
  });
});

function getSubscriptionCount(editor) {
  return (
    editor.emitter.getTotalListenerCount() +
    editor.tokenizedBuffer.emitter.getTotalListenerCount() +
    editor.buffer.emitter.getTotalListenerCount() +
    editor.displayLayer.emitter.getTotalListenerCount()
  );
}

function retainedEditorCount(registry) {
  const editors = new Set();
  registry.editors.forEach(e => editors.add(e));
  registry.editorsWithMaintainedConfig.forEach(e => editors.add(e));
  registry.editorsWithMaintainedGrammar.forEach(e => editors.add(e));
  return editors.size;
}
