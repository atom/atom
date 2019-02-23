function beforeEach (fn) {
  global.beforeEach(() => {
    const result = fn()
    if (result instanceof Promise) {
      waitsForPromise(() => result)
    }
  })
}

function afterEach (fn) {
  global.afterEach(() => {
    const result = fn()
    if (result instanceof Promise) {
      waitsForPromise(() => result)
    }
  })
}

;['it', 'fit', 'ffit', 'fffit'].forEach(name => {
  exports[name] = (description, fn) => {
    if (fn === undefined) {
      global[name](description)
      return
    }

    global[name](description, () => {
      const result = fn()
      if (result instanceof Promise) {
        waitsForPromise(() => result)
      }
    })
  }
})

async function conditionPromise (condition, description = 'anonymous condition') {
  const startTime = Date.now()

  while (true) {
    await timeoutPromise(100)

    if (await condition()) {
      return
    }

    if (Date.now() - startTime > 5000) {
      throw new Error('Timed out waiting on ' + description)
    }
  }
}

function timeoutPromise (timeout) {
  return new Promise(resolve => {
    global.setTimeout(resolve, timeout)
  })
}

function waitsForPromise (fn) {
  const promise = fn()
  global.waitsFor('spec promise to resolve', done => {
    promise.then(done, error => {
      jasmine.getEnv().currentSpec.fail(error)
      done()
    })
  })
}

function emitterEventPromise (emitter, event, timeout = 15000) {
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

function promisify (original) {
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

function promisifySome (obj, fnNames) {
  const result = {}
  for (const fnName of fnNames) {
    result[fnName] = promisify(obj[fnName])
  }
  return result
}

exports.afterEach = afterEach
exports.beforeEach = beforeEach
exports.conditionPromise = conditionPromise
exports.emitterEventPromise = emitterEventPromise
exports.promisify = promisify
exports.promisifySome = promisifySome
exports.timeoutPromise = timeoutPromise
