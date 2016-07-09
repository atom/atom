/** @babel */

import {TextBuffer} from 'atom'
import TextEditorRegistry from '../src/text-editor-registry'
import TextEditor from '../src/text-editor'

describe('TextEditorRegistry', function () {
  let registry, editor

  beforeEach(function () {
    registry = new TextEditorRegistry({
      config: atom.config
    })

    editor = new TextEditor({
      buffer: new TextBuffer({filePath: 'test.js'}),
      config: atom.config,
      clipboard: atom.clipboard,
      grammarRegistry: atom.grammars
    })
  })

  afterEach(function () {
    registry.destroy()
  })

  describe('.add', function () {
    it('adds an editor to the list of registered editors', function () {
      registry.add(editor)
      expect(editor.registered).toBe(true)
      expect(registry.editors.size).toBe(1)
      expect(registry.editors.has(editor)).toBe(true)
    })

    it('returns a Disposable that can unregister the editor', function () {
      const disposable = registry.add(editor)
      expect(registry.editors.size).toBe(1)
      disposable.dispose()
      expect(registry.editors.size).toBe(0)
      expect(editor.registered).toBe(false)
    })
  })

  describe('.observe', function () {
    it('calls the callback for current and future editors until unsubscribed', function () {
      const spy = jasmine.createSpy()
      const [editor1, editor2, editor3] = [{}, {}, {}]
      registry.add(editor1)
      const subscription = registry.observe(spy)
      expect(spy.calls.length).toBe(1)

      registry.add(editor2)
      expect(spy.calls.length).toBe(2)
      expect(spy.argsForCall[0][0]).toBe(editor1)
      expect(spy.argsForCall[1][0]).toBe(editor2)
      subscription.dispose()

      registry.add(editor3)
      expect(spy.calls.length).toBe(2)
    })
  })

  describe('.maintainGrammar', function () {
    it('assigns a grammar to the editor based on its path', async function () {
      await atom.packages.activatePackage('language-javascript')
      await atom.packages.activatePackage('language-c')

      registry.maintainGrammar(editor)
      expect(editor.getGrammar().name).toBe('JavaScript')

      editor.getBuffer().setPath('test.c')
      expect(editor.getGrammar().name).toBe('C')
    })

    it('updates the editor\'s grammar when a more appropriate grammar is added for its path', async function () {
      expect(editor.getGrammar().name).toBe('Null Grammar')
      registry.maintainGrammar(editor)
      await atom.packages.activatePackage('language-javascript')
      expect(editor.getGrammar().name).toBe('JavaScript')
    });
  })

  describe('.maintainConfig(editor)', function () {
    it('sets the encoding based on the config', function () {
      editor.setEncoding('utf8')
      expect(editor.getEncoding()).toBe('utf8')

      atom.config.set('core.fileEncoding', 'utf16le')
      registry.maintainConfig(editor)
      expect(editor.getEncoding()).toBe('utf16le')

      atom.config.set('core.fileEncoding', 'utf8')
      expect(editor.getEncoding()).toBe('utf8')
    });

    it('sets the tab length based on the config', function () {
      editor.setTabLength(4)
      expect(editor.getTabLength()).toBe(4)

      atom.config.set('editor.tabLength', 8)
      registry.maintainConfig(editor)
      expect(editor.getTabLength()).toBe(8)

      atom.config.set('editor.tabLength', 4)
      expect(editor.getTabLength()).toBe(4)
    });

    it('enables or disables atomic soft tabs based on the config', function () {
      editor.setAtomicSoftTabs(true)
      expect(editor.hasAtomicSoftTabs()).toBe(true)

      atom.config.set('editor.atomicSoftTabs', false)
      registry.maintainConfig(editor)
      expect(editor.hasAtomicSoftTabs()).toBe(false)

      atom.config.set('editor.atomicSoftTabs', true)
      expect(editor.hasAtomicSoftTabs()).toBe(true)
    });

    it('enables or disables invisible based on the config', function () {
      editor.setShowInvisibles(true)
      expect(editor.doesShowInvisibles()).toBe(true)

      atom.config.set('editor.showInvisibles', false)
      registry.maintainConfig(editor)
      expect(editor.doesShowInvisibles()).toBe(false)

      atom.config.set('editor.showInvisibles', true)
      expect(editor.doesShowInvisibles()).toBe(true)
    });

    it('sets the invisibles based on the config', function () {
      editor.setShowInvisibles(true)
      atom.config.set('editor.showInvisibles', true)

      const invisibles1 = {'tab': 'a', 'cr': false, eol: false, space: false}
      const invisibles2 = {'tab': 'b', 'cr': false, eol: false, space: false}

      editor.setInvisibles(invisibles1)
      expect(editor.getInvisibles()).toEqual(invisibles1)

      atom.config.set('editor.invisibles', invisibles2)
      registry.maintainConfig(editor)
      expect(editor.getInvisibles()).toEqual(invisibles2)

      atom.config.set('editor.invisibles', invisibles1)
      expect(editor.getInvisibles()).toEqual(invisibles1)
    });
  })
})
