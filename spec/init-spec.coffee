path = require 'path'
temp = require 'temp'
CSON = require 'season'
apm = require '../lib/apm-cli'
fs = require '../lib/fs'

describe "apm init", ->
  [packagePath, themePath] = []

  beforeEach ->
    # silenceOutput()
    spyOnToken()

    currentDir = temp.mkdirSync('apm-init-')
    spyOn(process, 'cwd').andReturn(currentDir)
    packagePath = path.join(currentDir, 'fake-package')
    themePath = path.join(currentDir, 'fake-theme')

  describe "when creating a package", ->
    it "generates the proper file structure", ->
      callback = jasmine.createSpy('callback')
      apm.run(['init', '--package', 'fake-package'], callback)

      waitsFor 'waiting for init to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(packagePath)).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'keymaps'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'keymaps', 'fake-package.cson'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'lib'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'lib', 'fake-package-view.coffee'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'lib', 'fake-package.coffee'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'menus'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'menus', 'fake-package.cson'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'spec', 'fake-package-view-spec.coffee'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'spec', 'fake-package-spec.coffee'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'stylesheets', 'fake-package.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'package.json'))).toBeTruthy()

    describe "when converting a TextMate bundle", ->
      it "generates the proper file structure", ->
        callback = jasmine.createSpy('callback')
        textMateBundlePath = path.join(__dirname, 'fixtures', 'r.tmbundle')
        apm.run(['init', '--package', 'fake-package', '--convert', textMateBundlePath], callback)

        waitsFor 'waiting for init to complete', ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(packagePath)).toBeTruthy()
          expect(fs.isFileSync(path.join(packagePath, 'scoped-properties', 'fake-package.cson'))).toBe true
          expect(fs.isFileSync(path.join(packagePath, 'snippets', 'fake-package.cson'))).toBe true
          expect(fs.isFileSync(path.join(packagePath, 'grammars', 'r.cson'))).toBe true
          expect(fs.existsSync(path.join(packagePath, 'command'))).toBeFalsy()
          expect(fs.existsSync(path.join(packagePath, 'README.md'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'package.json'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'LICENSE.md'))).toBeFalsy()
          expect(CSON.readFileSync(path.join(packagePath, 'snippets', 'fake-package.cson'))['.source.rd.tm']['Attach']).toEqual {
            body: 'attach($1) *outlet'
            prefix: 'att'
          }

  describe "when creating a theme", ->
    it "generates the proper file structure", ->
      callback = jasmine.createSpy('callback')
      apm.run(['init', '--theme', 'fake-theme'], callback)

      waitsFor 'waiting for init to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(themePath)).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'stylesheets'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'stylesheets', 'base.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'stylesheets', 'syntax-variables.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'index.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'README.md'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'package.json'))).toBeTruthy()

    describe "when converting a TextMate theme", ->
      it "generates the proper file structure", ->
        callback = jasmine.createSpy('callback')
        textMateThemePath = path.join(__dirname, 'fixtures', 'Dawn.tmTheme')
        apm.run(['init', '--theme', 'fake-theme', '--convert', textMateThemePath], callback)

        waitsFor 'waiting for init to complete', ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(themePath)).toBeTruthy()
          expect(fs.existsSync(path.join(themePath, 'stylesheets'))).toBeTruthy()
          expect(fs.readFileSync(path.join(themePath, 'stylesheets', 'syntax-variables.less'), 'utf8')).toContain """
            @syntax-gutter-text-color: #080808;
            @syntax-gutter-text-color-selected: #080808;
            @syntax-gutter-background-color: #F5F5F5;
            @syntax-gutter-background-color-selected: rgba(92, 108, 125, 0.07);
          """
          expect(fs.readFileSync(path.join(themePath, 'stylesheets', 'base.less'), 'utf8')).toContain """
            @import "syntax-variables";

            .editor {
              background-color: @syntax-background-color;
              color: @syntax-text-color;
            }

            .editor .gutter {
              background-color: @syntax-gutter-background-color;
              color: @syntax-gutter-text-color;
            }
          """
          expect(fs.existsSync(path.join(themePath, 'README.md'))).toBeTruthy()
          expect(fs.existsSync(path.join(themePath, 'package.json'))).toBeTruthy()
          expect(fs.existsSync(path.join(themePath, 'LICENSE.md'))).toBeFalsy()
