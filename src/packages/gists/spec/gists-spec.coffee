RootView = require 'root-view'
$ = require 'jquery'

describe "Gists package", ->
  [editor] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    window.loadPackage('gists')
    editor = rootView.getActiveView()
    spyOn($, 'ajax')

  describe "when gist:create is triggered on an editor", ->

    describe "when the editor has no selection", ->
      [request, originalFxOffValue] = []

      beforeEach ->
        editor.trigger 'gist:create'
        expect($.ajax).toHaveBeenCalled()
        request = $.ajax.argsForCall[0][0]

      it "creates an Ajax request to api.github.com with the entire buffer contents as the Gist's content", ->
        expect(request.url).toBe 'https://api.github.com/gists'
        expect(request.type).toBe 'POST'
        requestData = JSON.parse(request.data)
        expect(requestData.public).toBeFalsy()
        expect(requestData.files).toEqual 'sample.js': content: editor.getText()

      describe "when the server responds successfully", ->
        beforeEach ->
          request.success(html_url: 'https://gist.github.com/1', id: '1')

        it "places the created Gist's URL on the clipboard", ->
          expect(pasteboard.read()[0]).toBe 'https://gist.github.com/1'

        it "flashes that the Gist was created", ->
          expect(rootView.find('.notification')).toExist()
          expect(rootView.find('.notification .title').text()).toBe 'Gist 1 created'
          advanceClock(2000)
          expect(rootView.find('.notification')).not.toExist()

    describe "when the editor has a selection", ->
      beforeEach ->
        editor.setSelectedBufferRange [[4, 0], [8, 0]]

      it "creates an Ajax with the selected text as the Gist's content", ->
        editor.trigger 'gist:create'
        expect($.ajax).toHaveBeenCalled()
        request = $.ajax.argsForCall[0][0]
        requestData = JSON.parse(request.data)
        expect(requestData.files).toEqual 'sample.js': content: editor.getSelectedText()
