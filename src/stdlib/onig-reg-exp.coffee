module.exports =
class OnigRegExp
  constructor: (source) ->
    regexp = $onigRegExp.buildOnigRegExp(source);
    regexp.constructor = OnigRegExp
    regexp.__proto__ = OnigRegExp.prototype
    regexp.source = source
    return regexp

  search: $onigRegExp.search
  test: $onigRegExp.test
