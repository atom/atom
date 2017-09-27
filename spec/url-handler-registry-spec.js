/** @babel */

import url from 'url'

import {it} from './async-spec-helpers'

import UrlHandlerRegistry from '../src/url-handler-registry'

describe('UrlHandlerRegistry', () => {
  let registry

  beforeEach(() => {
    registry = new UrlHandlerRegistry(5)
  })

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

  it('keeps track of the most recent URIs', () => {
    const spy1 = jasmine.createSpy()
    const spy2 = jasmine.createSpy()
    const changeSpy = jasmine.createSpy()
    registry.registerHostHandler('one', spy1)
    registry.registerHostHandler('two', spy2)
    registry.onHistoryChange(changeSpy)

    const urls = [
      'atom://one/something?asdf=1',
      'atom://fake/nothing',
      'atom://two/other/stuff',
      'atom://one/more/thing',
      'atom://two/more/stuff'
    ]

    urls.forEach(u => registry.handleUrl(u))

    expect(changeSpy.callCount).toBe(5)
    expect(registry.getRecentlyHandledUrls()).toEqual(urls.map((u, idx) => {
      return {id: idx + 1, url: u, handled: !u.match(/fake/), host: url.parse(u).host}
    }).reverse())

    registry.handleUrl('atom://another/url')
    expect(changeSpy.callCount).toBe(6)
    const history = registry.getRecentlyHandledUrls()
    expect(history.length).toBe(5)
    expect(history[0].url).toBe('atom://another/url')
    expect(history[4].url).toBe(urls[1])
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
