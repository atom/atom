_ServiceHub = require('service-hub')

# Experimental: This class facilitates communication between Atom packages
# through semantically-versioned services. If you want your package to provide
# an API for other packages to interact with, provide or consume a service via
# the global instance of this class available as `atom.services`.
#
# If you're providing an API for other packages, the most straightforward is to
# `provide` a module namespaced under your package's name as follows.
#
# ```coffee
# atom.services.provide "status-bar", "1.0.0",
#   addRightItem: (item) -> # ...
#   addLeftItem: (item) -> # ...
# ```
#
# Then other packages can interact with your package by consuming the provided
# service. Note that a service consumer can provide an npm-style version range
# string to express the required API version of the consumed service. The
# callback will be invoked with the service immediately or when the service
# becomes available. If multiple services match the provided key-path and
# version range, the callback will be invoked multiple times.
#
# ```coffee
# atom.services.consume "status-bar", "^1.0.0", (statusBar) ->
#   statusBar.addLeftItem(new GrammarChanger)
# ```
#
# You can also provide multiple services end-points under the same namespace by
# passing a dot-separated key path. In this example, we also provide a global
# reference to the status bar's DOM element so other packages can modify it
# directly. Doing this via `atom.services` is superior to querying from the DOM
# manually because you can use semantic versioning to indicate when the DOM
# structure changes in a breaking way.
#
# ```coffee
# atom.services.provide "status-bar.view", "1.0.0", statusBarElement
# ```
#
# By convention, every package owns its package name in the services namespace.
# Your package can provide a service under another package's namespace, but you
# should always conform to that package's API. If you want to make additions to
# the API, add them under your own namespace.
#
# When upgrading your package's API, consider retaining previous versions with
# shims if at all possible to minimize breakage and to give the ecosystem time
# to catch up with your changes.
#
# You can also apply an inverted pattern, where your package consumes services
# under its own namespace. In this pattern, you would define a contract for
# services that other packages provide and your package consumes. For example,
# say we were adding the ability to add custom completion providers to
# autocomplete:
#
# ```coffee
# atom.services.consume "autocomplete", "1.0.0", (provider) ->
#   addCompletionProvider(provider)
# ```
#
# In this use case, you would want to consume a specific version number rather
# than a range. You could consume multiple version numbers to provide backward
# compatibility.
module.exports =
class ServiceHub extends _ServiceHub
  # Experimental: Provide a service by invoking the callback of all current and
  # future consumers matching the given key path and version range.
  #
  # * `keyPath` A {String} of `.` separated keys indicating the services's
  #   location in the namespace of all services.
  # * `version` A {String} containing a [semantic version](http://semver.org/)
  #   for the service's API.
  # * `service` An object exposing the service API.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # provided service.
  provide: (keyPath, version, service) ->
    super

  # Experimental: Consume a service by invoking the given callback for all
  # current and future provided services matching the given key path and version
  # range.
  #
  # * `keyPath` A {String} of `.` separated keys indicating the services's
  #   location in the namespace of all services.
  # * `versionRange` A {String} containing a [semantic version range](https://www.npmjs.org/doc/misc/semver.html)
  #   that any provided services for the given key path must satisfy.
  # * `callback` A {Function} to be called with current and future matching
  #   service objects.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # consumer.
  consume: (keyPath, versionRange, callback) ->
    super
