RootView = require 'root-view'
$ = require 'jquery'

describe "Gists package", ->

  [rootView, editor] = []

  beforeEach ->
    rootView = new RootView(fixturesProject.resolve('sample.js'))
    atom.loadPackage('gists')
    editor = rootView.getActiveEditor()
    spyOn($, 'ajax')

  afterEach ->
    rootView.deactivate()

  describe "when gist:create is triggered on an editor", ->

    describe "when the editor has no selection", ->
      it "creates an Ajax request to api.github.com with the entire buffer contents as the Gist's content", ->
        editor.trigger 'gist:create'
        expect($.ajax).toHaveBeenCalled()
        request = $.ajax.argsForCall[0][0]
        expect(request.url).toBe 'https://api.github.com/gists'
        expect(request.type).toBe 'POST'
        requestData = JSON.parse(request.data)
        expect(requestData.public).toBeFalsy()
        expect(requestData.files).toEqual 'sample.js': content: editor.getText()

      it "places the created Gist's URL on the clipboard", ->
        editor.trigger 'gist:create'
        request = $.ajax.argsForCall[0][0]
        request.success(html_url: 'https://gist.github.com/1')
        expect(pasteboard.read()[0]).toBe 'https://gist.github.com/1'

    describe "when the editor has a selection", ->
      beforeEach ->
        editor.setSelectedBufferRange [[4, 0], [8, 0]]

      it "creates an Ajax with the selected text as the Gist's content", ->
        editor.trigger 'gist:create'
        expect($.ajax).toHaveBeenCalled()
        request = $.ajax.argsForCall[0][0]
        requestData = JSON.parse(request.data)
        expect(requestData.files).toEqual 'sample.js': content: editor.getSelectedText()
