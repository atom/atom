SelectList = require 'select-list'
{$$} = require 'space-pen'
$ = require 'jquery'

fdescribe "SelectList", ->
  [selectList, array, list, miniEditor] = []

  beforeEach ->
    array = [
      ["A", "Alpha"], ["B", "Bravo"], ["C", "Charlie"],
      ["D", "Delta"], ["E", "Echo"], ["F", "Foxtrot"]
    ]

    selectList = new SelectList
    selectList.maxItems = 4
    selectList.filterKey = 1
    selectList.itemForElement = (element) ->
      $$ -> @li element[1], class: element[0]

    selectList.setArray(array)
    {list, miniEditor} = selectList

  describe "when an array is assigned", ->
    it "populates the list with up to maxItems items, based on the liForElement function", ->
      expect(list.find('li').length).toBe selectList.maxItems
      expect(list.find('li:eq(0)')).toHaveText 'Alpha'
      expect(list.find('li:eq(0)')).toHaveClass 'A'

  describe "when the text of the mini editor changes", ->
    it "filters the elements in the list based on the scoreElement function", ->
      miniEditor.insertText('la')
      expect(list.find('li').length).toBe 2
      expect(list.find('li:contains(Alpha)')).toExist()
      expect(list.find('li:contains(Delta)')).toExist()

  describe "when move-up / move-down are triggered on the miniEditor", ->
    it "selects the previous / next item in the list, if there is one", ->
      expect(list.find('li:first')).toHaveClass 'selected'

      miniEditor.trigger 'move-up'

      expect(list.find('li:first')).toHaveClass 'selected'

      miniEditor.trigger 'move-down'

      expect(list.find('li:eq(0)')).not.toHaveClass 'selected'
      expect(list.find('li:eq(1)')).toHaveClass 'selected'

      miniEditor.trigger 'move-down'

      expect(list.find('li:eq(1)')).not.toHaveClass 'selected'
      expect(list.find('li:eq(2)')).toHaveClass 'selected'

      miniEditor.trigger 'move-up'

      expect(list.find('li:eq(2)')).not.toHaveClass 'selected'
      expect(list.find('li:eq(1)')).toHaveClass 'selected'

    it "scrolls to keep the selected item in view", ->
      selectList.attachToDom()
      itemHeight = list.find('li').outerHeight()
      list.height(itemHeight * 2)

      miniEditor.trigger 'move-down'
      miniEditor.trigger 'move-down'
      expect(list.scrollBottom()).toBe itemHeight * 3

      miniEditor.trigger 'move-down'
      expect(list.scrollBottom()).toBe itemHeight * 4

      miniEditor.trigger 'move-up'
      miniEditor.trigger 'move-up'
      expect(list.scrollBottom()).toBe itemHeight * 3

  describe "the core:select event", ->
    it "triggers the selected hook", ->

  describe "the core:cancel event", ->
    it "triggers the cancelled hook", ->






