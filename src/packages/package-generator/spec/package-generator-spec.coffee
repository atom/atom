RootView = require 'root-view'
fs = require 'fs'

describe 'Package Generator', ->
  [packageGenerator] = []

  beforeEach ->
    new RootView(require.resolve('fixtures/sample.js'))
    atom.loadPackage("package-generator")

  afterEach ->
    rootView.deactivate()

  describe "when package-generator:generate is triggered", ->
    it "displays a miniEditor", ->
      rootView.trigger("package-generator:generate")
      packageGeneratorView = rootView.find(".package-generator")
      expect(packageGeneratorView).toExist()

  describe "when core:cancel is triggered", ->
    it "detaches from the DOM and focuses the the previously focused element", ->
      rootView.attachToDom()
      rootView.trigger("package-generator:generate")
      packageGeneratorView = rootView.find(".package-generator").view()
      expect(packageGeneratorView.miniEditor.isFocused).toBeTruthy()
      expect(rootView.getActiveEditor().isFocused).toBeFalsy()

      packageGeneratorView.trigger("core:cancel")
      expect(packageGeneratorView.hasParent()).toBeFalsy()
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

  describe "when a package is generated", ->
    [packageName, packagePath] = []

    beforeEach ->
      spyOn(atom, "open")

      packageName = "sweet-package-dude"
      packagePath = "/tmp/atom-packages/#{packageName}"
      fs.remove(packagePath) if fs.exists(packagePath)

      @addMatchers
        toExistOnDisk: (expected) ->
          notText = this.isNot and " not" or ""
          @message = -> return "Expected path '" + @actual + notText + "' to exist."
          fs.exists(@actual)

    afterEach ->
      fs.remove(packagePath) if fs.exists(packagePath)

    it "correctly lays out the package files and closes the package generator view", ->
      rootView.trigger("package-generator:generate")
      packageGeneratorView = rootView.find(".package-generator").view()
      expect(packageGeneratorView.hasParent()).toBeTruthy()
      packageGeneratorView.miniEditor.setText(packagePath)
      packageGeneratorView.miniEditor.trigger "core:confirm"

      expect("#{packagePath}/package.cson").toExistOnDisk()
      expect("#{packagePath}/lib/#{packageName}.coffee").toExistOnDisk()
      expect("#{packagePath}/lib/#{packageName}-view.coffee").toExistOnDisk()
      expect("#{packagePath}/spec/#{packageName}-spec.coffee").toExistOnDisk()
      expect("#{packagePath}/spec/#{packageName}-view-spec.coffee").toExistOnDisk()
      expect("#{packagePath}/keymaps/#{packageName}.cson").toExistOnDisk()
      expect("#{packagePath}/stylesheets/#{packageName}.css").toExistOnDisk()

      expect(packageGeneratorView.hasParent()).toBeFalsy()
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

    it "displays an error when the package path already exists", ->
      rootView.attachToDom()
      fs.makeTree(packagePath)
      rootView.trigger("package-generator:generate")
      packageGeneratorView = rootView.find(".package-generator").view()

      expect(packageGeneratorView.hasParent()).toBeTruthy()
      expect(packageGeneratorView.error).not.toBeVisible()
      packageGeneratorView.miniEditor.setText(packagePath)
      packageGeneratorView.miniEditor.trigger "core:confirm"
      expect(packageGeneratorView.hasParent()).toBeTruthy()
      expect(packageGeneratorView.error).toBeVisible()

    it "opens the package", ->
      rootView.trigger("package-generator:generate")
      packageGeneratorView = rootView.find(".package-generator").view()
      packageGeneratorView.miniEditor.setText(packagePath)
      packageGeneratorView.trigger "core:confirm"

      expect(atom.open).toHaveBeenCalledWith(packagePath)


