const {it, fit, ffit, fffit, beforeEach, afterEach} = require('./async-spec-helpers')

const path = require('path')
const fs = require('fs-plus')
const temp = require('temp').track()
const TextBuffer = require('text-buffer')
const GrammarRegistry = require('../src/grammar-registry')

describe('GrammarRegistry', () => {
  let grammarRegistry

  beforeEach(() => {
    grammarRegistry = new GrammarRegistry({config: atom.config})
  })

  describe('.assignLanguageMode(buffer, languageName)', () => {
    it('assigns to the buffer a language mode with the given language name', async () => {
      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      grammarRegistry.loadGrammarSync(require.resolve('language-css/grammars/css.cson'))

      const buffer = new TextBuffer()
      expect(grammarRegistry.assignLanguageMode(buffer, 'source.js')).toBe(true)
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.js')
      expect(grammarRegistry.getAssignedLanguageId(buffer)).toBe('source.js')

      // Returns true if we found the grammar, even if it didn't change
      expect(grammarRegistry.assignLanguageMode(buffer, 'source.js')).toBe(true)

      // Language names are not case-sensitive
      expect(grammarRegistry.assignLanguageMode(buffer, 'source.css')).toBe(true)
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.css')

      // Returns false if no language is found
      expect(grammarRegistry.assignLanguageMode(buffer, 'blub')).toBe(false)
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.css')
    })

    describe('when no languageName is passed', () => {
      it('makes the buffer use the null grammar', () => {
        grammarRegistry.loadGrammarSync(require.resolve('language-css/grammars/css.cson'))

        const buffer = new TextBuffer()
        expect(grammarRegistry.assignLanguageMode(buffer, 'source.css')).toBe(true)
        expect(buffer.getLanguageMode().getLanguageId()).toBe('source.css')

        expect(grammarRegistry.assignLanguageMode(buffer, null)).toBe(true)
        expect(buffer.getLanguageMode().getLanguageId()).toBe('text.plain.null-grammar')
        expect(grammarRegistry.getAssignedLanguageId(buffer)).toBe(null)
      })
    })
  })

  describe('.autoAssignLanguageMode(buffer)', () => {
    it('assigns to the buffer a language mode based on the best available grammar', () => {
      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      grammarRegistry.loadGrammarSync(require.resolve('language-css/grammars/css.cson'))

      const buffer = new TextBuffer()
      buffer.setPath('foo.js')
      expect(grammarRegistry.assignLanguageMode(buffer, 'source.css')).toBe(true)
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.css')

      grammarRegistry.autoAssignLanguageMode(buffer)
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.js')
    })
  })

  describe('.maintainLanguageMode(buffer)', () => {
    it('assigns a grammar to the buffer based on its path', async () => {
      const buffer = new TextBuffer()

      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      grammarRegistry.loadGrammarSync(require.resolve('language-c/grammars/c.cson'))

      buffer.setPath('test.js')
      grammarRegistry.maintainLanguageMode(buffer)
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.js')

      buffer.setPath('test.c')
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.c')
    })

    it('updates the buffer\'s grammar when a more appropriate grammar is added for its path', async () => {
      const buffer = new TextBuffer()
      expect(buffer.getLanguageMode().getLanguageId()).toBe(null)

      buffer.setPath('test.js')
      grammarRegistry.maintainLanguageMode(buffer)

      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.js')
    })

    it('can be overridden by calling .assignLanguageMode', () => {
      const buffer = new TextBuffer()

      buffer.setPath('test.js')
      grammarRegistry.maintainLanguageMode(buffer)

      grammarRegistry.loadGrammarSync(require.resolve('language-css/grammars/css.cson'))
      expect(grammarRegistry.assignLanguageMode(buffer, 'source.css')).toBe(true)
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.css')

      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.css')
    })

    it('returns a disposable that can be used to stop the registry from updating the buffer', async () => {
      const buffer = new TextBuffer()
      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))

      const previousSubscriptionCount = buffer.emitter.getTotalListenerCount()
      const disposable = grammarRegistry.maintainLanguageMode(buffer)
      expect(buffer.emitter.getTotalListenerCount()).toBeGreaterThan(previousSubscriptionCount)
      expect(retainedBufferCount(grammarRegistry)).toBe(1)

      buffer.setPath('test.js')
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.js')

      buffer.setPath('test.txt')
      expect(buffer.getLanguageMode().getLanguageId()).toBe('text.plain.null-grammar')

      disposable.dispose()
      expect(buffer.emitter.getTotalListenerCount()).toBe(previousSubscriptionCount)
      expect(retainedBufferCount(grammarRegistry)).toBe(0)

      buffer.setPath('test.js')
      expect(buffer.getLanguageMode().getLanguageId()).toBe('text.plain.null-grammar')
      expect(retainedBufferCount(grammarRegistry)).toBe(0)
    })

    it('doesn\'t do anything when called a second time with the same buffer', async () => {
      const buffer = new TextBuffer()
      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      const disposable1 = grammarRegistry.maintainLanguageMode(buffer)
      const disposable2 = grammarRegistry.maintainLanguageMode(buffer)

      buffer.setPath('test.js')
      expect(buffer.getLanguageMode().getLanguageId()).toBe('source.js')

      disposable2.dispose()
      buffer.setPath('test.txt')
      expect(buffer.getLanguageMode().getLanguageId()).toBe('text.plain.null-grammar')

      disposable1.dispose()
      buffer.setPath('test.js')
      expect(buffer.getLanguageMode().getLanguageId()).toBe('text.plain.null-grammar')
    })

    it('does not retain the buffer after the buffer is destroyed', () => {
      const buffer = new TextBuffer()
      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))

      const disposable = grammarRegistry.maintainLanguageMode(buffer)
      expect(retainedBufferCount(grammarRegistry)).toBe(1)
      expect(subscriptionCount(grammarRegistry)).toBe(2)

      buffer.destroy()
      expect(retainedBufferCount(grammarRegistry)).toBe(0)
      expect(subscriptionCount(grammarRegistry)).toBe(0)
      expect(buffer.emitter.getTotalListenerCount()).toBe(0)

      disposable.dispose()
      expect(retainedBufferCount(grammarRegistry)).toBe(0)
      expect(subscriptionCount(grammarRegistry)).toBe(0)
    })

    it('does not retain the buffer when the grammar registry is destroyed', () => {
      const buffer = new TextBuffer()
      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))

      const disposable = grammarRegistry.maintainLanguageMode(buffer)
      expect(retainedBufferCount(grammarRegistry)).toBe(1)
      expect(subscriptionCount(grammarRegistry)).toBe(2)

      grammarRegistry.clear()

      expect(retainedBufferCount(grammarRegistry)).toBe(0)
      expect(subscriptionCount(grammarRegistry)).toBe(0)
      expect(buffer.emitter.getTotalListenerCount()).toBe(0)
    })
  })

  describe('.selectGrammar(filePath)', () => {
    it('always returns a grammar', () => {
      const registry = new GrammarRegistry({config: atom.config})
      expect(registry.selectGrammar().scopeName).toBe('text.plain.null-grammar')
    })

    it('selects the text.plain grammar over the null grammar', async () => {
      await atom.packages.activatePackage('language-text')
      expect(atom.grammars.selectGrammar('test.txt').scopeName).toBe('text.plain')
    })

    it('selects a grammar based on the file path case insensitively', async () => {
      await atom.packages.activatePackage('language-coffee-script')
      expect(atom.grammars.selectGrammar('/tmp/source.coffee').scopeName).toBe('source.coffee')
      expect(atom.grammars.selectGrammar('/tmp/source.COFFEE').scopeName).toBe('source.coffee')
    })

    describe('on Windows', () => {
      let originalPlatform

      beforeEach(() => {
        originalPlatform = process.platform
        Object.defineProperty(process, 'platform', {value: 'win32'})
      })

      afterEach(() => {
        Object.defineProperty(process, 'platform', {value: originalPlatform})
      })

      it('normalizes back slashes to forward slashes when matching the fileTypes', async () => {
        await atom.packages.activatePackage('language-git')
        expect(atom.grammars.selectGrammar('something\\.git\\config').scopeName).toBe('source.git-config')
      })
    })

    it("can use the filePath to load the correct grammar based on the grammar's filetype", async () => {
      await atom.packages.activatePackage('language-git')
      await atom.packages.activatePackage('language-javascript')
      await atom.packages.activatePackage('language-ruby')

      expect(atom.grammars.selectGrammar('file.js').name).toBe('JavaScript') // based on extension (.js)
      expect(atom.grammars.selectGrammar(path.join(temp.dir, '.git', 'config')).name).toBe('Git Config') // based on end of the path (.git/config)
      expect(atom.grammars.selectGrammar('Rakefile').name).toBe('Ruby') // based on the file's basename (Rakefile)
      expect(atom.grammars.selectGrammar('curb').name).toBe('Null Grammar')
      expect(atom.grammars.selectGrammar('/hu.git/config').name).toBe('Null Grammar')
    })

    it("uses the filePath's shebang line if the grammar cannot be determined by the extension or basename", async () => {
      await atom.packages.activatePackage('language-javascript')
      await atom.packages.activatePackage('language-ruby')

      const filePath = require.resolve('./fixtures/shebang')
      expect(atom.grammars.selectGrammar(filePath).name).toBe('Ruby')
    })

    it('uses the number of newlines in the first line regex to determine the number of lines to test against', async () => {
      await atom.packages.activatePackage('language-property-list')
      await atom.packages.activatePackage('language-coffee-script')

      let fileContent = 'first-line\n<html>'
      expect(atom.grammars.selectGrammar('dummy.coffee', fileContent).name).toBe('CoffeeScript')

      fileContent = '<?xml version="1.0" encoding="UTF-8"?>'
      expect(atom.grammars.selectGrammar('grammar.tmLanguage', fileContent).name).toBe('Null Grammar')

      fileContent += '\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
      expect(atom.grammars.selectGrammar('grammar.tmLanguage', fileContent).name).toBe('Property List (XML)')
    })

    it("doesn't read the file when the file contents are specified", async () => {
      await atom.packages.activatePackage('language-ruby')

      const filePath = require.resolve('./fixtures/shebang')
      const filePathContents = fs.readFileSync(filePath, 'utf8')
      spyOn(fs, 'read').andCallThrough()
      expect(atom.grammars.selectGrammar(filePath, filePathContents).name).toBe('Ruby')
      expect(fs.read).not.toHaveBeenCalled()
    })

    describe('when multiple grammars have matching fileTypes', () => {
      it('selects the grammar with the longest fileType match', () => {
        const grammarPath1 = temp.path({suffix: '.json'})
        fs.writeFileSync(grammarPath1, JSON.stringify({
          name: 'test1',
          scopeName: 'source1',
          fileTypes: ['test']
        }))
        const grammar1 = atom.grammars.loadGrammarSync(grammarPath1)
        expect(atom.grammars.selectGrammar('more.test', '')).toBe(grammar1)
        fs.removeSync(grammarPath1)

        const grammarPath2 = temp.path({suffix: '.json'})
        fs.writeFileSync(grammarPath2, JSON.stringify({
          name: 'test2',
          scopeName: 'source2',
          fileTypes: ['test', 'more.test']
        }))
        const grammar2 = atom.grammars.loadGrammarSync(grammarPath2)
        expect(atom.grammars.selectGrammar('more.test', '')).toBe(grammar2)
        return fs.removeSync(grammarPath2)
      })
    })

    it('favors non-bundled packages when breaking scoring ties', async () => {
      await atom.packages.activatePackage('language-ruby')
      await atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'packages', 'package-with-rb-filetype'))

      atom.grammars.grammarForScopeName('source.ruby').bundledPackage = true
      atom.grammars.grammarForScopeName('test.rb').bundledPackage = false

      expect(atom.grammars.selectGrammar('test.rb', '#!/usr/bin/env ruby').scopeName).toBe('source.ruby')
      expect(atom.grammars.selectGrammar('test.rb', '#!/usr/bin/env testruby').scopeName).toBe('test.rb')
      expect(atom.grammars.selectGrammar('test.rb').scopeName).toBe('test.rb')
    })

    describe('when there is no file path', () => {
      it('does not throw an exception (regression)', () => {
        expect(() => atom.grammars.selectGrammar(null, '#!/usr/bin/ruby')).not.toThrow()
        expect(() => atom.grammars.selectGrammar(null, '')).not.toThrow()
        expect(() => atom.grammars.selectGrammar(null, null)).not.toThrow()
      })
    })

    describe('when the user has custom grammar file types', () => {
      it('considers the custom file types as well as those defined in the grammar', async () => {
        await atom.packages.activatePackage('language-ruby')
        atom.config.set('core.customFileTypes', {'source.ruby': ['Cheffile']})
        expect(atom.grammars.selectGrammar('build/Cheffile', 'cookbook "postgres"').scopeName).toBe('source.ruby')
      })

      it('favors user-defined file types over built-in ones of equal length', async () => {
        await atom.packages.activatePackage('language-ruby')
        await atom.packages.activatePackage('language-coffee-script')

        atom.config.set('core.customFileTypes', {
          'source.coffee': ['Rakefile'],
          'source.ruby': ['Cakefile']
        })
        expect(atom.grammars.selectGrammar('Rakefile', '').scopeName).toBe('source.coffee')
        expect(atom.grammars.selectGrammar('Cakefile', '').scopeName).toBe('source.ruby')
      })

      it('favors user-defined file types over grammars with matching first-line-regexps', async () => {
        await atom.packages.activatePackage('language-ruby')
        await atom.packages.activatePackage('language-javascript')

        atom.config.set('core.customFileTypes', {'source.ruby': ['bootstrap']})
        expect(atom.grammars.selectGrammar('bootstrap', '#!/usr/bin/env node').scopeName).toBe('source.ruby')
      })
    })

    it('favors a grammar with a matching file type over one with m matching first line pattern', async () => {
      await atom.packages.activatePackage('language-ruby')
      await atom.packages.activatePackage('language-javascript')
      expect(atom.grammars.selectGrammar('foo.rb', '#!/usr/bin/env node').scopeName).toBe('source.ruby')
    })
  })

  describe('.removeGrammar(grammar)', () => {
    it("removes the grammar, so it won't be returned by selectGrammar", async () => {
      await atom.packages.activatePackage('language-javascript')
      const grammar = atom.grammars.selectGrammar('foo.js')
      atom.grammars.removeGrammar(grammar)
      expect(atom.grammars.selectGrammar('foo.js').name).not.toBe(grammar.name)
    })
  })

  describe('serialization', () => {
    it('persists editors\' grammar overrides', async () => {
      const buffer1 = new TextBuffer()
      const buffer2 = new TextBuffer()

      grammarRegistry.loadGrammarSync(require.resolve('language-c/grammars/c.cson'))
      grammarRegistry.loadGrammarSync(require.resolve('language-html/grammars/html.cson'))
      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))

      grammarRegistry.maintainLanguageMode(buffer1)
      grammarRegistry.maintainLanguageMode(buffer2)
      grammarRegistry.assignLanguageMode(buffer1, 'source.c')
      grammarRegistry.assignLanguageMode(buffer2, 'source.js')

      const buffer1Copy = await TextBuffer.deserialize(buffer1.serialize())
      const buffer2Copy = await TextBuffer.deserialize(buffer2.serialize())

      const grammarRegistryCopy = new GrammarRegistry({config: atom.config})
      grammarRegistryCopy.deserialize(JSON.parse(JSON.stringify(grammarRegistry.serialize())))

      grammarRegistryCopy.loadGrammarSync(require.resolve('language-c/grammars/c.cson'))
      grammarRegistryCopy.loadGrammarSync(require.resolve('language-html/grammars/html.cson'))

      expect(buffer1Copy.getLanguageMode().getLanguageId()).toBe(null)
      expect(buffer2Copy.getLanguageMode().getLanguageId()).toBe(null)

      grammarRegistryCopy.maintainLanguageMode(buffer1Copy)
      grammarRegistryCopy.maintainLanguageMode(buffer2Copy)
      expect(buffer1Copy.getLanguageMode().getLanguageId()).toBe('source.c')
      expect(buffer2Copy.getLanguageMode().getLanguageId()).toBe(null)

      grammarRegistryCopy.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      expect(buffer1Copy.getLanguageMode().getLanguageId()).toBe('source.c')
      expect(buffer2Copy.getLanguageMode().getLanguageId()).toBe('source.js')
    })
  })
})

function retainedBufferCount (grammarRegistry) {
  return grammarRegistry.grammarScoresByBuffer.size
}

function subscriptionCount (grammarRegistry) {
  return grammarRegistry.subscriptions.disposables.size
}
