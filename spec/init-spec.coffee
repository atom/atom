path = require 'path'
temp = require 'temp'

apm = require '../lib/apm-cli'
fs = require '../lib/fs'

describe "apm init", ->
  [packagePath, themePath] = []

  beforeEach ->
    silenceOutput()
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
          expect(fs.isFileSync(path.join(packagePath, 'preferences', 'comments.json'))).toBe true
          expect(fs.isFileSync(path.join(packagePath, 'snippets', 'density.json'))).toBe true
          expect(fs.isFileSync(path.join(packagePath, 'syntaxes', 'r.json'))).toBe true
          expect(fs.existsSync(path.join(packagePath, 'command'))).toBeFalsy()
          expect(fs.existsSync(path.join(packagePath, 'README.md'))).toBeTruthy()
          expect(fs.existsSync(path.join(packagePath, 'package.json'))).toBeTruthy()

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
          expect(fs.existsSync(path.join(themePath, 'stylesheets'))).toBeFalsy()
          expect(fs.readFileSync(path.join(themePath, 'index.less'), 'utf8')).toContain """
            .editor, .editor .gutter {
              background-color: #F5F5F5;
              color: #080808;
            }
          """
          expect(fs.existsSync(path.join(themePath, 'README.md'))).toBeTruthy()
          expect(fs.existsSync(path.join(themePath, 'package.json'))).toBeTruthy()
