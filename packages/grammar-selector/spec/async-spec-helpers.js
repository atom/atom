exports.beforeEach = function beforeEach (fn) {
  global.beforeEach(function () {
    const result = fn()
    if (result instanceof Promise) {
      waitsForPromise('beforeEach promise', result)
    }
  })
}

exports.afterEach = function afterEach (fn) {
  global.afterEach(function () {
    const result = fn()
    if (result instanceof Promise) {
      waitsForPromise('afterEach promise', result)
    }
  })
}

;['it', 'fit', 'ffit', 'fffit'].forEach(function (name) {
  exports[name] = function (description, fn) {
    if (fn === undefined) {
      global[name](description)
      return
    }

    global[name](description, function () {
      const result = fn()
      if (result instanceof Promise) {
        waitsForPromise('test promise', result)
      }
    })
  }
})

function waitsForPromise (message, promise) {
  global.waitsFor(message, (done) => {
    promise.then(done, (error) => {
      jasmine.getEnv().currentSpec.fail(error)
      done()
    })
  })
}
