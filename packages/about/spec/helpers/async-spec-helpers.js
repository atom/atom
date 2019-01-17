/** @babel */

const {now} = Date
const {setTimeout} = global

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

export async function conditionPromise (condition) {
  const startTime = now()

  while (true) {
    await timeoutPromise(100)

    if (await condition()) {
      return
    }

    if (now() - startTime > 5000) {
      throw new Error('Timed out waiting on condition')
    }
  }
}

export function timeoutPromise (timeout) {
  return new Promise(function (resolve) {
    setTimeout(resolve, timeout)
  })
}

function waitsForPromise (fn) {
  const promise = fn()
  global.waitsFor('spec promise to resolve', function (done) {
    promise.then(done, function (error) {
      jasmine.getEnv().currentSpec.fail(error)
      done()
    })
  })
}
