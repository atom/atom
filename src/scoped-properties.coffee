Grim = require 'grim'
CSON = require 'season'
{CompositeDisposable} = require 'event-kit'

module.exports =
class ScopedProperties
  @load: (scopedPropertiesPath, callback) ->
    CSON.readFile scopedPropertiesPath, (error, scopedProperties={}) ->
      if error?
        callback(error)
      else
        callback(null, new ScopedProperties(scopedPropertiesPath, scopedProperties))

  constructor: (@path, @scopedProperties) ->
    for selector, properties of @scopedProperties
      if properties.editor?.commentStart?
        properties.editor.comment ?= {}
        properties.editor.comment.start ?= properties.editor.commentStart
        delete properties.editor.commentStart
        Grim.deprecate("The 'editor.commentStart' setting has been moved to 'editor.comment.start'.  Please update `#{@path}`.")

      if properties.editor?.commentEnd?
        properties.editor.comment ?= {}
        properties.editor.comment.end ?= properties.editor.commentEnd
        delete properties.editor.commentEnd
        Grim.deprecate("The 'editor.commentEnd' setting has been moved to 'editor.comment.end'. Please update `#{@path}`.")

      if properties.editor?.increaseIndentPattern?
        properties.editor.indent ?= {}
        properties.editor.indent.increasePattern ?= properties.editor.increaseIndentPattern
        delete properties.editor.increaseIndentPattern
        Grim.deprecate("The 'editor.increaseIndentPattern' setting has been moved to 'editor.indent.increasePattern'.  Please update `#{@path}`.")

      if properties.editor?.decreaseIndentPattern?
        properties.editor.indent ?= {}
        properties.editor.indent.decreasePattern ?= properties.editor.decreaseIndentPattern
        delete properties.editor.decreaseIndentPattern
        Grim.deprecate("The 'editor.decreaseIndentPattern' setting has been moved to 'editor.indent.decreasePattern'.  Please update `#{@path}`.")

    @propertyDisposable = new CompositeDisposable

  activate: ->
    for selector, properties of @scopedProperties
      @propertyDisposable.add atom.config.addScopedSettings(@path, selector, properties)
    return

  deactivate: ->
    @propertyDisposable.dispose()
