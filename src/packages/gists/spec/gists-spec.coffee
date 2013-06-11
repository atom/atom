RootView = require 'root-view'
gistUtils = require '../lib/gist-utils'

describe "Gists package", ->
  [editor] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    atom.activatePackage('gists')
    editor = rootView.getActiveView()
    spyOn(gistUtils, 'createGist')

  describe "when gist:create is triggered on an editor", ->
    describe "when the editor has no selection", ->
      [request, callback] = []

      beforeEach ->
        editor.trigger 'gist:create'
        expect(gistUtils.createGist).toHaveBeenCalled()
        request = gistUtils.createGist.argsForCall[0][0]
        callback = gistUtils.createGist.argsForCall[0][1]

      it "creates a Gist with the entire buffer contents as the Gist's content", ->
        expect(request.public).toBeFalsy()
        expect(request.files).toEqual 'sample.js': content: editor.getText()

      describe "when the server responds successfully", ->
        beforeEach ->
          callback(null, {html_url: 'https://gist.github.com/1', id: '1'})

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

      it "creates a request with the selected text as the Gist's content", ->
        editor.trigger 'gist:create'
        expect(gistUtils.createGist).toHaveBeenCalled()
        request = gistUtils.createGist.argsForCall[0][0]
        expect(request.files).toEqual 'sample.js': content: editor.getSelectedText()
