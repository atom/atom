/** @babel */

// Manages a pool of some resource.
export default class ResourcePool {
  constructor (pool) {
    this.pool = pool

    this.queue = []
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

    this.startNextIfAble()

    return wrapperPromise
  }

  wrapFunction (fn, resolve, reject) {
    return () => {
      const repo = this.pool.shift()
      const promise = fn(repo)
      promise
        .then(result => {
          resolve(result)
          this.taskDidComplete(repo)
        }, error => {
          reject(error)
          this.taskDidComplete(repo)
        })
    }
  }

  taskDidComplete (repo) {
    this.pool.push(repo)

    this.startNextIfAble()
  }

  startNextIfAble () {
    if (!this.pool.length || !this.queue.length) return

    const fn = this.queue.shift()
    fn()
  }

  getQueueDepth () { return this.queue.length }
}
