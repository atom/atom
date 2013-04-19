{
  var matchers = require('text-mate-scope-selector-matchers');
}

start = _ selector:(selector) _ {
  return selector;
}

segment
  = _ segment:[a-zA-Z0-9]+ _ {
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

expression
  = path

  / "(" _ selector:selector _ ")" {
    return selector;
  }

composite
  = left:expression  _ operator:[|&-] _ right:composite {
    return new matchers.CompositeMatcher(left, operator, right);
  }

  / expression

selector
  = left:composite _ "," _ right:selector {
    return new matchers.OrMatcher(left, right);
  }

  / composite

_
  = [ \t]*
