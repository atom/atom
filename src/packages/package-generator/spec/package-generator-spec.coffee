RootView = require 'root-view'
fs = require 'fs-utils'

describe 'Package Generator', ->
  [packageGenerator] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    window.loadPackage("package-generator")

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
      expect(rootView.getActiveView().isFocused).toBeFalsy()

      packageGeneratorView.trigger("core:cancel")
      expect(packageGeneratorView.hasParent()).toBeFalsy()
      expect(rootView.getActiveView().isFocused).toBeTruthy()

  describe "when a package is generated", ->
    [packageName, packagePath] = []

    beforeEach ->
      spyOn(atom, "open")

      packageName = "sweet-package-dude"
      packagePath = "/tmp/atom-packages/#{packageName}"
      fs.remove(packagePath) if fs.exists(packagePath)

    afterEach ->
      fs.remove(packagePath) if fs.exists(packagePath)

    it "forces the package's name to be lowercase with dashes", ->
      packageName = "CamelCaseIsForTheBirds"
      packagePath = fs.join(fs.directory(packagePath), packageName)
      rootView.trigger("package-generator:generate")
      packageGeneratorView = rootView.find(".package-generator").view()
      packageGeneratorView.miniEditor.setText(packagePath)
      packageGeneratorView.trigger "core:confirm"

      expect(packagePath).not.toExistOnDisk()
      expect(fs.join(fs.directory(packagePath), "camel-case-is-for-the-birds")).toExistOnDisk()

    it "correctly lays out the package files and closes the package generator view", ->
      rootView.attachToDom()
      rootView.trigger("package-generator:generate")
      packageGeneratorView = rootView.find(".package-generator").view()
      expect(packageGeneratorView.hasParent()).toBeTruthy()
      packageGeneratorView.miniEditor.setText(packagePath)
      packageGeneratorView.trigger "core:confirm"

      expect("#{packagePath}/package.cson").toExistOnDisk()
      expect("#{packagePath}/lib/#{packageName}.coffee").toExistOnDisk()
      expect("#{packagePath}/lib/#{packageName}-view.coffee").toExistOnDisk()
      expect("#{packagePath}/spec/#{packageName}-spec.coffee").toExistOnDisk()
      expect("#{packagePath}/spec/#{packageName}-view-spec.coffee").toExistOnDisk()
      expect("#{packagePath}/keymaps/#{packageName}.cson").toExistOnDisk()
      expect("#{packagePath}/stylesheets/#{packageName}.css").toExistOnDisk()

      expect(packageGeneratorView.hasParent()).toBeFalsy()
      expect(rootView.getActiveView().isFocused).toBeTruthy()

    it "replaces instances of packageName placeholders in template files", ->
      rootView.trigger("package-generator:generate")
      packageGeneratorView = rootView.find(".package-generator").view()
      expect(packageGeneratorView.hasParent()).toBeTruthy()
      packageGeneratorView.miniEditor.setText(packagePath)
      packageGeneratorView.trigger "core:confirm"

      lines = fs.read("#{packagePath}/package.cson").split("\n")
      expect(lines[0]).toBe "'main': 'lib\/#{packageName}'"

      lines = fs.read("#{packagePath}/lib/#{packageName}.coffee").split("\n")
      expect(lines[0]).toBe "SweetPackageDudeView = require 'sweet-package-dude/lib/sweet-package-dude-view'"
      expect(lines[3]).toBe "  sweetPackageDudeView: null"

    it "displays an error when the package path already exists", ->
      rootView.attachToDom()
      fs.makeTree(packagePath)
      rootView.trigger("package-generator:generate")
      packageGeneratorView = rootView.find(".package-generator").view()

      expect(packageGeneratorView.hasParent()).toBeTruthy()
      expect(packageGeneratorView.error).not.toBeVisible()
      packageGeneratorView.miniEditor.setText(packagePath)
      packageGeneratorView.trigger "core:confirm"
      expect(packageGeneratorView.hasParent()).toBeTruthy()
      expect(packageGeneratorView.error).toBeVisible()

    it "opens the package", ->
      rootView.trigger("package-generator:generate")
      packageGeneratorView = rootView.find(".package-generator").view()
      packageGeneratorView.miniEditor.setText(packagePath)
      packageGeneratorView.trigger "core:confirm"

      expect(atom.open).toHaveBeenCalledWith(packagePath)
