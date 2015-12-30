{Subscriber} = require 'emissary'
SubscriberMixin = componentDidUnmount: -> @unsubscribe()
Subscriber.extend(SubscriberMixin)
module.exports = SubscriberMixin
