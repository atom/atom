SelectListView = require '../src/select-list-view'
{$, $$} = require '../src/space-pen-extensions'

describe "SelectListView", ->
  [selectList, items, list, filterEditorView] = []

  beforeEach ->
    items = [
      ["A", "Alpha"], ["B", "Bravo"], ["C", "Charlie"],
      ["D", "Delta"], ["E", "Echo"], ["F", "Foxtrot"]
    ]

    selectList = new SelectListView
    selectList.setMaxItems(4)
    selectList.getFilterKey = -> 1
    selectList.viewForItem = (item) ->
      $$ -> @li item[1], class: item[0]

    selectList.confirmed = jasmine.createSpy('confirmed hook')
    selectList.cancelled = jasmine.createSpy('cancelled hook')

    selectList.setItems(items)
    {list, filterEditorView} = selectList

  describe "when an array is assigned", ->
    it "populates the list with up to maxItems items, based on the liForElement function", ->
      expect(list.find('li').length).toBe selectList.maxItems
      expect(list.find('li:eq(0)')).toHaveText 'Alpha'
      expect(list.find('li:eq(0)')).toHaveClass 'A'

  describe "viewForItem(item)", ->
    it "allows raw DOM elements to be returned", ->
      selectList.viewForItem = (item) ->
        li = document.createElement('li')
        li.classList.add(item[0])
        li.innerText = item[1]
        li

      selectList.setItems(items)

      expect(list.find('li').length).toBe selectList.maxItems
      expect(list.find('li:eq(0)')).toHaveText 'Alpha'
      expect(list.find('li:eq(0)')).toHaveClass 'A'
      expect(selectList.getSelectedItem()).toBe items[0]

    it "allows raw HTML to be returned", ->
      selectList.viewForItem = (item) ->
        "<li>#{item}</li>"

      selectList.setItems(['Bermuda', 'Bahama'])

      expect(list.find('li:eq(0)')).toHaveText 'Bermuda'
      expect(selectList.getSelectedItem()).toBe 'Bermuda'

  describe "when the text of the mini editor changes", ->
    beforeEach ->
      selectList.attachToDom()

    it "filters the elements in the list based on the scoreElement function and selects the first item", ->
      filterEditorView.getEditor().insertText('la')
      window.advanceClock(selectList.inputThrottle)

      expect(list.find('li').length).toBe 2
      expect(list.find('li:contains(Alpha)')).toExist()
      expect(list.find('li:contains(Delta)')).toExist()
      expect(list.find('li:first')).toHaveClass 'selected'
      expect(selectList.error).not.toBeVisible()

    it "displays an error if there are no matches, removes error when there are matches", ->
      filterEditorView.getEditor().insertText('nothing will match this')
      window.advanceClock(selectList.inputThrottle)

      expect(list.find('li').length).toBe 0
      expect(selectList.error).not.toBeHidden()

      filterEditorView.getEditor().setText('la')
      window.advanceClock(selectList.inputThrottle)

      expect(list.find('li').length).toBe 2
      expect(selectList.error).not.toBeVisible()

    it "displays no elements until the array has been set on the list", ->
      selectList.items = null
      selectList.list.empty()
      filterEditorView.getEditor().insertText('la')
      window.advanceClock(selectList.inputThrottle)

      expect(list.find('li').length).toBe 0
      expect(selectList.error).toBeHidden()
      selectList.setItems(items)
      expect(list.find('li').length).toBe 2

  describe "when core:move-up / core:move-down are triggered on the filterEditorView", ->
    it "selects the previous / next item in the list, or wraps around to the other side", ->
      expect(list.find('li:first')).toHaveClass 'selected'

      filterEditorView.trigger 'core:move-up'

      expect(list.find('li:first')).not.toHaveClass 'selected'
      expect(list.find('li:last')).toHaveClass 'selected'

      filterEditorView.trigger 'core:move-down'

      expect(list.find('li:first')).toHaveClass 'selected'
      expect(list.find('li:last')).not.toHaveClass 'selected'

      filterEditorView.trigger 'core:move-down'

      expect(list.find('li:eq(0)')).not.toHaveClass 'selected'
      expect(list.find('li:eq(1)')).toHaveClass 'selected'

      filterEditorView.trigger 'core:move-down'

      expect(list.find('li:eq(1)')).not.toHaveClass 'selected'
      expect(list.find('li:eq(2)')).toHaveClass 'selected'

      filterEditorView.trigger 'core:move-up'

      expect(list.find('li:eq(2)')).not.toHaveClass 'selected'
      expect(list.find('li:eq(1)')).toHaveClass 'selected'

    it "scrolls to keep the selected item in view", ->
      selectList.attachToDom()
      itemHeight = list.find('li').outerHeight()
      list.height(itemHeight * 2)

      filterEditorView.trigger 'core:move-down'
      filterEditorView.trigger 'core:move-down'
      expect(list.scrollBottom()).toBe itemHeight * 3

      filterEditorView.trigger 'core:move-down'
      expect(list.scrollBottom()).toBe itemHeight * 4

      filterEditorView.trigger 'core:move-up'
      filterEditorView.trigger 'core:move-up'
      expect(list.scrollTop()).toBe itemHeight

  describe "the core:confirm event", ->
    describe "when there is an item selected (because the list in not empty)", ->
      it "triggers the selected hook with the selected array element", ->
        filterEditorView.trigger 'core:move-down'
        filterEditorView.trigger 'core:move-down'
        filterEditorView.trigger 'core:confirm'
        expect(selectList.confirmed).toHaveBeenCalledWith(items[2])

    describe "when there is no item selected (because the list is empty)", ->
      beforeEach ->
        selectList.attachToDom()

      it "does not trigger the confirmed hook", ->
        filterEditorView.getEditor().insertText("i will never match anything")
        window.advanceClock(selectList.inputThrottle)

        expect(list.find('li')).not.toExist()
        filterEditorView.trigger 'core:confirm'
        expect(selectList.confirmed).not.toHaveBeenCalled()

      it "does trigger the cancelled hook", ->
        filterEditorView.getEditor().insertText("i will never match anything")
        window.advanceClock(selectList.inputThrottle)

        expect(list.find('li')).not.toExist()
        filterEditorView.trigger 'core:confirm'
        expect(selectList.cancelled).toHaveBeenCalled()

  describe "when a list item is clicked", ->
    it "selects the item on mousedown and confirms it on mouseup", ->
      item = list.find('li:eq(1)')

      item.mousedown()
      expect(item).toHaveClass 'selected'
      item.mouseup()

      expect(selectList.confirmed).toHaveBeenCalledWith(items[1])

  describe "the core:cancel event", ->
    it "triggers the cancelled hook and detaches and empties the select list", ->
      spyOn(selectList, 'detach')
      filterEditorView.trigger 'core:cancel'
      expect(selectList.cancelled).toHaveBeenCalled()
      expect(selectList.detach).toHaveBeenCalled()
      expect(selectList.list).toBeEmpty()

  describe "when the mini editor loses focus", ->
    it "triggers the cancelled hook and detaches the select list", ->
      spyOn(selectList, 'detach')
      filterEditorView.trigger 'blur'
      expect(selectList.cancelled).toHaveBeenCalled()
      expect(selectList.detach).toHaveBeenCalled()

  describe "the core:move-to-top event", ->
    it "scrolls to the top, selects the first element, and does not bubble the event", ->
      selectList.attachToDom()
      moveToTopHandler = jasmine.createSpy("moveToTopHandler")
      selectList.parent().on 'core:move-to-top', moveToTopHandler

      selectList.trigger 'core:move-down'
      expect(list.find('li:eq(1)')).toHaveClass 'selected'
      selectList.trigger 'core:move-to-top'
      expect(list.find('li:first')).toHaveClass 'selected'
      expect(moveToTopHandler).not.toHaveBeenCalled()

  describe "the core:move-to-bottom event", ->
    it "scrolls to the bottom, selects the last element, and does not bubble the event", ->
      selectList.attachToDom()
      moveToBottomHandler = jasmine.createSpy("moveToBottomHandler")
      selectList.parent().on 'core:move-to-bottom', moveToBottomHandler

      expect(list.find('li:first')).toHaveClass 'selected'
      selectList.trigger 'core:move-to-bottom'
      expect(list.find('li:last')).toHaveClass 'selected'
      expect(moveToBottomHandler).not.toHaveBeenCalled()
