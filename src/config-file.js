const _ = require('underscore-plus')
const fs = require('fs-plus')
const dedent = require('dedent')
const {Emitter} = require('event-kit')
const {watchPath} = require('./path-watcher')
const CSON = require('season')
const Path = require('path')

const EVENT_TYPES = new Set([
  'created',
  'modified',
  'renamed'
])

module.exports =
class ConfigFile {
  constructor (path) {
    this.path = path
    this.requestLoad = _.debounce(() => this.reload(), 100)
    this.emitter = new Emitter()
    this.value = {}
  }

  get () {
    return this.value
  }

  update (value) {
    return new Promise((resolve, reject) =>
      CSON.writeFile(this.path, value, error => {
        if (error) {
          reject(error)
        } else {
          this.value = value
          resolve()
        }
      })
    )
  }

  async watch (callback) {
    if (!fs.existsSync(this.path)) {
      fs.makeTreeSync(Path.dirname(this.path))
      CSON.writeFileSync(this.path, {}, {flag: 'wx'})
    }

    await this.reload()

    try {
      const watcher = await watchPath(this.path, {}, events => {
        if (events.some(event => EVENT_TYPES.has(event.action))) this.requestLoad()
      })
      return watcher
    } catch (error) {
      this.emitter.emit('did-error', dedent `
        Unable to watch path: \`${Path.basename(this.path)}\`.

        Make sure you have permissions to \`${this.path}\`.
        On linux there are currently problems with watch sizes.
        See [this document][watches] for more info.

        [watches]:https://github.com/atom/atom/blob/master/docs/build-instructions/linux.md#typeerror-unable-to-watch-path\
      `)
    }
  }

  onDidChange (callback) {
    return this.emitter.on('did-change', callback)
  }

  onDidError (callback) {
    return this.emitter.on('did-error', callback)
  }

  reload () {
    return new Promise(resolve => {
      CSON.readFile(this.path, (error, data) => {
        if (error) {
          this.emitter.emit('did-error', `Failed to load \`${Path.basename(this.path)}\` - ${error.message}`)
        } else {
          this.value = data || {}
          this.emitter.emit('did-change', this.value)
        }
        resolve()
      })
    })
  }
}
