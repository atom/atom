{
  var matchers = require('text-mate-scope-selector-matchers');
}

start = _ selector:(selector) _ {
  return selector;
}

segment
  = _ segment:([a-zA-Z0-9+_]+[a-zA-Z0-9-+_]*) _ {
    return new matchers.SegmentMatcher(segment);
  }

  / _ scopeName:[\*] _ {
    return new matchers.TrueMatcher();
  }

scope
  = first:segment others:("." segment)* {
    return new matchers.ScopeMatcher(first, others);
  }

path
  = first:scope others:(_ scope)* {
    return new matchers.PathMatcher(first, others);
  }

group
  = "(" _ selector:selector _ ")" {
    return selector;
  }

filter
  = prefix:([LRB]":") _ group:group {
    return group;
  }

  / prefix:([LRB]":") _ path:path {
    return path;
  }

expression
  = "-" _ filter:filter _ {
    return new matchers.NegateMatcher(filter);
  }

  / "-" _ group:group _ {
    return new matchers.NegateMatcher(group);
  }

  / "-" _ path:path _ {
    return new matchers.NegateMatcher(path);
  }

  / filter

  / group

  / path

composite
  = left:expression _ operator:[|&-] _ right:composite {
    return new matchers.CompositeMatcher(left, operator, right);
  }

  / expression

selector
  = left:composite _ "," _ right:selector? {
    if (right)
      return new matchers.OrMatcher(left, right);
    else
      return left;
  }

  / composite

_
  = [ \t]*
