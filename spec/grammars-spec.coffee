path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
GrammarRegistry = require '../src/grammar-registry'

describe "the `grammars` global", ->
  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-text')

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.packages.activatePackage('language-coffee-script')

    waitsForPromise ->
      atom.packages.activatePackage('language-ruby')

    waitsForPromise ->
      atom.packages.activatePackage('language-git')

  afterEach ->
    atom.packages.deactivatePackages()
    atom.packages.unloadPackages()

  describe ".selectGrammar(filePath)", ->
    it "always returns a grammar", ->
      registry = new GrammarRegistry(config: atom.config)
      expect(registry.selectGrammar().scopeName).toBe 'text.plain.null-grammar'

    it "selects the text.plain grammar over the null grammar", ->
      expect(atom.grammars.selectGrammar('test.txt').scopeName).toBe 'text.plain'

    it "selects a grammar based on the file path case insensitively", ->
      expect(atom.grammars.selectGrammar('/tmp/source.coffee').scopeName).toBe 'source.coffee'
      expect(atom.grammars.selectGrammar('/tmp/source.COFFEE').scopeName).toBe 'source.coffee'

    describe "on Windows", ->
      originalPlatform = null

      beforeEach ->
        originalPlatform = process.platform
        Object.defineProperty process, 'platform', value: 'win32'

      afterEach ->
        Object.defineProperty process, 'platform', value: originalPlatform

      it "normalizes back slashes to forward slashes when matching the fileTypes", ->
        expect(atom.grammars.selectGrammar('something\\.git\\config').scopeName).toBe 'source.git-config'

    it "can use the filePath to load the correct grammar based on the grammar's filetype", ->
      waitsForPromise ->
        atom.packages.activatePackage('language-git')

      runs ->
        expect(atom.grammars.selectGrammar("file.js").name).toBe "JavaScript" # based on extension (.js)
        expect(atom.grammars.selectGrammar(path.join(temp.dir, '.git', 'config')).name).toBe "Git Config" # based on end of the path (.git/config)
        expect(atom.grammars.selectGrammar("Rakefile").name).toBe "Ruby" # based on the file's basename (Rakefile)
        expect(atom.grammars.selectGrammar("curb").name).toBe "Null Grammar"
        expect(atom.grammars.selectGrammar("/hu.git/config").name).toBe "Null Grammar"

    it "uses the filePath's shebang line if the grammar cannot be determined by the extension or basename", ->
      filePath = require.resolve("./fixtures/shebang")
      expect(atom.grammars.selectGrammar(filePath).name).toBe "Ruby"

    it "uses the number of newlines in the first line regex to determine the number of lines to test against", ->
      waitsForPromise ->
        atom.packages.activatePackage('language-property-list')

      runs ->
        fileContent = "first-line\n<html>"
        expect(atom.grammars.selectGrammar("dummy.coffee", fileContent).name).toBe "CoffeeScript"

        fileContent = '<?xml version="1.0" encoding="UTF-8"?>'
        expect(atom.grammars.selectGrammar("grammar.tmLanguage", fileContent).name).toBe "Null Grammar"

        fileContent += '\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
        expect(atom.grammars.selectGrammar("grammar.tmLanguage", fileContent).name).toBe "Property List (XML)"

    it "doesn't read the file when the file contents are specified", ->
      filePath = require.resolve("./fixtures/shebang")
      filePathContents = fs.readFileSync(filePath, 'utf8')
      spyOn(fs, 'read').andCallThrough()
      expect(atom.grammars.selectGrammar(filePath, filePathContents).name).toBe "Ruby"
      expect(fs.read).not.toHaveBeenCalled()

    it "allows the default grammar to be overridden for a path", ->
      filePath = '/foo/bar/file.js'
      expect(atom.grammars.selectGrammar(filePath).name).not.toBe 'Ruby'
      atom.grammars.setGrammarOverrideForPath(filePath, 'source.ruby')
      expect(atom.grammars.selectGrammar(filePath).name).toBe 'Ruby'
      atom.grammars.clearGrammarOverrideForPath(filePath)
      expect(atom.grammars.selectGrammar(filePath).name).not.toBe 'Ruby'

    describe "when multiple grammars have matching fileTypes", ->
      it "selects the grammar with the longest fileType match", ->
        grammarPath1 = temp.path(suffix: '.json')
        fs.writeFileSync grammarPath1, JSON.stringify(
          name: 'test1'
          scopeName: 'source1'
          fileTypes: ['test']
        )
        grammar1 = atom.grammars.loadGrammarSync(grammarPath1)
        expect(atom.grammars.selectGrammar('more.test', '')).toBe grammar1

        grammarPath2 = temp.path(suffix: '.json')
        fs.writeFileSync grammarPath2, JSON.stringify(
          name: 'test2'
          scopeName: 'source2'
          fileTypes: ['test', 'more.test']
        )
        grammar2 = atom.grammars.loadGrammarSync(grammarPath2)
        expect(atom.grammars.selectGrammar('more.test', '')).toBe grammar2

    it "favors non-bundled packages when breaking scoring ties", ->
      waitsForPromise ->
        atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'packages', 'package-with-rb-filetype'))

      runs ->
        atom.grammars.grammarForScopeName('source.ruby').bundledPackage = true
        atom.grammars.grammarForScopeName('test.rb').bundledPackage = false

        expect(atom.grammars.selectGrammar('test.rb').scopeName).toBe 'test.rb'

    describe "when there is no file path", ->
      it "does not throw an exception (regression)", ->
        expect(-> atom.grammars.selectGrammar(null, '#!/usr/bin/ruby')).not.toThrow()
        expect(-> atom.grammars.selectGrammar(null, '')).not.toThrow()
        expect(-> atom.grammars.selectGrammar(null, null)).not.toThrow()

    describe "when the user has custom grammar file types", ->
      it "considers the custom file types as well as those defined in the grammar", ->
        atom.config.set('core.customFileTypes', 'source.ruby': ['Cheffile'])
        expect(atom.grammars.selectGrammar('build/Cheffile', 'cookbook "postgres"').scopeName).toBe 'source.ruby'

      it "favors user-defined file types over built-in ones of equal length", ->
        atom.config.set('core.customFileTypes',
          'source.coffee': ['Rakefile'],
          'source.ruby': ['Cakefile']
        )
        expect(atom.grammars.selectGrammar('Rakefile', '').scopeName).toBe 'source.coffee'
        expect(atom.grammars.selectGrammar('Cakefile', '').scopeName).toBe 'source.ruby'

      it "favors grammars with matching first-line-regexps even if custom file types match the file", ->
        atom.config.set('core.customFileTypes', 'source.ruby': ['bootstrap'])
        expect(atom.grammars.selectGrammar('bootstrap', '#!/usr/bin/env node').scopeName).toBe 'source.js'

  describe ".removeGrammar(grammar)", ->
    it "removes the grammar, so it won't be returned by selectGrammar", ->
      grammar = atom.grammars.selectGrammar('foo.js')
      atom.grammars.removeGrammar(grammar)
      expect(atom.grammars.selectGrammar('foo.js').name).not.toBe grammar.name
