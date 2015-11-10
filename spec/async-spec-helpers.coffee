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
  waitsFor 'spec promise to resolve', 30000, (done) ->
    promise.then(
      done,
      (error) ->
        jasmine.getEnv().currentSpec.fail(error)
        done()
    )
