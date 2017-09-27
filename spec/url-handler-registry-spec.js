/** @babel */

import url from 'url'

import {it} from './async-spec-helpers'

import UrlHandlerRegistry from '../src/url-handler-registry'

describe('UrlHandlerRegistry', () => {
  let registry = new UrlHandlerRegistry()

  it('handles URLs on a per-host basis', () => {
    const testPackageSpy = jasmine.createSpy()
    const otherPackageSpy = jasmine.createSpy()
    registry.registerHostHandler('test-package', testPackageSpy)
    registry.registerHostHandler('other-package', otherPackageSpy)

    registry.handleUrl('atom://yet-another-package/path')
    expect(testPackageSpy).not.toHaveBeenCalled()
    expect(otherPackageSpy).not.toHaveBeenCalled()

    registry.handleUrl('atom://test-package/path')
    expect(testPackageSpy).toHaveBeenCalledWith(url.parse('atom://test-package/path', true), 'atom://test-package/path')
    expect(otherPackageSpy).not.toHaveBeenCalled()

    registry.handleUrl('atom://other-package/path')
    expect(otherPackageSpy).toHaveBeenCalledWith(url.parse('atom://other-package/path', true), 'atom://other-package/path')
  })

  it('refuses to handle bad URLs', () => {
    [
      'atom:package/path',
      'atom:8080://package/path',
      'user:pass@atom://package/path',
      'smth://package/path'
    ].forEach(uri => {
      expect(() => registry.handleUrl(uri)).toThrow()
    })
  })
})
