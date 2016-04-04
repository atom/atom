/** @babel */

import ResourcePool from '../src/resource-pool'

import {it} from './async-spec-helpers'

describe('ResourcePool', () => {
  let queue

  beforeEach(() => {
    queue = new ResourcePool([{}])
  })

  describe('.enqueue', () => {
    it('calls the enqueued function', async () => {
      let called = false
      await queue.enqueue(() => {
        called = true
        return Promise.resolve()
      })
      expect(called).toBe(true)
    })

    it('forwards values from the inner promise', async () => {
      const result = await queue.enqueue(() => Promise.resolve(42))
      expect(result).toBe(42)
    })

    it('forwards errors from the inner promise', async () => {
      let threw = false
      try {
        await queue.enqueue(() => Promise.reject(new Error('down with the sickness')))
      } catch (e) {
        threw = true
      }
      expect(threw).toBe(true)
    })

    it('continues to dequeue work after a promise has been rejected', async () => {
      try {
        await queue.enqueue(() => Promise.reject(new Error('down with the sickness')))
      } catch (e) {}

      const result = await queue.enqueue(() => Promise.resolve(42))
      expect(result).toBe(42)
    })

    it('queues up work', async () => {
      let resolve = null
      queue.enqueue(() => {
        return new Promise((resolve_, reject) => {
          resolve = resolve_
        })
      })

      expect(queue.getQueueDepth()).toBe(0)

      queue.enqueue(() => new Promise((resolve, reject) => {}))

      expect(queue.getQueueDepth()).toBe(1)
      resolve()

      waitsFor(() => queue.getQueueDepth() === 0)
    })
  })
})
