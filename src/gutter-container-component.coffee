_ = require 'underscore-plus'
CustomGutterComponent = require './custom-gutter-component'
LineNumberGutterComponent = require './line-number-gutter-component'

# The GutterContainerComponent manages the GutterComponents of a particular
# TextEditorComponent.

module.exports =
class GutterContainerComponent
  constructor: ({@onLineNumberGutterMouseDown, @editor, @domElementPool, @views}) ->
    # An array of objects of the form: {name: {String}, component: {Object}}
    @gutterComponents = []
    @gutterComponentsByGutterName = {}
    @lineNumberGutterComponent = null

    @domNode = document.createElement('div')
    @domNode.classList.add('gutter-container')
    @domNode.style.display = 'flex'

  destroy: ->
    for {component} in @gutterComponents
      component.destroy?()
    return

  getDomNode: ->
    @domNode

  getLineNumberGutterComponent: ->
    @lineNumberGutterComponent

  updateSync: (state) ->
    # The GutterContainerComponent expects the gutters to be sorted in the order
    # they should appear.
    newState = state.gutters

    newGutterComponents = []
    newGutterComponentsByGutterName = {}
    for {gutter, visible, styles, content} in newState
      gutterComponent = @gutterComponentsByGutterName[gutter.name]
      if not gutterComponent
        if gutter.name is 'line-number'
          gutterComponent = new LineNumberGutterComponent({onMouseDown: @onLineNumberGutterMouseDown, @editor, gutter, @domElementPool, @views})
          @lineNumberGutterComponent = gutterComponent
        else
          gutterComponent = new CustomGutterComponent({gutter, @views})

      if visible then gutterComponent.showNode() else gutterComponent.hideNode()
      # Pass the gutter only the state that it needs.
      if gutter.name is 'line-number'
        # For ease of use in the line number gutter component, set the shared
        # 'styles' as a field under the 'content'.
        gutterSubstate = _.clone(content)
        gutterSubstate.styles = styles
      else
        # Custom gutter 'content' is keyed on gutter name, so we cannot set
        # 'styles' as a subfield directly under it.
        gutterSubstate = {content, styles}
      gutterComponent.updateSync(gutterSubstate)

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
          indexInOldGutters += 1

    # Remove any gutters that were not present in the new gutters state.
    for gutterComponentDescription in @gutterComponents
      if not newGutterComponentsByGutterName[gutterComponentDescription.name]
        gutterComponent = gutterComponentDescription.component
        gutterComponent.getDomNode().remove()
