RootView = require 'root-view'
fsUtils = require 'fs-utils'

describe "Archive viewer", ->
  beforeEach ->
    window.rootView = new RootView
    atom.activatePackage('archive-view', sync: true)

  describe ".initialize()", ->
    it "displays the files and folders in the archive file", ->
      rootView.open('nested.tar')

      archiveView = rootView.find('.archive-view')
      expect(rootView.find('.archive-view')).toExist()

      waitsFor -> archiveView.find('.entry').length > 0

      runs ->
        expect(archiveView.find('.directory').length).toBe 6
        expect(archiveView.find('.directory:eq(0)').text()).toBe 'd1'
        expect(archiveView.find('.directory:eq(1)').text()).toBe 'd2'
        expect(archiveView.find('.directory:eq(2)').text()).toBe 'd3'
        expect(archiveView.find('.directory:eq(3)').text()).toBe 'd4'
        expect(archiveView.find('.directory:eq(4)').text()).toBe 'da'
        expect(archiveView.find('.directory:eq(5)').text()).toBe 'db'

        expect(archiveView.find('.file').length).toBe 3
        expect(archiveView.find('.file:eq(0)').text()).toBe 'f1.txt'
        expect(archiveView.find('.file:eq(1)').text()).toBe 'f2.txt'
        expect(archiveView.find('.file:eq(2)').text()).toBe 'fa.txt'

    it "selects the first file", ->
      rootView.open('nested.tar')

      archiveView = rootView.find('.archive-view')
      waitsFor -> archiveView.find('.entry').length > 0
      runs -> expect(archiveView.find('.selected').text()).toBe 'f1.txt'

  describe "when core:move-up/core:move-down is triggered", ->
    it "selects the next/previous file", ->
      rootView.open('nested.tar')

      archiveView = rootView.find('.archive-view')

      waitsFor -> archiveView.find('.entry').length > 0

      runs ->
        archiveView.find('.selected').trigger 'core:move-up'
        expect(archiveView.find('.selected').text()).toBe 'f1.txt'
        archiveView.find('.selected').trigger 'core:move-down'
        expect(archiveView.find('.selected').text()).toBe 'f2.txt'
        archiveView.find('.selected').trigger 'core:move-down'
        expect(archiveView.find('.selected').text()).toBe 'fa.txt'
        archiveView.find('.selected').trigger 'core:move-down'
        expect(archiveView.find('.selected').text()).toBe 'fa.txt'
        archiveView.find('.selected').trigger 'core:move-up'
        expect(archiveView.find('.selected').text()).toBe 'f2.txt'
        archiveView.find('.selected').trigger 'core:move-up'
        expect(archiveView.find('.selected').text()).toBe 'f1.txt'

  describe "when a file is clicked", ->
    it "copies the contents to a temp file and opens it in a new editor", ->
      rootView.open('nested.tar')

      archiveView = rootView.find('.archive-view')

      waitsFor -> archiveView.find('.entry').length > 0

      runs ->
        spyOn(rootView, 'open').andCallThrough()
        archiveView.find('.file:eq(2)').trigger 'click'
        waitsFor -> rootView.open.callCount is 1
        runs ->
          expect(rootView.getActiveView().getText()).toBe 'hey there\n'
          expect(rootView.getActivePaneItem().getTitle()).toBe 'fa.txt'

  describe "when core:confirm is triggered", ->
    it "copies the contents to a temp file and opens it in a new editor", ->
      rootView.open('nested.tar')

      archiveView = rootView.find('.archive-view')

      waitsFor -> archiveView.find('.entry').length > 0

      runs ->
        spyOn(rootView, 'open').andCallThrough()
        archiveView.find('.file:eq(0)').trigger 'core:confirm'
        waitsFor -> rootView.open.callCount is 1
        runs ->
          expect(rootView.getActiveView().getText()).toBe ''
          expect(rootView.getActivePaneItem().getTitle()).toBe 'f1.txt'

  describe "when the file is removed", ->
    it "destroys the view", ->
      rootView.open('nested.tar')

      archiveView = rootView.find('.archive-view')

      waitsFor -> archiveView.find('.entry').length > 0

      runs ->
        expect(rootView.getActivePane().getItems().length).toBe 1
        rootView.getActivePaneItem().file.trigger('removed')
        expect(rootView.getActivePane()).toBeFalsy()

  describe "when the file is modified", ->
    it "refreshes the view", ->
      rootView.open('nested.tar')

      archiveView = rootView.find('.archive-view').view()

      waitsFor -> archiveView.find('.entry').length > 0

      runs ->
        spyOn(archiveView, 'refresh')
        rootView.getActivePaneItem().file.trigger('contents-changed')
        expect(archiveView.refresh).toHaveBeenCalled()
