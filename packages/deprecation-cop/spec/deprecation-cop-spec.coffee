DeprecationCopView = require '../lib/deprecation-cop-view'

describe "DeprecationCop", ->
  [activationPromise, workspaceElement] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('deprecation-cop')
    expect(atom.workspace.getActivePane().getActiveItem()).not.toExist()

  describe "when the deprecation-cop:view event is triggered", ->
    it "displays the deprecation cop pane", ->
      atom.commands.dispatch workspaceElement, 'deprecation-cop:view'

      waitsForPromise ->
        activationPromise

      deprecationCopView = null
      waitsFor ->
        deprecationCopView = atom.workspace.getActivePane().getActiveItem()

      runs ->
        expect(deprecationCopView instanceof DeprecationCopView).toBeTruthy()

  describe "deactivating the package", ->
    it "removes the deprecation cop pane item", ->
      atom.commands.dispatch workspaceElement, 'deprecation-cop:view'

      waitsForPromise ->
        activationPromise

      waitsForPromise ->
        Promise.resolve(atom.packages.deactivatePackage('deprecation-cop')) # Wrapped for Promise & non-Promise deactivate

      runs ->
        expect(atom.workspace.getActivePane().getActiveItem()).not.toExist()
