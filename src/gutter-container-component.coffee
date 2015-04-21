CustomGutterComponent = require './custom-gutter-component'
LineNumberGutterComponent = require './line-number-gutter-component'

# The GutterContainerComponent manages the GutterComponents of a particular
# TextEditorComponent.

module.exports =
class GutterContainerComponent

  constructor: ({@onLineNumberGutterMouseDown, @editor}) ->
    # An array of objects of the form: {name: {String}, component: {Object}}
    @gutterComponents = []
    @gutterComponentsByGutterName = {}
    @lineNumberGutterComponent = null

    @domNode = document.createElement('div')
    @domNode.classList.add('gutter-container')
    @domNode.style.display = 'flex';

  getDomNode: ->
    @domNode

  getLineNumberGutterComponent: ->
    @lineNumberGutterComponent

  updateSync: (state) ->
    # The GutterContainerComponent expects the gutters to be sorted in the order
    # they should appear.
    newState = state.gutters.sortedDescriptions

    newGutterComponents = []
    newGutterComponentsByGutterName = {}
    for {gutter, visible} in newState
      gutterComponent = @gutterComponentsByGutterName[gutter.name]
      if not gutterComponent
        if gutter.name is 'line-number'
          gutterComponent = new LineNumberGutterComponent({onMouseDown: @onLineNumberGutterMouseDown, @editor, gutter})
          @lineNumberGutterComponent = gutterComponent
        else
          gutterComponent = new CustomGutterComponent({gutter})
      if visible then gutterComponent.showNode() else gutterComponent.hideNode()
      gutterComponent.updateSync(state)
      newGutterComponents.push({
        name: gutter.name,
        component: gutterComponent,
      })
      newGutterComponentsByGutterName[gutter.name] = gutterComponent

    @reorderGutters(newGutterComponents, newGutterComponentsByGutterName)

    @gutterComponents = newGutterComponents
    @gutterComponentsByGutterName = newGutterComponentsByGutterName

  ###
  Section: Private Methods
  ###

  reorderGutters: (newGutterComponents, newGutterComponentsByGutterName) ->
    # First, insert new gutters into the DOM.
    indexInOldGutters = 0
    oldGuttersLength = @gutterComponents.length

    for gutterComponentDescription in newGutterComponents
      gutterComponent = gutterComponentDescription.component
      gutterName = gutterComponentDescription.name

      if @gutterComponentsByGutterName[gutterName]
        # If the gutter existed previously, we first try to move the cursor to
        # the point at which it occurs in the previous gutters.
        matchingGutterFound = false
        while indexInOldGutters < oldGuttersLength
          existingGutterComponentDescription = @gutterComponents[indexInOldGutters]
          existingGutterComponent = existingGutterComponentDescription.component
          indexInOldGutters++
          if existingGutterComponent is gutterComponent
            matchingGutterFound = true
            break
        if not matchingGutterFound
          # If we've reached this point, the gutter previously existed, but its
          # position has moved. Remove it from the DOM and re-insert it.
          gutterComponent.getDomNode().remove()
          @domNode.appendChild(gutterComponent.getDomNode())

      else
        if indexInOldGutters is oldGuttersLength
          @domNode.appendChild(gutterComponent.getDomNode())
        else
          @domNode.insertBefore(gutterComponent.getDomNode(), @domNode.children[indexInOldGutters])

    # Remove any gutters that were not present in the new gutters state.
    for gutterComponentDescription in @gutterComponents
      if not newGutterComponentsByGutterName[gutterComponentDescription.name]
        gutterComponent = gutterComponentDescription.component
        gutterComponent.getDomNode().remove()
