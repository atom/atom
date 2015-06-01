describe "TextEditorLoader", ->
  it "replaces itself with the editor being loaded once loading is complete", ->
    loader = null
    atom.project.largeFileThreshhold = 0
    waitsForPromise -> atom.workspace.open('sample.js').then (l) -> loader = l

    runs ->
      expect(atom.workspace.getActivePaneItem()).toBe(loader)

    waitsFor "text editor to load", (done) ->
      loader.editor.onDidLoad(done)

    runs ->
      expect(atom.workspace.getActivePane().getItems()).toEqual [loader.editor]
