const {it, fit, ffit, fffit, beforeEach, afterEach, conditionPromise, timeoutPromise} = require('./async-spec-helpers')

const path = require('path')
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
      expect(grammarRegistry.assignLanguageMode(buffer, 'javascript')).toBe(true)
      expect(buffer.getLanguageMode().getLanguageName()).toBe('JavaScript')

      // Returns true if we found the grammar, even if it didn't change
      expect(grammarRegistry.assignLanguageMode(buffer, 'javascript')).toBe(true)

      // Language names are not case-sensitive
      expect(grammarRegistry.assignLanguageMode(buffer, 'css')).toBe(true)
      expect(buffer.getLanguageMode().getLanguageName()).toBe('CSS')

      // Returns false if no language is found
      expect(grammarRegistry.assignLanguageMode(buffer, 'blub')).toBe(false)
      expect(buffer.getLanguageMode().getLanguageName()).toBe('CSS')
    })

    describe('when no languageName is passed', () => {
      it('makes the buffer use the null grammar', () => {
        grammarRegistry.loadGrammarSync(require.resolve('language-css/grammars/css.cson'))

        const buffer = new TextBuffer()
        expect(grammarRegistry.assignLanguageMode(buffer, 'css')).toBe(true)
        expect(buffer.getLanguageMode().getLanguageName()).toBe('CSS')

        expect(grammarRegistry.assignLanguageMode(buffer, null)).toBe(true)
        expect(buffer.getLanguageMode().getLanguageName()).toBe('None')
      })
    })
  })

  describe('.autoAssignLanguageMode(buffer)', () => {
    it('assigns to the buffer a language mode based on the best available grammar', () => {
      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      grammarRegistry.loadGrammarSync(require.resolve('language-css/grammars/css.cson'))

      const buffer = new TextBuffer()
      buffer.setPath('foo.js')
      expect(grammarRegistry.assignLanguageMode(buffer, 'css')).toBe(true)
      expect(buffer.getLanguageMode().getLanguageName()).toBe('CSS')

      expect(grammarRegistry.autoAssignLanguageMode(buffer)).toBe(true)
      expect(buffer.getLanguageMode().getLanguageName()).toBe('JavaScript')
    })
  })

  describe('.maintainLanguageMode', () => {
    it('assigns a grammar to the buffer based on its path', async () => {
      const buffer = new TextBuffer()

      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      grammarRegistry.loadGrammarSync(require.resolve('language-c/grammars/c.cson'))

      buffer.setPath('test.js')
      grammarRegistry.maintainLanguageMode(buffer)
      expect(buffer.getLanguageMode().getLanguageName()).toBe('JavaScript')

      buffer.setPath('test.c')
      expect(buffer.getLanguageMode().getLanguageName()).toBe('C')
    })

    it('updates the buffer\'s grammar when a more appropriate grammar is added for its path', async () => {
      const buffer = new TextBuffer()
      expect(buffer.getLanguageMode().getLanguageName()).toBe('None')

      buffer.setPath('test.js')
      grammarRegistry.maintainLanguageMode(buffer)

      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      expect(buffer.getLanguageMode().getLanguageName()).toBe('JavaScript')
    })

    it('can be overridden by calling .assignLanguageMode', () => {
      const buffer = new TextBuffer()
      expect(buffer.getLanguageMode().getLanguageName()).toBe('None')

      buffer.setPath('test.js')
      grammarRegistry.maintainLanguageMode(buffer)

      grammarRegistry.loadGrammarSync(require.resolve('language-css/grammars/css.cson'))
      expect(grammarRegistry.assignLanguageMode(buffer, 'css')).toBe(true)
      expect(buffer.getLanguageMode().getLanguageName()).toBe('CSS')

      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
      expect(buffer.getLanguageMode().getLanguageName()).toBe('CSS')
    })

    it('returns a disposable that can be used to stop the registry from updating the buffer', async () => {
      const buffer = new TextBuffer()
      grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))

      const previousSubscriptionCount = buffer.emitter.getTotalListenerCount()
      const disposable = grammarRegistry.maintainLanguageMode(buffer)
      expect(buffer.emitter.getTotalListenerCount()).toBeGreaterThan(previousSubscriptionCount)
      expect(retainedBufferCount(grammarRegistry)).toBe(1)

      buffer.setPath('test.js')
      expect(buffer.getLanguageMode().getLanguageName()).toBe('JavaScript')

      buffer.setPath('test.txt')
      expect(buffer.getLanguageMode().getLanguageName()).toBe('Null Grammar')

      disposable.dispose()
      expect(buffer.emitter.getTotalListenerCount()).toBe(previousSubscriptionCount)
      expect(retainedBufferCount(grammarRegistry)).toBe(0)

      buffer.setPath('test.js')
      expect(buffer.getLanguageMode().getLanguageName()).toBe('Null Grammar')
      expect(retainedBufferCount(grammarRegistry)).toBe(0)
    })

    describe('when called twice with a given buffer', () => {
      it('does nothing the second time', async () => {
        const buffer = new TextBuffer()
        grammarRegistry.loadGrammarSync(require.resolve('language-javascript/grammars/javascript.cson'))
        const disposable1 = grammarRegistry.maintainLanguageMode(buffer)
        const disposable2 = grammarRegistry.maintainLanguageMode(buffer)

        buffer.setPath('test.js')
        expect(buffer.getLanguageMode().getLanguageName()).toBe('JavaScript')

        disposable2.dispose()
        buffer.setPath('test.txt')
        expect(buffer.getLanguageMode().getLanguageName()).toBe('Null Grammar')

        disposable1.dispose()
        buffer.setPath('test.js')
        expect(buffer.getLanguageMode().getLanguageName()).toBe('Null Grammar')
      })
    })
  })
})

function retainedBufferCount (grammarRegistry) {
  return grammarRegistry.grammarScoresByBuffer.size
}
