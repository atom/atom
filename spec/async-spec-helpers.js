/** @babel */

export function beforeEach (fn) {
  global.beforeEach(function () {
    const result = fn()
    if (result instanceof Promise) {
      waitsForPromise(() => result)
    }
  })
}

export function afterEach (fn) {
  global.afterEach(function () {
    const result = fn()
    if (result instanceof Promise) {
      waitsForPromise(() => result)
    }
  })
}

['it', 'fit', 'ffit', 'fffit'].forEach(function (name) {
  module.exports[name] = function (description, fn) {
    global[name](description, function () {
      const result = fn()
      if (result instanceof Promise) {
        waitsForPromise(() => result)
      }
    })
  }
})

export function conditionPromise (condition)  {
  const timeoutError = new Error("Timed out waiting on condition")
  Error.captureStackTrace(timeoutError, conditionPromise)

  return new Promise(function (resolve, reject) {
    const interval = global.setInterval(function () {
      if (condition()) {
        global.clearInterval(interval)
        global.clearTimeout(timeout)
        resolve()
      }
    }, 100)
    const timeout = global.setTimeout(function () {
      global.clearInterval(interval)
      reject(timeoutError)
    }, 5000)
  })
}

export function timeoutPromise (timeout) {
  return new Promise(function (resolve) {
    global.setTimeout(resolve, timeout)
  })
}

function waitsForPromise (fn) {
  const promise = fn()
  // This timeout is 3 minutes. We need to bump it back down once we fix
  // backgrounding of the renderer process on CI. See https://github.com/atom/electron/issues/4317
  global.waitsFor('spec promise to resolve', 3 * 60 * 1000, function (done) {
    promise.then(done, function (error) {
      jasmine.getEnv().currentSpec.fail(error)
      done()
    })
  })
}
