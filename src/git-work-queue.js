/** @babel */

// A queue used to manage git work.
export default class GitWorkQueue {
  constructor () {
    this.queue = []
    this.working = false
  }

  // Enqueue the given function. The function must return a {Promise} when
  // called.
  enqueue (fn) {
    let resolve = null
    let reject = null
    const wrapperPromise = new Promise((resolve_, reject_) => {
      resolve = resolve_
      reject = reject_
    })

    this.queue.push(this.wrapFunction(fn, resolve, reject))

    if (this.shouldStartNext()) {
      this.startNext()
    }

    return wrapperPromise
  }

  wrapFunction (fn, resolve, reject) {
    return () => {
      const promise = fn()
      promise
        .then(result => {
          resolve(result)
          this.taskDidComplete()
        }, error => {
          reject(error)
          this.taskDidComplete()
        })
    }
  }

  taskDidComplete () {
    this.working = false

    if (this.shouldStartNext()) {
      this.startNext()
    }
  }

  shouldStartNext () {
    return !this.working && this.queue.length > 0
  }

  startNext () {
    this.working = true

    const fn = this.queue.shift()
    fn()
  }

  getQueueDepth () { return this.queue.length }
}
