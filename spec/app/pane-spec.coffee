Editor = require 'editor'
Pane = require 'pane'
{$$} = require 'space-pen'

describe "Pane", ->
  [view1, view2, editSession1, editSession2, pane] = []

  beforeEach ->
    view1 = $$ -> @div id: 'view-1', 'View 1'
    view2 = $$ -> @div id: 'view-2', 'View 2'
    editSession1 = project.buildEditSession('sample.js')
    editSession2 = project.buildEditSession('sample.txt')
    pane = new Pane(view1, editSession1, view2, editSession2)

  describe ".initialize(items...)", ->
    it "displays the first item in the pane", ->
      expect(pane.itemViews.find('#view-1')).toExist()

  describe ".showItem(item)", ->
    it "hides all item views except the one being shown and sets the currentItem", ->
      expect(pane.currentItem).toBe view1
      pane.showItem(view2)
      expect(view1.css('display')).toBe 'none'
      expect(view2.css('display')).toBe ''
      expect(pane.currentItem).toBe view2

    describe "when showing a model item", ->
      describe "when no view has yet been appended for that item", ->
        it "appends and shows a view to display the item based on its `.getViewClass` method", ->
          pane.showItem(editSession1)
          editor = pane.itemViews.find('.editor').view()
          expect(editor.activeEditSession).toBe editSession1

      describe "when a valid view has already been appended for another item", ->
        it "recycles the existing view by assigning the selected item to it", ->
          pane.showItem(editSession1)
          pane.showItem(editSession2)
          expect(pane.itemViews.find('.editor').length).toBe 1
          editor = pane.itemViews.find('.editor').view()
          expect(editor.activeEditSession).toBe editSession2

    describe "when showing a view item", ->
      it "appends it to the itemViews div if it hasn't already been appended and show it", ->
        expect(pane.itemViews.find('#view-2')).not.toExist()
        pane.showItem(view2)
        expect(pane.itemViews.find('#view-2')).toExist()

  describe "pane:show-next-item and pane:show-preview-item", ->
    it "advances forward/backward through the pane's items, looping around at either end", ->
      expect(pane.currentItem).toBe view1
      pane.trigger 'pane:show-previous-item'
      expect(pane.currentItem).toBe editSession2
      pane.trigger 'pane:show-previous-item'
      expect(pane.currentItem).toBe view2
      pane.trigger 'pane:show-next-item'
      expect(pane.currentItem).toBe editSession2
      pane.trigger 'pane:show-next-item'
      expect(pane.currentItem).toBe view1
