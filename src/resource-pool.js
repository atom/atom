/** @babel */

// Manages a pool of some resource.
export default class ResourcePool {
  constructor (pool) {
    this.pool = pool

    this.queue = []
  }

  // Enqueue the given function. The function will be given an object from the
  // pool. The function must return a {Promise}.
  enqueue (fn) {
    let resolve = null
    let reject = null
    const wrapperPromise = new Promise((resolve_, reject_) => {
      resolve = resolve_
      reject = reject_
    })

    this.queue.push(this.wrapFunction(fn, resolve, reject))

    this.dequeueIfAble()

    return wrapperPromise
  }

  wrapFunction (fn, resolve, reject) {
    return (resource) => {
      const promise = fn(resource)
      promise
        .then(result => {
          resolve(result)
          this.taskDidComplete(resource)
        }, error => {
          reject(error)
          this.taskDidComplete(resource)
        })
    }
  }

  taskDidComplete (resource) {
    this.pool.push(resource)

    this.dequeueIfAble()
  }

  dequeueIfAble () {
    if (!this.pool.length || !this.queue.length) return

    const fn = this.queue.shift()
    const resource = this.pool.shift()
    fn(resource)
  }

  getQueueDepth () { return this.queue.length }
}
