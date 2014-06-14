_ = require 'underscore-plus'
Decoration = require './decoration'

module.exports =
class Decorations
  constructor: (@editor, @startScreenRow, @endScreenRow) ->
    @decorationsCache = {}
    @decorationsByMarkerId = @editor.decorationsForScreenRowRange(@startScreenRow, @endScreenRow)
    @decorationsByScreenRow = @indexDecorationsByScreenRow(@decorationsByMarkerId)

  decorationsByScreenRowForType: (decorationType) ->
    unless @decorationsCache[decorationType]?
      filteredDecorations = {}

      for screenRow, decorations of @decorationsByScreenRow
        for decoration in decorations
          if decoration.isType(decorationType)
            filteredDecorations[screenRow] ?= []
            filteredDecorations[screenRow].push decoration

      for screenRow in [@startScreenRow...@endScreenRow]
        if @editor.isFoldableAtScreenRow(screenRow)
          filteredDecorations[screenRow] ?= []
          filteredDecorations[screenRow].push new Decoration(null, {class: 'foldable'})

      @decorationsCache[decorationType] = filteredDecorations
    @decorationsCache[decorationType]

  decorationsByMarkerIdForType: (decorationType) ->
    filteredDecorations = {}
    for id, decorations of @decorationsByMarkerId
      for decoration in decorations
        if decoration.isType(decorationType)
          filteredDecorations[id] ?= []
          filteredDecorations[id].push decoration
    filteredDecorations

  indexDecorationsByScreenRow: (decorationsByMarkerId) ->
    decorationsByScreenRow = {}
    for id, decorations of decorationsByMarkerId
      for decoration in decorations
        continue unless decoration.isValid()
        range = decoration.getScreenRange()
        for screenRow in [range.start.row..range.end.row]
          decorationsByScreenRow[screenRow] ?= []
          decorationsByScreenRow[screenRow].push(decoration)
    decorationsByScreenRow
