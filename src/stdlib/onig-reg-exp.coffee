module.exports =
class OnigRegExp
  @create: (source) ->
    regexp = $onigRegExp.buildOnigRegExp(source);
    regexp.constructor = OnigRegExp
    regexp.__proto__ = OnigRegExp.prototype
    regexp.source = source
    regexp

  search: $onigRegExp.search
  test: $onigRegExp.test
