let nextInstanceId = 1

export default class Model {
  static resetNextInstanceId () {
    nextInstanceId = 1
  }

  constructor (params = {}) {
    this.alive = true
    this.assignId(params.id)
  }

  assignId (id) {
    this.id = this.id || id || nextInstanceId++
    if (id >= nextInstanceId) {
      nextInstanceId = id + 1
    }
  }

  destroy () {
    if (!this.isAlive()) return
    this.alive = false
    if (typeof this.destroyed === 'function') {
      this.destroyed()
    }
  }

  isAlive () {
    return this.alive
  }

  isDestroyed () {
    return !this.isAlive()
  }
}
