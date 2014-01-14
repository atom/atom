{remove} = require 'underscore-plus'

# Public: A global which manages the relationship between views and models.
# Given a model, it can be used to find or create an appropriate view. Access
# the singleton instance via the `atom.views` global.
module.exports =
class ViewRegistry
  # Private:
  constructor: ->
    @viewClassesByName = {}
    @viewsByModel = new WeakMap

  # Public: Registers a view class. If the class is named 'FooView', it will be
  # used to create views for model instances of class 'Foo'.
  register: (viewClass) ->
    @viewClassesByName[viewClass.name] = viewClass

  # Public: Returns a view class appropriate for visualizing a given model.
  getViewClass: (model) ->
    @viewClassesByName[model.constructor.name + 'View'] ? model.getViewClass()

  # Public: Creates a new view for the given model, assuming an appropriate view
  # class has been registered or the model implements a `.getViewClass` method.
  create: (model) ->
    throw new Error("Cannot create view for undefined model") unless model?

    if viewClass = @getViewClass(model)
      view = new viewClass(model)
      @viewsByModel.set(model, []) unless @viewsByModel.has(model)
      @viewsByModel.get(model).push(view)
      view
    else
      throw new Error("No view found for model of class #{model.constructor.name}")

  # Public: Returns an existing view for the given model, if one exists.
  find: (model) ->
    @viewsByModel.get(model)?[0] if model?

  # Public: Returns an existing view for the given model if one exists or
  # creates and returns a new one.
  findOrCreate: (model, context) ->
    if model?
      @find(model) ? @create(model)

  # Public: Removes the association between the given view and the model. You
  # only need to call this if you plan on holding a reference to the model but
  # no longer want to hold a reference to the view.
  remove: (model, view) ->
    if viewsForModel = @viewsByModel.get(model)
      remove(viewsForModel, view)

  # Deprecated: Associates an arbitrary model with an arbitrary view. Used for
  # supporting deprecated API paths where a manually-created view needs to blend
  # in with code that uses the view registry.
  associate: (model, view) ->
    @viewsByModel.set(model, []) unless @viewsByModel.has(model)
    @viewsByModel.get(model).push(view)
