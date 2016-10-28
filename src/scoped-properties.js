import CSON from 'season'

export default class ScopedProperties {
  static load (scopedPropertiesPath, config, callback) {
    return CSON.readFile(scopedPropertiesPath, (error, scopedProperties = {}) => {
      if (error != null) {
        return callback(error)
      } else {
        return callback(null, new ScopedProperties(scopedPropertiesPath, scopedProperties, config))
      }
    })
  }

  constructor (path, scopedProperties, config) {
    this.path = path
    this.scopedProperties = scopedProperties
    this.config = config
  }

  activate () {
    for (let selector in this.scopedProperties) {
      let properties = this.scopedProperties[selector]
      this.config.set(null, properties, {
        scopeSelector: selector,
        source: this.path
      })
    }
  }

  deactivate () {
    for (let selector in this.scopedProperties) {
      this.config.unset(null, {
        scopeSelector: selector,
        source: this.path
      })
    }
  }
}
