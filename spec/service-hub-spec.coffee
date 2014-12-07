describe 'ServiceHub', ->
  fdescribe 'apiVersion', ->
    it 'gets the API version for the default API', ->
      spyOn(atom.services, 'getPackageInfo').andReturn
        apiVersion: '1.2.3'

      expect(atom.services.apiVersion('package-name')).toEqual '1.2.3'

    it 'gets the API version for a named API', ->
      spyOn(atom.services, 'getPackageInfo').andReturn
        apiVersion:
          frob: '1.1.0'
          xyzzy: '2.2.0'

      expect(atom.services.apiVersion('package-name.frob')).toEqual '1.1.0'
      expect(atom.services.apiVersion('package-name.xyzzy')).toEqual '2.2.0'

    it 'gets the API version from a deeply nested API', ->
      spyOn(atom.services, 'getPackageInfo').andReturn
        apiVersion:
          frob:
            xyzzy:
              blorch: '5.5.5'

      expect(atom.services.apiVersion('package-name.frob.xyzzy.blorch')).toEqual '5.5.5'

    it 'returns undefined if an API cannot be found', ->
      spyOn(atom.services, 'getPackageInfo').andReturn
        apiVersion:
          frob:
            xyzzy:
              blorch: '5.5.5'

      expect(atom.services.apiVersion('package-name.foo')).toBeUndefined()

    it 'returns undefined if not given a keyPath', ->
      expect(atom.services.apiVersion()).toBeUndefined()
