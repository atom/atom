atom.deserializers.add('MyDeserializer', function (state) {
  return {state: state, a: 'b'}
})

exports.activate = function () {}
