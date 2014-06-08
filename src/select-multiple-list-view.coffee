{$, $$, View} = require './space-pen-extensions'
SelectListView = require './select-list-view'

# Public: Provides a view that renders a list of items with an editor that
# filters the items. Enables you to select multiple items at once.
#
# Subclasses must implement the following methods:
#
# * {::viewForItem}
# * {::completed}
#
# Subclasses should implement the following methods:
#
# * {::addButtons}
#
# ## Requiring in packages
#
# ```coffee
# {SelectMultipleListView} = require 'atom'
#
# class MySelectListView extends SelectMultipleListView
#   initialize: ->
#     super
#     @addClass('overlay from-top')
#     @setItems(['Hello', 'World'])
#     atom.workspaceView.append(this)
#     @focusFilterEditor()
#
#   viewForItem: (item) ->
#     "<li>#{item}</li>"
#
#   completed: (items) ->
#     console.log("#{items} were selected")
# ```
module.exports =
class SelectMultipleListView extends SelectListView
  #
  # This method can be overridden by subclasses but `super` should always
  # be called.
  initialize: ->
    super
    @list.addClass('mark-active')

    @on 'mousedown', ({target}) =>
      false if target is @list[0] or $(target).hasClass('btn')

    @addButtons()

  # Public: Function to add buttons to the SelectMultipleListView.
  #
  # This method can be overridden by subclasses.
  #
  # ### Important
  #   There must always be a button to call the function `@complete()` to
  #   confirm the selections!
  #
  # #### Example (Default)
  # ```coffeee
  # addButtons: ->
  #     viewButton = $$ ->
  #       @div class: 'buttons', =>
  #         @span class: 'pull-left', =>
  #           @button class: 'btn btn-error inline-block-tight btn-cancel-button', 'Cancel'
  #         @span class: 'pull-right', =>
  #           @button class: 'btn btn-success inline-block-tight btn-complete-button', 'Confirm'
  #     viewButton.appendTo(this)
  #
  #     @on 'click', 'button', ({target}) =>
  #       @complete() if $(target).hasClass('btn-complete-button')
  #       @cancel() if $(target).hasClass('btn-cancel-button')
  # ```
  addButtons: ->
    viewButton = $$ ->
      @div class: 'buttons', =>
        @span class: 'pull-left', =>
          @button class: 'btn btn-error inline-block-tight btn-cancel-button', 'Cancel'
        @span class: 'pull-right', =>
          @button class: 'btn btn-success inline-block-tight btn-complete-button', 'Confirm'
    viewButton.appendTo(this)

    @on 'click', 'button', ({target}) =>
      @complete() if $(target).hasClass('btn-complete-button')
      @cancel() if $(target).hasClass('btn-cancel-button')

  confirmSelection: ->
    viewItem = @getSelectedItemView()
    if viewItem?
      @confirmed(viewItem)
    else
      @cancel()

  confirmed: (viewItem) ->
    if viewItem.hasClass('active')
      viewItem.removeClass('active')
    else
      viewItem.addClass('active')

  complete: ->
    items = ($.map $(this).find('li.active'), (el) -> $(el).data('select-list-item'))
    if items?
      @completed(items)
    else
      @cancel()

  # Public: Create a view for the given model item.
  #
  # This method must be overridden by subclasses.
  #
  # This is called when the item is about to appended to the list view.
  #
  # item - The model item being rendered. This will always be one of the items
  #        previously passed to {::setItems}.
  #
  # Returns a String of HTML, DOM element, jQuery object, or View.
  viewForItem: (item) ->
    throw new Error("Subclass must implement a viewForItem(item) method")

  # Public: Callback function for when the complete button is pressed.
  #
  # This method must be overridden by subclasses.
  #
  # items - An {Array} containing the selected items. This will always be one
  #         of the items previously passed to {::setItems}.
  #
  # Returns a DOM element, jQuery object, or {View}.
  completed: (items) ->
    throw new Error("Subclass must implement a completed(items) method")
