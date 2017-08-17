exports.beforeEach = (fn) ->
  global.beforeEach ->
    result = fn()
    if result instanceof Promise
      waitsForPromise(-> result)

exports.afterEach = (fn) ->
  global.afterEach ->
    result = fn()
    if result instanceof Promise
      waitsForPromise(-> result)

['it', 'fit', 'ffit', 'fffit'].forEach (name) ->
  exports[name] = (description, fn) ->
    global[name] description, ->
      result = fn()
      if result instanceof Promise
        waitsForPromise(-> result)

waitsForPromise = (fn) ->
  promise = fn()
  # This timeout is 3 minutes. We need to bump it back down once we fix backgrounding
  # of the renderer process on CI. See https://github.com/atom/electron/issues/4317
  waitsFor 'spec promise to resolve', 3 * 60 * 1000, (done) ->
    promise.then(
      done,
      (error) ->
        jasmine.getEnv().currentSpec.fail(error)
        done()
    )
