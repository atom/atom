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
    if (fn === undefined) {
      global[name](description)
      return
    }

    global[name](description, function () {
      const result = fn()
      if (result instanceof Promise) {
        waitsForPromise(() => result)
      }
    })
  }
})

export async function conditionPromise (condition) {
  const startTime = Date.now()

  while (true) {
    await timeoutPromise(100)

    if (await condition()) {
      return
    }

    if (Date.now() - startTime > 5000) {
      throw new Error('Timed out waiting on condition')
    }
  }
}

export function timeoutPromise (timeout) {
  return new Promise(function (resolve) {
    global.setTimeout(resolve, timeout)
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

export function emitterEventPromise (emitter, event, timeout = 15000) {
  return new Promise((resolve, reject) => {
    const timeoutHandle = setTimeout(() => {
      reject(new Error(`Timed out waiting for '${event}' event`))
    }, timeout)
    emitter.once(event, () => {
      clearTimeout(timeoutHandle)
      resolve()
    })
  })
}

export function promisify (original) {
  return function (...args) {
    return new Promise((resolve, reject) => {
      args.push((err, ...results) => {
        if (err) {
          reject(err)
        } else {
          resolve(...results)
        }
      })

      return original(...args)
    })
  }
}

export function promisifySome (obj, fnNames) {
  const result = {}
  for (const fnName of fnNames) {
    result[fnName] = promisify(obj[fnName])
  }
  return result
}
