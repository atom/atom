start = _ match:(selector) _ {
  return match;
}

segment
  = _ segment:[a-zA-Z0-9]+ _ {
    var segment = segment.join("");
    return function(scope) {
      return scope === segment;
    };
  }

  / _ scopeName:[\*] _ {
    return function() {
      return true;
    };
  }

scope
  = first:segment others:("." segment)* {
    return function(scope) {
      var segments = [first];
      for (var i = 0; i < others.length; i++)
        segments.push(others[i][1]);

      var scopeSegments = scope.split(".");
      if (scopeSegments.length < segments.length)
        return false;

      var allSegmentsMatch = true;
      for (var j = 0; j < segments.length; j++)
        if (!segments[j](scopeSegments[j]))
          return false;
      return true;
    }
  }

path
  = first:scope others:(_ scope)* {
    return function(scopes) {
      var scopeMatchers = [first];
      for (var i = 0; i < others.length; i++)
        scopeMatchers.push(others[i][1]);

      var matcher = scopeMatchers.shift();
      for (var i = 0; i < scopes.length; i++) {
        if (matcher(scopes[i]))
          matcher = scopeMatchers.shift();
        if (!matcher)
          return true;
      }
      return false;
    }
  }

expression
  = path

  / "(" _ selector:selector _ ")" {
    return selector;
  }

composite
  = left:expression  _ operator:[|&-] _ right:composite {
      switch(operator) {
        case "|":
          return function(scopes) {
            return left(scopes) || right(scopes);
          };
        case "&":
          return function(scopes) {
            return left(scopes) && right(scopes);
          };
        case "-":
          return function(scopes) {
            return left(scopes) && !right(scopes);
          };
      }
    }

  / expression

selector
  = left:composite _ "," _ right:selector {
      return function(scopes) {
        return left(scopes) || right(scopes);
      };
    }

  / composite

_
  = [ \t]*
