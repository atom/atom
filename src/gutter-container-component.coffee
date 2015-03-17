LineNumberGutterComponent = require './line-number-gutter-component'

# The GutterContainerComponent manages the GutterComponents of a particular
# TextEditorComponent.

module.exports =
class GutterContainerComponent

  constructor: ({@onLineNumberGutterMouseDown, @editor}) ->
    @gutterComponents = []
    @gutterComponentsByGutterName = {}
    @lineNumberGutterComponent = null

    @domNode = document.createElement('div')
    @domNode.classList.add('gutter-container')

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
    for gutter in newState
      gutterComponent = @gutterComponentsByGutterName[gutter.name]
      if !gutterComponent
        if gutter.name is 'line-number'
          gutterComponent = new LineNumberGutterComponent({onMouseDown: @onLineNumberGutterMouseDown, @editor, name: gutter.name})
          @lineNumberGutterComponent = gutterComponent
        else
          # TODO (jessicalin) Implement non-line-number gutters.
          continue
      newGutterComponents.push(gutterComponent)
      newGutterComponentsByGutterName[gutter.name] = gutterComponent

    @updateChildGutters(state, newGutterComponents, newGutterComponentsByGutterName)

    @gutterComponents = newGutterComponents
    @gutterComponentsByGutterName = newGutterComponentsByGutterName

  ###
  Section: Private Methods
  ###

  updateChildGutters: (state, newGutterComponents, newGutterComponentsByGutterName) ->
    # First, insert new gutters into the DOM.
    indexInOldGutters = 0
    oldGuttersLength = @gutterComponents.length
    for gutterComponent in newGutterComponents
      gutterComponent.updateSync(state)
      if @gutterComponentsByGutterName[gutterComponent.getName()]
        # If the gutter existed previously, we first try to move the cursor to
        # the point at which it occurs in the previous gutters.
        matchingGutterFound = false
        while indexInOldGutters < oldGuttersLength
          existingGutterComponent = @gutterComponents[indexInOldGutters]
          indexInOldGutters++
          if existingGutterComponent.getName() == gutterComponent.getName()
            matchingGutterFound = true
            break
        if !matchingGutterFound
          # If we've reached this point, the gutter previously existed, but its
          # position has moved. Remove it from the DOM and re-insert it.
          gutterComponent.getDomNode().remove()
          @domNode.appendChild(gutterComponent.getDomNode())

      else
        if indexInOldGutters == oldGuttersLength
          @domNode.appendChild(gutterComponent.getDomNode())
        else
          @domNode.insertBefore(gutterComponent.getDomNode(), @domNode.children[indexInOldGutters])

    # Remove any gutters that were not present in the new gutters state.
    for gutterComponent in @gutterComponents
      if !newGutterComponentsByGutterName[gutterComponent.getName()]
        gutterComponent.getDomNode().remove()
