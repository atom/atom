/**
 * Copyright (c) 2011 Jeremy Ashkenas
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

define(function(require, exports, module) {
  var Access, Arr, Assign, Base, Block, Call, Class, Closure, Code, Comment, Existence, Extends, For, IDENTIFIER, IS_STRING, If, In, Index, LEVEL_ACCESS, LEVEL_COND, LEVEL_LIST, LEVEL_OP, LEVEL_PAREN, LEVEL_TOP, Literal, METHOD_DEF, NEGATE, NO, Obj, Op, Param, Parens, Push, Range, Return, SIMPLENUM, Scope, Slice, Splat, Switch, TAB, THIS, Throw, Try, UTILITIES, Value, While, YES, compact, del, ends, extend, flatten, last, merge, multident, starts, unfoldSoak, utility, _ref;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    }
    return -1;
  };
  Scope = require('ace/mode/coffee/scope').Scope;
  _ref = require('ace/mode/coffee/helpers'), compact = _ref.compact, flatten = _ref.flatten, extend = _ref.extend, merge = _ref.merge, del = _ref.del, starts = _ref.starts, ends = _ref.ends, last = _ref.last;
  exports.extend = extend;
  YES = function() {
    return true;
  };
  NO = function() {
    return false;
  };
  THIS = function() {
    return this;
  };
  NEGATE = function() {
    this.negated = !this.negated;
    return this;
  };
  exports.Base = Base = (function() {
    function Base() {}
    Base.prototype.compile = function(o, lvl) {
      var node;
      o = extend({}, o);
      if (lvl) {
        o.level = lvl;
      }
      node = this.unfoldSoak(o) || this;
      node.tab = o.indent;
      if (o.level === LEVEL_TOP || !node.isStatement(o)) {
        return node.compileNode(o);
      } else {
        return node.compileClosure(o);
      }
    };
    Base.prototype.compileClosure = function(o) {
      if (this.jumps() || this instanceof Throw) {
        throw SyntaxError('cannot use a pure statement in an expression.');
      }
      o.sharedScope = true;
      return Closure.wrap(this).compileNode(o);
    };
    Base.prototype.cache = function(o, level, reused) {
      var ref, sub;
      if (!this.isComplex()) {
        ref = level ? this.compile(o, level) : this;
        return [ref, ref];
      } else {
        ref = new Literal(reused || o.scope.freeVariable('ref'));
        sub = new Assign(ref, this);
        if (level) {
          return [sub.compile(o, level), ref.value];
        } else {
          return [sub, ref];
        }
      }
    };
    Base.prototype.compileLoopReference = function(o, name) {
      var src, tmp;
      src = tmp = this.compile(o, LEVEL_LIST);
      if (!((-Infinity < +src && +src < Infinity) || IDENTIFIER.test(src) && o.scope.check(src, true))) {
        src = "" + (tmp = o.scope.freeVariable(name)) + " = " + src;
      }
      return [src, tmp];
    };
    Base.prototype.makeReturn = function() {
      return new Return(this);
    };
    Base.prototype.contains = function(pred) {
      var contains;
      contains = false;
      this.traverseChildren(false, function(node) {
        if (pred(node)) {
          contains = true;
          return false;
        }
      });
      return contains;
    };
    Base.prototype.containsType = function(type) {
      return this instanceof type || this.contains(function(node) {
        return node instanceof type;
      });
    };
    Base.prototype.lastNonComment = function(list) {
      var i;
      i = list.length;
      while (i--) {
        if (!(list[i] instanceof Comment)) {
          return list[i];
        }
      }
      return null;
    };
    Base.prototype.toString = function(idt, name) {
      var tree;
      if (idt == null) {
        idt = '';
      }
      if (name == null) {
        name = this.constructor.name;
      }
      tree = '\n' + idt + name;
      if (this.soak) {
        tree += '?';
      }
      this.eachChild(function(node) {
        return tree += node.toString(idt + TAB);
      });
      return tree;
    };
    Base.prototype.eachChild = function(func) {
      var attr, child, _i, _j, _len, _len2, _ref2, _ref3;
      if (!this.children) {
        return this;
      }
      _ref2 = this.children;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        attr = _ref2[_i];
        if (this[attr]) {
          _ref3 = flatten([this[attr]]);
          for (_j = 0, _len2 = _ref3.length; _j < _len2; _j++) {
            child = _ref3[_j];
            if (func(child) === false) {
              return this;
            }
          }
        }
      }
      return this;
    };
    Base.prototype.traverseChildren = function(crossScope, func) {
      return this.eachChild(function(child) {
        if (func(child) === false) {
          return false;
        }
        return child.traverseChildren(crossScope, func);
      });
    };
    Base.prototype.invert = function() {
      return new Op('!', this);
    };
    Base.prototype.unwrapAll = function() {
      var node;
      node = this;
      while (node !== (node = node.unwrap())) {
        continue;
      }
      return node;
    };
    Base.prototype.children = [];
    Base.prototype.isStatement = NO;
    Base.prototype.jumps = NO;
    Base.prototype.isComplex = YES;
    Base.prototype.isChainable = NO;
    Base.prototype.isAssignable = NO;
    Base.prototype.unwrap = THIS;
    Base.prototype.unfoldSoak = NO;
    Base.prototype.assigns = NO;
    return Base;
  })();
  exports.Block = Block = (function() {
    __extends(Block, Base);
    function Block(nodes) {
      this.expressions = compact(flatten(nodes || []));
    }
    Block.prototype.children = ['expressions'];
    Block.prototype.push = function(node) {
      this.expressions.push(node);
      return this;
    };
    Block.prototype.pop = function() {
      return this.expressions.pop();
    };
    Block.prototype.unshift = function(node) {
      this.expressions.unshift(node);
      return this;
    };
    Block.prototype.unwrap = function() {
      if (this.expressions.length === 1) {
        return this.expressions[0];
      } else {
        return this;
      }
    };
    Block.prototype.isEmpty = function() {
      return !this.expressions.length;
    };
    Block.prototype.isStatement = function(o) {
      var exp, _i, _len, _ref2;
      _ref2 = this.expressions;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        exp = _ref2[_i];
        if (exp.isStatement(o)) {
          return true;
        }
      }
      return false;
    };
    Block.prototype.jumps = function(o) {
      var exp, _i, _len, _ref2;
      _ref2 = this.expressions;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        exp = _ref2[_i];
        if (exp.jumps(o)) {
          return exp;
        }
      }
    };
    Block.prototype.makeReturn = function() {
      var expr, len;
      len = this.expressions.length;
      while (len--) {
        expr = this.expressions[len];
        if (!(expr instanceof Comment)) {
          this.expressions[len] = expr.makeReturn();
          if (expr instanceof Return && !expr.expression) {
            this.expressions.splice(len, 1);
          }
          break;
        }
      }
      return this;
    };
    Block.prototype.compile = function(o, level) {
      if (o == null) {
        o = {};
      }
      if (o.scope) {
        return Block.__super__.compile.call(this, o, level);
      } else {
        return this.compileRoot(o);
      }
    };
    Block.prototype.compileNode = function(o) {
      var code, codes, node, top, _i, _len, _ref2;
      this.tab = o.indent;
      top = o.level === LEVEL_TOP;
      codes = [];
      _ref2 = this.expressions;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        node = _ref2[_i];
        node = node.unwrapAll();
        node = node.unfoldSoak(o) || node;
        if (top) {
          node.front = true;
          code = node.compile(o);
          codes.push(node.isStatement(o) ? code : this.tab + code + ';');
        } else {
          codes.push(node.compile(o, LEVEL_LIST));
        }
      }
      if (top) {
        return codes.join('\n');
      }
      code = codes.join(', ') || 'void 0';
      if (codes.length > 1 && o.level >= LEVEL_LIST) {
        return "(" + code + ")";
      } else {
        return code;
      }
    };
    Block.prototype.compileRoot = function(o) {
      var code;
      o.indent = this.tab = o.bare ? '' : TAB;
      o.scope = new Scope(null, this, null);
      o.level = LEVEL_TOP;
      code = this.compileWithDeclarations(o);
      if (o.bare) {
        return code;
      } else {
        return "(function() {\n" + code + "\n}).call(this);\n";
      }
    };
    Block.prototype.compileWithDeclarations = function(o) {
      var assigns, code, declars, exp, i, post, rest, scope, _len, _ref2;
      code = post = '';
      _ref2 = this.expressions;
      for (i = 0, _len = _ref2.length; i < _len; i++) {
        exp = _ref2[i];
        exp = exp.unwrap();
        if (!(exp instanceof Comment || exp instanceof Literal)) {
          break;
        }
      }
      o = merge(o, {
        level: LEVEL_TOP
      });
      if (i) {
        rest = this.expressions.splice(i, this.expressions.length);
        code = this.compileNode(o);
        this.expressions = rest;
      }
      post = this.compileNode(o);
      scope = o.scope;
      if (scope.expressions === this) {
        declars = o.scope.hasDeclarations();
        assigns = scope.hasAssignments;
        if ((declars || assigns) && i) {
          code += '\n';
        }
        if (declars) {
          code += "" + this.tab + "var " + (scope.declaredVariables().join(', ')) + ";\n";
        }
        if (assigns) {
          code += "" + this.tab + "var " + (multident(scope.assignedVariables().join(', '), this.tab)) + ";\n";
        }
      }
      return code + post;
    };
    Block.wrap = function(nodes) {
      if (nodes.length === 1 && nodes[0] instanceof Block) {
        return nodes[0];
      }
      return new Block(nodes);
    };
    return Block;
  })();
  exports.Literal = Literal = (function() {
    __extends(Literal, Base);
    function Literal(value) {
      this.value = value;
    }
    Literal.prototype.makeReturn = function() {
      if (this.isStatement()) {
        return this;
      } else {
        return new Return(this);
      }
    };
    Literal.prototype.isAssignable = function() {
      return IDENTIFIER.test(this.value);
    };
    Literal.prototype.isStatement = function() {
      var _ref2;
      return (_ref2 = this.value) === 'break' || _ref2 === 'continue' || _ref2 === 'debugger';
    };
    Literal.prototype.isComplex = NO;
    Literal.prototype.assigns = function(name) {
      return name === this.value;
    };
    Literal.prototype.jumps = function(o) {
      if (!this.isStatement()) {
        return false;
      }
      if (!(o && (o.loop || o.block && (this.value !== 'continue')))) {
        return this;
      } else {
        return false;
      }
    };
    Literal.prototype.compileNode = function(o) {
      var code;
      code = this.isUndefined ? o.level >= LEVEL_ACCESS ? '(void 0)' : 'void 0' : this.value.reserved ? "\"" + this.value + "\"" : this.value;
      if (this.isStatement()) {
        return "" + this.tab + code + ";";
      } else {
        return code;
      }
    };
    Literal.prototype.toString = function() {
      return ' "' + this.value + '"';
    };
    return Literal;
  })();
  exports.Return = Return = (function() {
    __extends(Return, Base);
    function Return(expr) {
      if (expr && !expr.unwrap().isUndefined) {
        this.expression = expr;
      }
    }
    Return.prototype.children = ['expression'];
    Return.prototype.isStatement = YES;
    Return.prototype.makeReturn = THIS;
    Return.prototype.jumps = THIS;
    Return.prototype.compile = function(o, level) {
      var expr, _ref2;
      expr = (_ref2 = this.expression) != null ? _ref2.makeReturn() : void 0;
      if (expr && !(expr instanceof Return)) {
        return expr.compile(o, level);
      } else {
        return Return.__super__.compile.call(this, o, level);
      }
    };
    Return.prototype.compileNode = function(o) {
      return this.tab + ("return" + (this.expression ? ' ' + this.expression.compile(o, LEVEL_PAREN) : '') + ";");
    };
    return Return;
  })();
  exports.Value = Value = (function() {
    __extends(Value, Base);
    function Value(base, props, tag) {
      if (!props && base instanceof Value) {
        return base;
      }
      this.base = base;
      this.properties = props || [];
      if (tag) {
        this[tag] = true;
      }
      return this;
    }
    Value.prototype.children = ['base', 'properties'];
    Value.prototype.push = function(prop) {
      this.properties.push(prop);
      return this;
    };
    Value.prototype.hasProperties = function() {
      return !!this.properties.length;
    };
    Value.prototype.isArray = function() {
      return !this.properties.length && this.base instanceof Arr;
    };
    Value.prototype.isComplex = function() {
      return this.hasProperties() || this.base.isComplex();
    };
    Value.prototype.isAssignable = function() {
      return this.hasProperties() || this.base.isAssignable();
    };
    Value.prototype.isSimpleNumber = function() {
      return this.base instanceof Literal && SIMPLENUM.test(this.base.value);
    };
    Value.prototype.isAtomic = function() {
      var node, _i, _len, _ref2;
      _ref2 = this.properties.concat(this.base);
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        node = _ref2[_i];
        if (node.soak || node instanceof Call) {
          return false;
        }
      }
      return true;
    };
    Value.prototype.isStatement = function(o) {
      return !this.properties.length && this.base.isStatement(o);
    };
    Value.prototype.assigns = function(name) {
      return !this.properties.length && this.base.assigns(name);
    };
    Value.prototype.jumps = function(o) {
      return !this.properties.length && this.base.jumps(o);
    };
    Value.prototype.isObject = function(onlyGenerated) {
      if (this.properties.length) {
        return false;
      }
      return (this.base instanceof Obj) && (!onlyGenerated || this.base.generated);
    };
    Value.prototype.isSplice = function() {
      return last(this.properties) instanceof Slice;
    };
    Value.prototype.makeReturn = function() {
      if (this.properties.length) {
        return Value.__super__.makeReturn.call(this);
      } else {
        return this.base.makeReturn();
      }
    };
    Value.prototype.unwrap = function() {
      if (this.properties.length) {
        return this;
      } else {
        return this.base;
      }
    };
    Value.prototype.cacheReference = function(o) {
      var base, bref, name, nref;
      name = last(this.properties);
      if (this.properties.length < 2 && !this.base.isComplex() && !(name != null ? name.isComplex() : void 0)) {
        return [this, this];
      }
      base = new Value(this.base, this.properties.slice(0, -1));
      if (base.isComplex()) {
        bref = new Literal(o.scope.freeVariable('base'));
        base = new Value(new Parens(new Assign(bref, base)));
      }
      if (!name) {
        return [base, bref];
      }
      if (name.isComplex()) {
        nref = new Literal(o.scope.freeVariable('name'));
        name = new Index(new Assign(nref, name.index));
        nref = new Index(nref);
      }
      return [base.push(name), new Value(bref || base.base, [nref || name])];
    };
    Value.prototype.compileNode = function(o) {
      var code, prop, props, _i, _len;
      this.base.front = this.front;
      props = this.properties;
      code = this.base.compile(o, props.length ? LEVEL_ACCESS : null);
      if (props[0] instanceof Access && this.isSimpleNumber()) {
        code = "(" + code + ")";
      }
      for (_i = 0, _len = props.length; _i < _len; _i++) {
        prop = props[_i];
        code += prop.compile(o);
      }
      return code;
    };
    Value.prototype.unfoldSoak = function(o) {
      var result;
      if (this.unfoldedSoak != null) {
        return this.unfoldedSoak;
      }
      result = __bind(function() {
        var fst, i, ifn, prop, ref, snd, _len, _ref2;
        if (ifn = this.base.unfoldSoak(o)) {
          Array.prototype.push.apply(ifn.body.properties, this.properties);
          return ifn;
        }
        _ref2 = this.properties;
        for (i = 0, _len = _ref2.length; i < _len; i++) {
          prop = _ref2[i];
          if (prop.soak) {
            prop.soak = false;
            fst = new Value(this.base, this.properties.slice(0, i));
            snd = new Value(this.base, this.properties.slice(i));
            if (fst.isComplex()) {
              ref = new Literal(o.scope.freeVariable('ref'));
              fst = new Parens(new Assign(ref, fst));
              snd.base = ref;
            }
            return new If(new Existence(fst), snd, {
              soak: true
            });
          }
        }
        return null;
      }, this)();
      return this.unfoldedSoak = result || false;
    };
    return Value;
  })();
  exports.Comment = Comment = (function() {
    __extends(Comment, Base);
    function Comment(comment) {
      this.comment = comment;
    }
    Comment.prototype.isStatement = YES;
    Comment.prototype.makeReturn = THIS;
    Comment.prototype.compileNode = function(o, level) {
      var code;
      code = '/*' + multident(this.comment, this.tab) + '*/';
      if ((level || o.level) === LEVEL_TOP) {
        code = o.indent + code;
      }
      return code;
    };
    return Comment;
  })();
  exports.Call = Call = (function() {
    __extends(Call, Base);
    function Call(variable, args, soak) {
      this.args = args != null ? args : [];
      this.soak = soak;
      this.isNew = false;
      this.isSuper = variable === 'super';
      this.variable = this.isSuper ? null : variable;
    }
    Call.prototype.children = ['variable', 'args'];
    Call.prototype.newInstance = function() {
      var base;
      base = this.variable.base || this.variable;
      if (base instanceof Call) {
        base.newInstance();
      } else {
        this.isNew = true;
      }
      return this;
    };
    Call.prototype.superReference = function(o) {
      var method, name;
      method = o.scope.method;
      if (!method) {
        throw SyntaxError('cannot call super outside of a function.');
      }
      name = method.name;
      if (!name) {
        throw SyntaxError('cannot call super on an anonymous function.');
      }
      if (method.klass) {
        return "" + method.klass + ".__super__." + name;
      } else {
        return "" + name + ".__super__.constructor";
      }
    };
    Call.prototype.unfoldSoak = function(o) {
      var call, ifn, left, list, rite, _i, _len, _ref2, _ref3;
      if (this.soak) {
        if (this.variable) {
          if (ifn = unfoldSoak(o, this, 'variable')) {
            return ifn;
          }
          _ref2 = new Value(this.variable).cacheReference(o), left = _ref2[0], rite = _ref2[1];
        } else {
          left = new Literal(this.superReference(o));
          rite = new Value(left);
        }
        rite = new Call(rite, this.args);
        rite.isNew = this.isNew;
        left = new Literal("typeof " + (left.compile(o)) + " === \"function\"");
        return new If(left, new Value(rite), {
          soak: true
        });
      }
      call = this;
      list = [];
      while (true) {
        if (call.variable instanceof Call) {
          list.push(call);
          call = call.variable;
          continue;
        }
        if (!(call.variable instanceof Value)) {
          break;
        }
        list.push(call);
        if (!((call = call.variable.base) instanceof Call)) {
          break;
        }
      }
      _ref3 = list.reverse();
      for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
        call = _ref3[_i];
        if (ifn) {
          if (call.variable instanceof Call) {
            call.variable = ifn;
          } else {
            call.variable.base = ifn;
          }
        }
        ifn = unfoldSoak(o, call, 'variable');
      }
      return ifn;
    };
    Call.prototype.filterImplicitObjects = function(list) {
      var node, nodes, obj, prop, properties, _i, _j, _len, _len2, _ref2;
      nodes = [];
      for (_i = 0, _len = list.length; _i < _len; _i++) {
        node = list[_i];
        if (!((typeof node.isObject === "function" ? node.isObject() : void 0) && node.base.generated)) {
          nodes.push(node);
          continue;
        }
        obj = null;
        _ref2 = node.base.properties;
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          prop = _ref2[_j];
          if (prop instanceof Assign) {
            if (!obj) {
              nodes.push(obj = new Obj(properties = [], true));
            }
            properties.push(prop);
          } else {
            nodes.push(prop);
            obj = null;
          }
        }
      }
      return nodes;
    };
    Call.prototype.compileNode = function(o) {
      var arg, args, code, _ref2;
      if ((_ref2 = this.variable) != null) {
        _ref2.front = this.front;
      }
      if (code = Splat.compileSplattedArray(o, this.args, true)) {
        return this.compileSplat(o, code);
      }
      args = this.filterImplicitObjects(this.args);
      args = ((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = args.length; _i < _len; _i++) {
          arg = args[_i];
          _results.push(arg.compile(o, LEVEL_LIST));
        }
        return _results;
      })()).join(', ');
      if (this.isSuper) {
        return this.superReference(o) + (".call(this" + (args && ', ' + args) + ")");
      } else {
        return (this.isNew ? 'new ' : '') + this.variable.compile(o, LEVEL_ACCESS) + ("(" + args + ")");
      }
    };
    Call.prototype.compileSuper = function(args, o) {
      return "" + (this.superReference(o)) + ".call(this" + (args.length ? ', ' : '') + args + ")";
    };
    Call.prototype.compileSplat = function(o, splatArgs) {
      var base, fun, idt, name, ref;
      if (this.isSuper) {
        return "" + (this.superReference(o)) + ".apply(this, " + splatArgs + ")";
      }
      if (this.isNew) {
        idt = this.tab + TAB;
        return "(function(func, args, ctor) {\n" + idt + "ctor.prototype = func.prototype;\n" + idt + "var child = new ctor, result = func.apply(child, args);\n" + idt + "return typeof result === \"object\" ? result : child;\n" + this.tab + "})(" + (this.variable.compile(o, LEVEL_LIST)) + ", " + splatArgs + ", function() {})";
      }
      base = new Value(this.variable);
      if ((name = base.properties.pop()) && base.isComplex()) {
        ref = o.scope.freeVariable('ref');
        fun = "(" + ref + " = " + (base.compile(o, LEVEL_LIST)) + ")" + (name.compile(o));
      } else {
        fun = base.compile(o, LEVEL_ACCESS);
        if (SIMPLENUM.test(fun)) {
          fun = "(" + fun + ")";
        }
        if (name) {
          ref = fun;
          fun += name.compile(o);
        } else {
          ref = 'null';
        }
      }
      return "" + fun + ".apply(" + ref + ", " + splatArgs + ")";
    };
    return Call;
  })();
  exports.Extends = Extends = (function() {
    __extends(Extends, Base);
    function Extends(child, parent) {
      this.child = child;
      this.parent = parent;
    }
    Extends.prototype.children = ['child', 'parent'];
    Extends.prototype.compile = function(o) {
      utility('hasProp');
      return new Call(new Value(new Literal(utility('extends'))), [this.child, this.parent]).compile(o);
    };
    return Extends;
  })();
  exports.Access = Access = (function() {
    __extends(Access, Base);
    function Access(name, tag) {
      this.name = name;
      this.name.asKey = true;
      this.proto = tag === 'proto' ? '.prototype' : '';
      this.soak = tag === 'soak';
    }
    Access.prototype.children = ['name'];
    Access.prototype.compile = function(o) {
      var name;
      name = this.name.compile(o);
      return this.proto + (IS_STRING.test(name) ? "[" + name + "]" : "." + name);
    };
    Access.prototype.isComplex = NO;
    return Access;
  })();
  exports.Index = Index = (function() {
    __extends(Index, Base);
    function Index(index) {
      this.index = index;
    }
    Index.prototype.children = ['index'];
    Index.prototype.compile = function(o) {
      return (this.proto ? '.prototype' : '') + ("[" + (this.index.compile(o, LEVEL_PAREN)) + "]");
    };
    Index.prototype.isComplex = function() {
      return this.index.isComplex();
    };
    return Index;
  })();
  exports.Range = Range = (function() {
    __extends(Range, Base);
    Range.prototype.children = ['from', 'to'];
    function Range(from, to, tag) {
      this.from = from;
      this.to = to;
      this.exclusive = tag === 'exclusive';
      this.equals = this.exclusive ? '' : '=';
    }
    Range.prototype.compileVariables = function(o) {
      var step, _ref2, _ref3, _ref4, _ref5;
      o = merge(o, {
        top: true
      });
      _ref2 = this.from.cache(o, LEVEL_LIST), this.from = _ref2[0], this.fromVar = _ref2[1];
      _ref3 = this.to.cache(o, LEVEL_LIST), this.to = _ref3[0], this.toVar = _ref3[1];
      if (step = del(o, 'step')) {
        _ref4 = step.cache(o, LEVEL_LIST), this.step = _ref4[0], this.stepVar = _ref4[1];
      }
      _ref5 = [this.fromVar.match(SIMPLENUM), this.toVar.match(SIMPLENUM)], this.fromNum = _ref5[0], this.toNum = _ref5[1];
      if (this.stepVar) {
        return this.stepNum = this.stepVar.match(SIMPLENUM);
      }
    };
    Range.prototype.compileNode = function(o) {
      var cond, condPart, from, gt, idx, known, lt, stepPart, to, varPart, _ref2, _ref3;
      if (!this.fromVar) {
        this.compileVariables(o);
      }
      if (!o.index) {
        return this.compileArray(o);
      }
      known = this.fromNum && this.toNum;
      idx = del(o, 'index');
      varPart = "" + idx + " = " + this.from;
      if (this.to !== this.toVar) {
        varPart += ", " + this.to;
      }
      if (this.step !== this.stepVar) {
        varPart += ", " + this.step;
      }
      _ref2 = ["" + idx + " <" + this.equals, "" + idx + " >" + this.equals], lt = _ref2[0], gt = _ref2[1];
      condPart = this.stepNum ? condPart = +this.stepNum > 0 ? "" + lt + " " + this.toVar : "" + gt + " " + this.toVar : known ? ((_ref3 = [+this.fromNum, +this.toNum], from = _ref3[0], to = _ref3[1], _ref3), condPart = from <= to ? "" + lt + " " + to : "" + gt + " " + to) : (cond = "" + this.fromVar + " <= " + this.toVar, condPart = "" + cond + " ? " + lt + " " + this.toVar + " : " + gt + " " + this.toVar);
      stepPart = this.stepVar ? "" + idx + " += " + this.stepVar : known ? from <= to ? "" + idx + "++" : "" + idx + "--" : "" + cond + " ? " + idx + "++ : " + idx + "--";
      return "" + varPart + "; " + condPart + "; " + stepPart;
    };
    Range.prototype.compileArray = function(o) {
      var body, cond, i, idt, post, pre, range, result, vars, _i, _ref2, _ref3, _results;
      if (this.fromNum && this.toNum && Math.abs(this.fromNum - this.toNum) <= 20) {
        range = (function() {
          _results = [];
          for (var _i = _ref2 = +this.fromNum, _ref3 = +this.toNum; _ref2 <= _ref3 ? _i <= _ref3 : _i >= _ref3; _ref2 <= _ref3 ? _i++ : _i--){ _results.push(_i); }
          return _results;
        }).apply(this, arguments);
        if (this.exclusive) {
          range.pop();
        }
        return "[" + (range.join(', ')) + "]";
      }
      idt = this.tab + TAB;
      i = o.scope.freeVariable('i');
      result = o.scope.freeVariable('results');
      pre = "\n" + idt + result + " = [];";
      if (this.fromNum && this.toNum) {
        o.index = i;
        body = this.compileNode(o);
      } else {
        vars = ("" + i + " = " + this.from) + (this.to !== this.toVar ? ", " + this.to : '');
        cond = "" + this.fromVar + " <= " + this.toVar;
        body = "var " + vars + "; " + cond + " ? " + i + " <" + this.equals + " " + this.toVar + " : " + i + " >" + this.equals + " " + this.toVar + "; " + cond + " ? " + i + "++ : " + i + "--";
      }
      post = "{ " + result + ".push(" + i + "); }\n" + idt + "return " + result + ";\n" + o.indent;
      return "(function() {" + pre + "\n" + idt + "for (" + body + ")" + post + "}).apply(this, arguments)";
    };
    return Range;
  })();
  exports.Slice = Slice = (function() {
    __extends(Slice, Base);
    Slice.prototype.children = ['range'];
    function Slice(range) {
      this.range = range;
      Slice.__super__.constructor.call(this);
    }
    Slice.prototype.compileNode = function(o) {
      var compiled, from, fromStr, to, toStr, _ref2;
      _ref2 = this.range, to = _ref2.to, from = _ref2.from;
      fromStr = from && from.compile(o, LEVEL_PAREN) || '0';
      compiled = to && to.compile(o, LEVEL_PAREN);
      if (to && !(!this.range.exclusive && +compiled === -1)) {
        toStr = ', ' + (this.range.exclusive ? compiled : SIMPLENUM.test(compiled) ? (+compiled + 1).toString() : "(" + compiled + " + 1) || 9e9");
      }
      return ".slice(" + fromStr + (toStr || '') + ")";
    };
    return Slice;
  })();
  exports.Obj = Obj = (function() {
    __extends(Obj, Base);
    function Obj(props, generated) {
      this.generated = generated != null ? generated : false;
      this.objects = this.properties = props || [];
    }
    Obj.prototype.children = ['properties'];
    Obj.prototype.compileNode = function(o) {
      var i, idt, indent, join, lastNoncom, node, obj, prop, props, _i, _len;
      props = this.properties;
      if (!props.length) {
        if (this.front) {
          return '({})';
        } else {
          return '{}';
        }
      }
      if (this.generated) {
        for (_i = 0, _len = props.length; _i < _len; _i++) {
          node = props[_i];
          if (node instanceof Value) {
            throw new Error('cannot have an implicit value in an implicit object');
          }
        }
      }
      idt = o.indent += TAB;
      lastNoncom = this.lastNonComment(this.properties);
      props = (function() {
        var _len2, _results;
        _results = [];
        for (i = 0, _len2 = props.length; i < _len2; i++) {
          prop = props[i];
          join = i === props.length - 1 ? '' : prop === lastNoncom || prop instanceof Comment ? '\n' : ',\n';
          indent = prop instanceof Comment ? '' : idt;
          if (prop instanceof Value && prop["this"]) {
            prop = new Assign(prop.properties[0].name, prop, 'object');
          }
          if (!(prop instanceof Comment)) {
            if (!(prop instanceof Assign)) {
              prop = new Assign(prop, prop, 'object');
            }
            (prop.variable.base || prop.variable).asKey = true;
          }
          _results.push(indent + prop.compile(o, LEVEL_TOP) + join);
        }
        return _results;
      })();
      props = props.join('');
      obj = "{" + (props && '\n' + props + '\n' + this.tab) + "}";
      if (this.front) {
        return "(" + obj + ")";
      } else {
        return obj;
      }
    };
    Obj.prototype.assigns = function(name) {
      var prop, _i, _len, _ref2;
      _ref2 = this.properties;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        prop = _ref2[_i];
        if (prop.assigns(name)) {
          return true;
        }
      }
      return false;
    };
    return Obj;
  })();
  exports.Arr = Arr = (function() {
    __extends(Arr, Base);
    function Arr(objs) {
      this.objects = objs || [];
    }
    Arr.prototype.children = ['objects'];
    Arr.prototype.filterImplicitObjects = Call.prototype.filterImplicitObjects;
    Arr.prototype.compileNode = function(o) {
      var code, obj, objs;
      if (!this.objects.length) {
        return '[]';
      }
      o.indent += TAB;
      objs = this.filterImplicitObjects(this.objects);
      if (code = Splat.compileSplattedArray(o, objs)) {
        return code;
      }
      code = ((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = objs.length; _i < _len; _i++) {
          obj = objs[_i];
          _results.push(obj.compile(o, LEVEL_LIST));
        }
        return _results;
      })()).join(', ');
      if (code.indexOf('\n') >= 0) {
        return "[\n" + o.indent + code + "\n" + this.tab + "]";
      } else {
        return "[" + code + "]";
      }
    };
    Arr.prototype.assigns = function(name) {
      var obj, _i, _len, _ref2;
      _ref2 = this.objects;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        obj = _ref2[_i];
        if (obj.assigns(name)) {
          return true;
        }
      }
      return false;
    };
    return Arr;
  })();
  exports.Class = Class = (function() {
    __extends(Class, Base);
    function Class(variable, parent, body) {
      this.variable = variable;
      this.parent = parent;
      this.body = body != null ? body : new Block;
      this.boundFuncs = [];
      this.body.classBody = true;
    }
    Class.prototype.children = ['variable', 'parent', 'body'];
    Class.prototype.determineName = function() {
      var decl, tail;
      if (!this.variable) {
        return null;
      }
      decl = (tail = last(this.variable.properties)) ? tail instanceof Access && tail.name.value : this.variable.base.value;
      return decl && (decl = IDENTIFIER.test(decl) && decl);
    };
    Class.prototype.setContext = function(name) {
      return this.body.traverseChildren(false, function(node) {
        if (node.classBody) {
          return false;
        }
        if (node instanceof Literal && node.value === 'this') {
          return node.value = name;
        } else if (node instanceof Code) {
          node.klass = name;
          if (node.bound) {
            return node.context = name;
          }
        }
      });
    };
    Class.prototype.addBoundFunctions = function(o) {
      var bname, bvar, _i, _len, _ref2, _results;
      if (this.boundFuncs.length) {
        _ref2 = this.boundFuncs;
        _results = [];
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          bvar = _ref2[_i];
          bname = bvar.compile(o);
          _results.push(this.ctor.body.unshift(new Literal("this." + bname + " = " + (utility('bind')) + "(this." + bname + ", this)")));
        }
        return _results;
      }
    };
    Class.prototype.addProperties = function(node, name, o) {
      var assign, base, exprs, func, props;
      props = node.base.properties.slice(0);
      exprs = (function() {
        var _results;
        _results = [];
        while (assign = props.shift()) {
          if (assign instanceof Assign) {
            base = assign.variable.base;
            delete assign.context;
            func = assign.value;
            if (base.value === 'constructor') {
              if (this.ctor) {
                throw new Error('cannot define more than one constructor in a class');
              }
              if (func.bound) {
                throw new Error('cannot define a constructor as a bound function');
              }
              if (func instanceof Code) {
                assign = this.ctor = func;
              } else {
                this.externalCtor = o.scope.freeVariable('class');
                assign = new Assign(new Literal(this.externalCtor), func);
              }
            } else {
              if (!assign.variable["this"]) {
                assign.variable = new Value(new Literal(name), [new Access(base, 'proto')]);
              }
              if (func instanceof Code && func.bound) {
                this.boundFuncs.push(base);
                func.bound = false;
              }
            }
          }
          _results.push(assign);
        }
        return _results;
      }).call(this);
      return compact(exprs);
    };
    Class.prototype.walkBody = function(name, o) {
      return this.traverseChildren(false, __bind(function(child) {
        var exps, i, node, _len, _ref2;
        if (child instanceof Class) {
          return false;
        }
        if (child instanceof Block) {
          _ref2 = exps = child.expressions;
          for (i = 0, _len = _ref2.length; i < _len; i++) {
            node = _ref2[i];
            if (node instanceof Value && node.isObject(true)) {
              exps[i] = this.addProperties(node, name, o);
            }
          }
          return child.expressions = exps = flatten(exps);
        }
      }, this));
    };
    Class.prototype.ensureConstructor = function(name) {
      if (!this.ctor) {
        this.ctor = new Code;
        if (this.parent) {
          this.ctor.body.push(new Literal("" + name + ".__super__.constructor.apply(this, arguments)"));
        }
        if (this.externalCtor) {
          this.ctor.body.push(new Literal("" + this.externalCtor + ".apply(this, arguments)"));
        }
        this.body.expressions.unshift(this.ctor);
      }
      this.ctor.ctor = this.ctor.name = name;
      this.ctor.klass = null;
      return this.ctor.noReturn = true;
    };
    Class.prototype.compileNode = function(o) {
      var decl, klass, lname, name;
      decl = this.determineName();
      name = decl || this.name || '_Class';
      lname = new Literal(name);
      this.setContext(name);
      this.walkBody(name, o);
      this.ensureConstructor(name);
      if (this.parent) {
        this.body.expressions.unshift(new Extends(lname, this.parent));
      }
      if (!(this.ctor instanceof Code)) {
        this.body.expressions.unshift(this.ctor);
      }
      this.body.expressions.push(lname);
      this.addBoundFunctions(o);
      klass = new Parens(Closure.wrap(this.body), true);
      if (this.variable) {
        klass = new Assign(this.variable, klass);
      }
      return klass.compile(o);
    };
    return Class;
  })();
  exports.Assign = Assign = (function() {
    __extends(Assign, Base);
    function Assign(variable, value, context, options) {
      this.variable = variable;
      this.value = value;
      this.context = context;
      this.param = options && options.param;
    }
    Assign.prototype.children = ['variable', 'value'];
    Assign.prototype.assigns = function(name) {
      return this[this.context === 'object' ? 'value' : 'variable'].assigns(name);
    };
    Assign.prototype.unfoldSoak = function(o) {
      return unfoldSoak(o, this, 'variable');
    };
    Assign.prototype.compileNode = function(o) {
      var isValue, match, name, val, _ref2;
      if (isValue = this.variable instanceof Value) {
        if (this.variable.isArray() || this.variable.isObject()) {
          return this.compilePatternMatch(o);
        }
        if (this.variable.isSplice()) {
          return this.compileSplice(o);
        }
        if ((_ref2 = this.context) === '||=' || _ref2 === '&&=' || _ref2 === '?=') {
          return this.compileConditional(o);
        }
      }
      name = this.variable.compile(o, LEVEL_LIST);
      if (!(this.context || this.variable.isAssignable())) {
        throw SyntaxError("\"" + (this.variable.compile(o)) + "\" cannot be assigned.");
      }
      if (!(this.context || isValue && (this.variable.namespaced || this.variable.hasProperties()))) {
        if (this.param) {
          o.scope.add(name, 'var');
        } else {
          o.scope.find(name);
        }
      }
      if (this.value instanceof Code && (match = METHOD_DEF.exec(name))) {
        this.value.name = match[2];
        if (match[1]) {
          this.value.klass = match[1];
        }
      }
      val = this.value.compile(o, LEVEL_LIST);
      if (this.context === 'object') {
        return "" + name + ": " + val;
      }
      val = name + (" " + (this.context || '=') + " ") + val;
      if (o.level <= LEVEL_LIST) {
        return val;
      } else {
        return "(" + val + ")";
      }
    };
    Assign.prototype.compilePatternMatch = function(o) {
      var acc, assigns, code, i, idx, isObject, ivar, obj, objects, olen, ref, rest, splat, top, val, value, vvar, _len, _ref2, _ref3, _ref4, _ref5;
      top = o.level === LEVEL_TOP;
      value = this.value;
      objects = this.variable.base.objects;
      if (!(olen = objects.length)) {
        code = value.compile(o);
        if (o.level >= LEVEL_OP) {
          return "(" + code + ")";
        } else {
          return code;
        }
      }
      isObject = this.variable.isObject();
      if (top && olen === 1 && !((obj = objects[0]) instanceof Splat)) {
        if (obj instanceof Assign) {
          _ref2 = obj, idx = _ref2.variable.base, obj = _ref2.value;
        } else {
          if (obj.base instanceof Parens) {
            _ref3 = new Value(obj.unwrapAll()).cacheReference(o), obj = _ref3[0], idx = _ref3[1];
          } else {
            idx = isObject ? obj["this"] ? obj.properties[0].name : obj : new Literal(0);
          }
        }
        acc = IDENTIFIER.test(idx.unwrap().value || 0);
        value = new Value(value);
        value.properties.push(new (acc ? Access : Index)(idx));
        return new Assign(obj, value, null, {
          param: this.param
        }).compile(o, LEVEL_TOP);
      }
      vvar = value.compile(o, LEVEL_LIST);
      assigns = [];
      splat = false;
      if (!IDENTIFIER.test(vvar) || this.variable.assigns(vvar)) {
        assigns.push("" + (ref = o.scope.freeVariable('ref')) + " = " + vvar);
        vvar = ref;
      }
      for (i = 0, _len = objects.length; i < _len; i++) {
        obj = objects[i];
        idx = i;
        if (isObject) {
          if (obj instanceof Assign) {
            _ref4 = obj, idx = _ref4.variable.base, obj = _ref4.value;
          } else {
            if (obj.base instanceof Parens) {
              _ref5 = new Value(obj.unwrapAll()).cacheReference(o), obj = _ref5[0], idx = _ref5[1];
            } else {
              idx = obj["this"] ? obj.properties[0].name : obj;
            }
          }
        }
        if (!splat && obj instanceof Splat) {
          val = "" + olen + " <= " + vvar + ".length ? " + (utility('slice')) + ".call(" + vvar + ", " + i;
          if (rest = olen - i - 1) {
            ivar = o.scope.freeVariable('i');
            val += ", " + ivar + " = " + vvar + ".length - " + rest + ") : (" + ivar + " = " + i + ", [])";
          } else {
            val += ") : []";
          }
          val = new Literal(val);
          splat = "" + ivar + "++";
        } else {
          if (obj instanceof Splat) {
            obj = obj.name.compile(o);
            throw SyntaxError("multiple splats are disallowed in an assignment: " + obj + " ...");
          }
          if (typeof idx === 'number') {
            idx = new Literal(splat || idx);
            acc = false;
          } else {
            acc = isObject && IDENTIFIER.test(idx.unwrap().value || 0);
          }
          val = new Value(new Literal(vvar), [new (acc ? Access : Index)(idx)]);
        }
        assigns.push(new Assign(obj, val, null, {
          param: this.param
        }).compile(o, LEVEL_TOP));
      }
      if (!top) {
        assigns.push(vvar);
      }
      code = assigns.join(', ');
      if (o.level < LEVEL_LIST) {
        return code;
      } else {
        return "(" + code + ")";
      }
    };
    Assign.prototype.compileConditional = function(o) {
      var left, rite, _ref2;
      _ref2 = this.variable.cacheReference(o), left = _ref2[0], rite = _ref2[1];
      if (__indexOf.call(this.context, "?") >= 0) {
        o.isExistentialEquals = true;
      }
      return new Op(this.context.slice(0, -1), left, new Assign(rite, this.value, '=')).compile(o);
    };
    Assign.prototype.compileSplice = function(o) {
      var code, exclusive, from, fromDecl, fromRef, name, to, valDef, valRef, _ref2, _ref3, _ref4;
      _ref2 = this.variable.properties.pop().range, from = _ref2.from, to = _ref2.to, exclusive = _ref2.exclusive;
      name = this.variable.compile(o);
      _ref3 = (from != null ? from.cache(o, LEVEL_OP) : void 0) || ['0', '0'], fromDecl = _ref3[0], fromRef = _ref3[1];
      if (to) {
        if ((from != null ? from.isSimpleNumber() : void 0) && to.isSimpleNumber()) {
          to = +to.compile(o) - +fromRef;
          if (!exclusive) {
            to += 1;
          }
        } else {
          to = to.compile(o) + ' - ' + fromRef;
          if (!exclusive) {
            to += ' + 1';
          }
        }
      } else {
        to = "9e9";
      }
      _ref4 = this.value.cache(o, LEVEL_LIST), valDef = _ref4[0], valRef = _ref4[1];
      code = "[].splice.apply(" + name + ", [" + fromDecl + ", " + to + "].concat(" + valDef + ")), " + valRef;
      if (o.level > LEVEL_TOP) {
        return "(" + code + ")";
      } else {
        return code;
      }
    };
    return Assign;
  })();
  exports.Code = Code = (function() {
    __extends(Code, Base);
    function Code(params, body, tag) {
      this.params = params || [];
      this.body = body || new Block;
      this.bound = tag === 'boundfunc';
      if (this.bound) {
        this.context = 'this';
      }
    }
    Code.prototype.children = ['params', 'body'];
    Code.prototype.isStatement = function() {
      return !!this.ctor;
    };
    Code.prototype.jumps = NO;
    Code.prototype.compileNode = function(o) {
      var code, exprs, i, idt, lit, p, param, ref, splats, v, val, vars, wasEmpty, _i, _j, _k, _len, _len2, _len3, _len4, _ref2, _ref3, _ref4, _ref5;
      o.scope = new Scope(o.scope, this.body, this);
      o.scope.shared = del(o, 'sharedScope');
      o.indent += TAB;
      delete o.bare;
      vars = [];
      exprs = [];
      _ref2 = this.params;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        param = _ref2[_i];
        if (param.splat) {
          _ref3 = this.params;
          for (_j = 0, _len2 = _ref3.length; _j < _len2; _j++) {
            p = _ref3[_j];
            if (p.name.value) {
              o.scope.add(p.name.value, 'var', true);
            }
          }
          splats = new Assign(new Value(new Arr((function() {
            var _k, _len3, _ref4, _results;
            _ref4 = this.params;
            _results = [];
            for (_k = 0, _len3 = _ref4.length; _k < _len3; _k++) {
              p = _ref4[_k];
              _results.push(p.asReference(o));
            }
            return _results;
          }).call(this))), new Value(new Literal('arguments')));
          break;
        }
      }
      _ref4 = this.params;
      for (_k = 0, _len3 = _ref4.length; _k < _len3; _k++) {
        param = _ref4[_k];
        if (param.isComplex()) {
          val = ref = param.asReference(o);
          if (param.value) {
            val = new Op('?', ref, param.value);
          }
          exprs.push(new Assign(new Value(param.name), val, '=', {
            param: true
          }));
        } else {
          ref = param;
          if (param.value) {
            lit = new Literal(ref.name.value + ' == null');
            val = new Assign(new Value(param.name), param.value, '=');
            exprs.push(new If(lit, val));
          }
        }
        if (!splats) {
          vars.push(ref);
        }
      }
      wasEmpty = this.body.isEmpty();
      if (splats) {
        exprs.unshift(splats);
      }
      if (exprs.length) {
        (_ref5 = this.body.expressions).unshift.apply(_ref5, exprs);
      }
      if (!splats) {
        for (i = 0, _len4 = vars.length; i < _len4; i++) {
          v = vars[i];
          o.scope.parameter(vars[i] = v.compile(o));
        }
      }
      if (!(wasEmpty || this.noReturn)) {
        this.body.makeReturn();
      }
      idt = o.indent;
      code = 'function';
      if (this.ctor) {
        code += ' ' + this.name;
      }
      code += '(' + vars.join(', ') + ') {';
      if (!this.body.isEmpty()) {
        code += "\n" + (this.body.compileWithDeclarations(o)) + "\n" + this.tab;
      }
      code += '}';
      if (this.ctor) {
        return this.tab + code;
      }
      if (this.bound) {
        return utility('bind') + ("(" + code + ", " + this.context + ")");
      }
      if (this.front || (o.level >= LEVEL_ACCESS)) {
        return "(" + code + ")";
      } else {
        return code;
      }
    };
    Code.prototype.traverseChildren = function(crossScope, func) {
      if (crossScope) {
        return Code.__super__.traverseChildren.call(this, crossScope, func);
      }
    };
    return Code;
  })();
  exports.Param = Param = (function() {
    __extends(Param, Base);
    function Param(name, value, splat) {
      this.name = name;
      this.value = value;
      this.splat = splat;
    }
    Param.prototype.children = ['name', 'value'];
    Param.prototype.compile = function(o) {
      return this.name.compile(o, LEVEL_LIST);
    };
    Param.prototype.asReference = function(o) {
      var node;
      if (this.reference) {
        return this.reference;
      }
      node = this.name;
      if (node["this"]) {
        node = node.properties[0].name;
        if (node.value.reserved) {
          node = new Literal('_' + node.value);
        }
      } else if (node.isComplex()) {
        node = new Literal(o.scope.freeVariable('arg'));
      }
      node = new Value(node);
      if (this.splat) {
        node = new Splat(node);
      }
      return this.reference = node;
    };
    Param.prototype.isComplex = function() {
      return this.name.isComplex();
    };
    return Param;
  })();
  exports.Splat = Splat = (function() {
    __extends(Splat, Base);
    Splat.prototype.children = ['name'];
    Splat.prototype.isAssignable = YES;
    function Splat(name) {
      this.name = name.compile ? name : new Literal(name);
    }
    Splat.prototype.assigns = function(name) {
      return this.name.assigns(name);
    };
    Splat.prototype.compile = function(o) {
      if (this.index != null) {
        return this.compileParam(o);
      } else {
        return this.name.compile(o);
      }
    };
    Splat.compileSplattedArray = function(o, list, apply) {
      var args, base, code, i, index, node, _len;
      index = -1;
      while ((node = list[++index]) && !(node instanceof Splat)) {
        continue;
      }
      if (index >= list.length) {
        return '';
      }
      if (list.length === 1) {
        code = list[0].compile(o, LEVEL_LIST);
        if (apply) {
          return code;
        }
        return "" + (utility('slice')) + ".call(" + code + ")";
      }
      args = list.slice(index);
      for (i = 0, _len = args.length; i < _len; i++) {
        node = args[i];
        code = node.compile(o, LEVEL_LIST);
        args[i] = node instanceof Splat ? "" + (utility('slice')) + ".call(" + code + ")" : "[" + code + "]";
      }
      if (index === 0) {
        return args[0] + (".concat(" + (args.slice(1).join(', ')) + ")");
      }
      base = (function() {
        var _i, _len2, _ref2, _results;
        _ref2 = list.slice(0, index);
        _results = [];
        for (_i = 0, _len2 = _ref2.length; _i < _len2; _i++) {
          node = _ref2[_i];
          _results.push(node.compile(o, LEVEL_LIST));
        }
        return _results;
      })();
      return "[" + (base.join(', ')) + "].concat(" + (args.join(', ')) + ")";
    };
    return Splat;
  })();
  exports.While = While = (function() {
    __extends(While, Base);
    function While(condition, options) {
      this.condition = (options != null ? options.invert : void 0) ? condition.invert() : condition;
      this.guard = options != null ? options.guard : void 0;
    }
    While.prototype.children = ['condition', 'guard', 'body'];
    While.prototype.isStatement = YES;
    While.prototype.makeReturn = function() {
      this.returns = true;
      return this;
    };
    While.prototype.addBody = function(body) {
      this.body = body;
      return this;
    };
    While.prototype.jumps = function() {
      var expressions, node, _i, _len;
      expressions = this.body.expressions;
      if (!expressions.length) {
        return false;
      }
      for (_i = 0, _len = expressions.length; _i < _len; _i++) {
        node = expressions[_i];
        if (node.jumps({
          loop: true
        })) {
          return node;
        }
      }
      return false;
    };
    While.prototype.compileNode = function(o) {
      var body, code, rvar, set;
      o.indent += TAB;
      set = '';
      body = this.body;
      if (body.isEmpty()) {
        body = '';
      } else {
        if (o.level > LEVEL_TOP || this.returns) {
          rvar = o.scope.freeVariable('results');
          set = "" + this.tab + rvar + " = [];\n";
          if (body) {
            body = Push.wrap(rvar, body);
          }
        }
        if (this.guard) {
          body = Block.wrap([new If(this.guard, body)]);
        }
        body = "\n" + (body.compile(o, LEVEL_TOP)) + "\n" + this.tab;
      }
      code = set + this.tab + ("while (" + (this.condition.compile(o, LEVEL_PAREN)) + ") {" + body + "}");
      if (this.returns) {
        code += "\n" + this.tab + "return " + rvar + ";";
      }
      return code;
    };
    return While;
  })();
  exports.Op = Op = (function() {
    var CONVERSIONS, INVERSIONS;
    __extends(Op, Base);
    function Op(op, first, second, flip) {
      var call;
      if (op === 'in') {
        return new In(first, second);
      }
      if (op === 'do') {
        call = new Call(first, first.params || []);
        call["do"] = true;
        return call;
      }
      if (op === 'new') {
        if (first instanceof Call && !first["do"]) {
          return first.newInstance();
        }
        if (first instanceof Code && first.bound || first["do"]) {
          first = new Parens(first);
        }
      }
      this.operator = CONVERSIONS[op] || op;
      this.first = first;
      this.second = second;
      this.flip = !!flip;
      return this;
    }
    CONVERSIONS = {
      '==': '===',
      '!=': '!==',
      'of': 'in'
    };
    INVERSIONS = {
      '!==': '===',
      '===': '!=='
    };
    Op.prototype.children = ['first', 'second'];
    Op.prototype.isSimpleNumber = NO;
    Op.prototype.isUnary = function() {
      return !this.second;
    };
    Op.prototype.isComplex = function() {
      var _ref2;
      return !(this.isUnary() && ((_ref2 = this.operator) === '+' || _ref2 === '-')) || this.first.isComplex();
    };
    Op.prototype.isChainable = function() {
      var _ref2;
      return (_ref2 = this.operator) === '<' || _ref2 === '>' || _ref2 === '>=' || _ref2 === '<=' || _ref2 === '===' || _ref2 === '!==';
    };
    Op.prototype.invert = function() {
      var allInvertable, curr, fst, op, _ref2;
      if (this.isChainable() && this.first.isChainable()) {
        allInvertable = true;
        curr = this;
        while (curr && curr.operator) {
          allInvertable && (allInvertable = curr.operator in INVERSIONS);
          curr = curr.first;
        }
        if (!allInvertable) {
          return new Parens(this).invert();
        }
        curr = this;
        while (curr && curr.operator) {
          curr.invert = !curr.invert;
          curr.operator = INVERSIONS[curr.operator];
          curr = curr.first;
        }
        return this;
      } else if (op = INVERSIONS[this.operator]) {
        this.operator = op;
        if (this.first.unwrap() instanceof Op) {
          this.first.invert();
        }
        return this;
      } else if (this.second) {
        return new Parens(this).invert();
      } else if (this.operator === '!' && (fst = this.first.unwrap()) instanceof Op && ((_ref2 = fst.operator) === '!' || _ref2 === 'in' || _ref2 === 'instanceof')) {
        return fst;
      } else {
        return new Op('!', this);
      }
    };
    Op.prototype.unfoldSoak = function(o) {
      var _ref2;
      return ((_ref2 = this.operator) === '++' || _ref2 === '--' || _ref2 === 'delete') && unfoldSoak(o, this, 'first');
    };
    Op.prototype.compileNode = function(o) {
      var code;
      if (this.isUnary()) {
        return this.compileUnary(o);
      }
      if (this.isChainable() && this.first.isChainable()) {
        return this.compileChain(o);
      }
      if (this.operator === '?') {
        return this.compileExistence(o);
      }
      this.first.front = this.front;
      code = this.first.compile(o, LEVEL_OP) + ' ' + this.operator + ' ' + this.second.compile(o, LEVEL_OP);
      if (o.level <= LEVEL_OP) {
        return code;
      } else {
        return "(" + code + ")";
      }
    };
    Op.prototype.compileChain = function(o) {
      var code, fst, shared, _ref2;
      _ref2 = this.first.second.cache(o), this.first.second = _ref2[0], shared = _ref2[1];
      fst = this.first.compile(o, LEVEL_OP);
      code = "" + fst + " " + (this.invert ? '&&' : '||') + " " + (shared.compile(o)) + " " + this.operator + " " + (this.second.compile(o, LEVEL_OP));
      return "(" + code + ")";
    };
    Op.prototype.compileExistence = function(o) {
      var fst, ref;
      if (this.first.isComplex()) {
        ref = new Literal(o.scope.freeVariable('ref'));
        fst = new Parens(new Assign(ref, this.first));
      } else {
        fst = this.first;
        ref = fst;
      }
      return new If(new Existence(fst), ref, {
        type: 'if'
      }).addElse(this.second).compile(o);
    };
    Op.prototype.compileUnary = function(o) {
      var op, parts;
      parts = [op = this.operator];
      if ((op === 'new' || op === 'typeof' || op === 'delete') || (op === '+' || op === '-') && this.first instanceof Op && this.first.operator === op) {
        parts.push(' ');
      }
      if (op === 'new' && this.first.isStatement(o)) {
        this.first = new Parens(this.first);
      }
      parts.push(this.first.compile(o, LEVEL_OP));
      if (this.flip) {
        parts.reverse();
      }
      return parts.join('');
    };
    Op.prototype.toString = function(idt) {
      return Op.__super__.toString.call(this, idt, this.constructor.name + ' ' + this.operator);
    };
    return Op;
  })();
  exports.In = In = (function() {
    __extends(In, Base);
    function In(object, array) {
      this.object = object;
      this.array = array;
    }
    In.prototype.children = ['object', 'array'];
    In.prototype.invert = NEGATE;
    In.prototype.compileNode = function(o) {
      var hasSplat, obj, _i, _len, _ref2;
      if (this.array instanceof Value && this.array.isArray()) {
        _ref2 = this.array.base.objects;
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          obj = _ref2[_i];
          if (obj instanceof Splat) {
            hasSplat = true;
            break;
          }
        }
        if (!hasSplat) {
          return this.compileOrTest(o);
        }
      }
      return this.compileLoopTest(o);
    };
    In.prototype.compileOrTest = function(o) {
      var cmp, cnj, i, item, ref, sub, tests, _ref2, _ref3;
      _ref2 = this.object.cache(o, LEVEL_OP), sub = _ref2[0], ref = _ref2[1];
      _ref3 = this.negated ? [' !== ', ' && '] : [' === ', ' || '], cmp = _ref3[0], cnj = _ref3[1];
      tests = (function() {
        var _len, _ref4, _results;
        _ref4 = this.array.base.objects;
        _results = [];
        for (i = 0, _len = _ref4.length; i < _len; i++) {
          item = _ref4[i];
          _results.push((i ? ref : sub) + cmp + item.compile(o, LEVEL_OP));
        }
        return _results;
      }).call(this);
      if (tests.length === 0) {
        return 'false';
      }
      tests = tests.join(cnj);
      if (o.level < LEVEL_OP) {
        return tests;
      } else {
        return "(" + tests + ")";
      }
    };
    In.prototype.compileLoopTest = function(o) {
      var code, ref, sub, _ref2;
      _ref2 = this.object.cache(o, LEVEL_LIST), sub = _ref2[0], ref = _ref2[1];
      code = utility('indexOf') + (".call(" + (this.array.compile(o, LEVEL_LIST)) + ", " + ref + ") ") + (this.negated ? '< 0' : '>= 0');
      if (sub === ref) {
        return code;
      }
      code = sub + ', ' + code;
      if (o.level < LEVEL_LIST) {
        return code;
      } else {
        return "(" + code + ")";
      }
    };
    In.prototype.toString = function(idt) {
      return In.__super__.toString.call(this, idt, this.constructor.name + (this.negated ? '!' : ''));
    };
    return In;
  })();
  exports.Try = Try = (function() {
    __extends(Try, Base);
    function Try(attempt, error, recovery, ensure) {
      this.attempt = attempt;
      this.error = error;
      this.recovery = recovery;
      this.ensure = ensure;
    }
    Try.prototype.children = ['attempt', 'recovery', 'ensure'];
    Try.prototype.isStatement = YES;
    Try.prototype.jumps = function(o) {
      var _ref2;
      return this.attempt.jumps(o) || ((_ref2 = this.recovery) != null ? _ref2.jumps(o) : void 0);
    };
    Try.prototype.makeReturn = function() {
      if (this.attempt) {
        this.attempt = this.attempt.makeReturn();
      }
      if (this.recovery) {
        this.recovery = this.recovery.makeReturn();
      }
      return this;
    };
    Try.prototype.compileNode = function(o) {
      var catchPart, errorPart;
      o.indent += TAB;
      errorPart = this.error ? " (" + (this.error.compile(o)) + ") " : ' ';
      catchPart = this.recovery ? " catch" + errorPart + "{\n" + (this.recovery.compile(o, LEVEL_TOP)) + "\n" + this.tab + "}" : !(this.ensure || this.recovery) ? ' catch (_e) {}' : void 0;
      return ("" + this.tab + "try {\n" + (this.attempt.compile(o, LEVEL_TOP)) + "\n" + this.tab + "}" + (catchPart || '')) + (this.ensure ? " finally {\n" + (this.ensure.compile(o, LEVEL_TOP)) + "\n" + this.tab + "}" : '');
    };
    return Try;
  })();
  exports.Throw = Throw = (function() {
    __extends(Throw, Base);
    function Throw(expression) {
      this.expression = expression;
    }
    Throw.prototype.children = ['expression'];
    Throw.prototype.isStatement = YES;
    Throw.prototype.jumps = NO;
    Throw.prototype.makeReturn = THIS;
    Throw.prototype.compileNode = function(o) {
      return this.tab + ("throw " + (this.expression.compile(o)) + ";");
    };
    return Throw;
  })();
  exports.Existence = Existence = (function() {
    __extends(Existence, Base);
    function Existence(expression) {
      this.expression = expression;
    }
    Existence.prototype.children = ['expression'];
    Existence.prototype.invert = NEGATE;
    Existence.prototype.compileNode = function(o) {
      var cmp, cnj, code, _ref2;
      code = this.expression.compile(o, LEVEL_OP);
      code = IDENTIFIER.test(code) && !o.scope.check(code) ? ((_ref2 = this.negated ? ['===', '||'] : ['!==', '&&'], cmp = _ref2[0], cnj = _ref2[1], _ref2), "typeof " + code + " " + cmp + " \"undefined\" " + cnj + " " + code + " " + cmp + " null") : "" + code + " " + (this.negated ? '==' : '!=') + " null";
      if (o.level <= LEVEL_COND) {
        return code;
      } else {
        return "(" + code + ")";
      }
    };
    return Existence;
  })();
  exports.Parens = Parens = (function() {
    __extends(Parens, Base);
    function Parens(body) {
      this.body = body;
    }
    Parens.prototype.children = ['body'];
    Parens.prototype.unwrap = function() {
      return this.body;
    };
    Parens.prototype.isComplex = function() {
      return this.body.isComplex();
    };
    Parens.prototype.makeReturn = function() {
      return this.body.makeReturn();
    };
    Parens.prototype.compileNode = function(o) {
      var bare, code, expr;
      expr = this.body.unwrap();
      if (expr instanceof Value && expr.isAtomic()) {
        expr.front = this.front;
        return expr.compile(o);
      }
      code = expr.compile(o, LEVEL_PAREN);
      bare = o.level < LEVEL_OP && (expr instanceof Op || expr instanceof Call || (expr instanceof For && expr.returns));
      if (bare) {
        return code;
      } else {
        return "(" + code + ")";
      }
    };
    return Parens;
  })();
  exports.For = For = (function() {
    __extends(For, Base);
    function For(body, source) {
      var _ref2;
      this.source = source.source, this.guard = source.guard, this.step = source.step, this.name = source.name, this.index = source.index;
      this.body = Block.wrap([body]);
      this.own = !!source.own;
      this.object = !!source.object;
      if (this.object) {
        _ref2 = [this.index, this.name], this.name = _ref2[0], this.index = _ref2[1];
      }
      if (this.index instanceof Value) {
        throw SyntaxError('index cannot be a pattern matching expression');
      }
      this.range = this.source instanceof Value && this.source.base instanceof Range && !this.source.properties.length;
      this.pattern = this.name instanceof Value;
      if (this.range && this.index) {
        throw SyntaxError('indexes do not apply to range loops');
      }
      if (this.range && this.pattern) {
        throw SyntaxError('cannot pattern match over range loops');
      }
      this.returns = false;
    }
    For.prototype.children = ['body', 'source', 'guard', 'step'];
    For.prototype.isStatement = YES;
    For.prototype.jumps = While.prototype.jumps;
    For.prototype.makeReturn = function() {
      this.returns = true;
      return this;
    };
    For.prototype.compileNode = function(o) {
      var body, defPart, forPart, forVarPart, guardPart, idt1, index, ivar, lastJumps, lvar, name, namePart, ref, resultPart, returnResult, rvar, scope, source, stepPart, stepvar, svar, varPart, _ref2;
      body = Block.wrap([this.body]);
      lastJumps = (_ref2 = last(body.expressions)) != null ? _ref2.jumps() : void 0;
      if (lastJumps && lastJumps instanceof Return) {
        this.returns = false;
      }
      source = this.range ? this.source.base : this.source;
      scope = o.scope;
      name = this.name && this.name.compile(o, LEVEL_LIST);
      index = this.index && this.index.compile(o, LEVEL_LIST);
      if (name && !this.pattern) {
        scope.find(name, {
          immediate: true
        });
      }
      if (index) {
        scope.find(index, {
          immediate: true
        });
      }
      if (this.returns) {
        rvar = scope.freeVariable('results');
      }
      ivar = (this.range ? name : index) || scope.freeVariable('i');
      if (this.step && !this.range) {
        stepvar = scope.freeVariable("step");
      }
      if (this.pattern) {
        name = ivar;
      }
      varPart = '';
      guardPart = '';
      defPart = '';
      idt1 = this.tab + TAB;
      if (this.range) {
        forPart = source.compile(merge(o, {
          index: ivar,
          step: this.step
        }));
      } else {
        svar = this.source.compile(o, LEVEL_LIST);
        if ((name || this.own) && !IDENTIFIER.test(svar)) {
          defPart = "" + this.tab + (ref = scope.freeVariable('ref')) + " = " + svar + ";\n";
          svar = ref;
        }
        if (name && !this.pattern) {
          namePart = "" + name + " = " + svar + "[" + ivar + "]";
        }
        if (!this.object) {
          lvar = scope.freeVariable('len');
          forVarPart = ("" + ivar + " = 0, " + lvar + " = " + svar + ".length") + (this.step ? ", " + stepvar + " = " + (this.step.compile(o, LEVEL_OP)) : '');
          stepPart = this.step ? "" + ivar + " += " + stepvar : "" + ivar + "++";
          forPart = "" + forVarPart + "; " + ivar + " < " + lvar + "; " + stepPart;
        }
      }
      if (this.returns) {
        resultPart = "" + this.tab + rvar + " = [];\n";
        returnResult = "\n" + this.tab + "return " + rvar + ";";
        body = Push.wrap(rvar, body);
      }
      if (this.guard) {
        body = Block.wrap([new If(this.guard, body)]);
      }
      if (this.pattern) {
        body.expressions.unshift(new Assign(this.name, new Literal("" + svar + "[" + ivar + "]")));
      }
      defPart += this.pluckDirectCall(o, body);
      if (namePart) {
        varPart = "\n" + idt1 + namePart + ";";
      }
      if (this.object) {
        forPart = "" + ivar + " in " + svar;
        if (this.own) {
          guardPart = "\n" + idt1 + "if (!" + (utility('hasProp')) + ".call(" + svar + ", " + ivar + ")) continue;";
        }
      }
      body = body.compile(merge(o, {
        indent: idt1
      }), LEVEL_TOP);
      if (body) {
        body = '\n' + body + '\n';
      }
      return "" + defPart + (resultPart || '') + this.tab + "for (" + forPart + ") {" + guardPart + varPart + body + this.tab + "}" + (returnResult || '');
    };
    For.prototype.pluckDirectCall = function(o, body) {
      var base, defs, expr, fn, idx, ref, val, _len, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7;
      defs = '';
      _ref2 = body.expressions;
      for (idx = 0, _len = _ref2.length; idx < _len; idx++) {
        expr = _ref2[idx];
        expr = expr.unwrapAll();
        if (!(expr instanceof Call)) {
          continue;
        }
        val = expr.variable.unwrapAll();
        if (!((val instanceof Code) || (val instanceof Value && ((_ref3 = val.base) != null ? _ref3.unwrapAll() : void 0) instanceof Code && val.properties.length === 1 && ((_ref4 = (_ref5 = val.properties[0].name) != null ? _ref5.value : void 0) === 'call' || _ref4 === 'apply')))) {
          continue;
        }
        fn = ((_ref6 = val.base) != null ? _ref6.unwrapAll() : void 0) || val;
        ref = new Literal(o.scope.freeVariable('fn'));
        base = new Value(ref);
        if (val.base) {
          _ref7 = [base, val], val.base = _ref7[0], base = _ref7[1];
          args.unshift(new Literal('this'));
        }
        body.expressions[idx] = new Call(base, expr.args);
        defs += this.tab + new Assign(ref, fn).compile(o, LEVEL_TOP) + ';\n';
      }
      return defs;
    };
    return For;
  })();
  exports.Switch = Switch = (function() {
    __extends(Switch, Base);
    function Switch(subject, cases, otherwise) {
      this.subject = subject;
      this.cases = cases;
      this.otherwise = otherwise;
    }
    Switch.prototype.children = ['subject', 'cases', 'otherwise'];
    Switch.prototype.isStatement = YES;
    Switch.prototype.jumps = function(o) {
      var block, conds, _i, _len, _ref2, _ref3, _ref4;
      if (o == null) {
        o = {
          block: true
        };
      }
      _ref2 = this.cases;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        _ref3 = _ref2[_i], conds = _ref3[0], block = _ref3[1];
        if (block.jumps(o)) {
          return block;
        }
      }
      return (_ref4 = this.otherwise) != null ? _ref4.jumps(o) : void 0;
    };
    Switch.prototype.makeReturn = function() {
      var pair, _i, _len, _ref2, _ref3;
      _ref2 = this.cases;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        pair = _ref2[_i];
        pair[1].makeReturn();
      }
      if ((_ref3 = this.otherwise) != null) {
        _ref3.makeReturn();
      }
      return this;
    };
    Switch.prototype.compileNode = function(o) {
      var block, body, code, cond, conditions, expr, i, idt1, idt2, _i, _len, _len2, _ref2, _ref3, _ref4, _ref5;
      idt1 = o.indent + TAB;
      idt2 = o.indent = idt1 + TAB;
      code = this.tab + ("switch (" + (((_ref2 = this.subject) != null ? _ref2.compile(o, LEVEL_PAREN) : void 0) || false) + ") {\n");
      _ref3 = this.cases;
      for (i = 0, _len = _ref3.length; i < _len; i++) {
        _ref4 = _ref3[i], conditions = _ref4[0], block = _ref4[1];
        _ref5 = flatten([conditions]);
        for (_i = 0, _len2 = _ref5.length; _i < _len2; _i++) {
          cond = _ref5[_i];
          if (!this.subject) {
            cond = cond.invert();
          }
          code += idt1 + ("case " + (cond.compile(o, LEVEL_PAREN)) + ":\n");
        }
        if (body = block.compile(o, LEVEL_TOP)) {
          code += body + '\n';
        }
        if (i === this.cases.length - 1 && !this.otherwise) {
          break;
        }
        expr = this.lastNonComment(block.expressions);
        if (expr instanceof Return || (expr instanceof Literal && expr.jumps() && expr.value !== 'debugger')) {
          continue;
        }
        code += idt2 + 'break;\n';
      }
      if (this.otherwise && this.otherwise.expressions.length) {
        code += idt1 + ("default:\n" + (this.otherwise.compile(o, LEVEL_TOP)) + "\n");
      }
      return code + this.tab + '}';
    };
    return Switch;
  })();
  exports.If = If = (function() {
    __extends(If, Base);
    function If(condition, body, options) {
      this.body = body;
      if (options == null) {
        options = {};
      }
      this.condition = options.type === 'unless' ? condition.invert() : condition;
      this.elseBody = null;
      this.isChain = false;
      this.soak = options.soak;
    }
    If.prototype.children = ['condition', 'body', 'elseBody'];
    If.prototype.bodyNode = function() {
      var _ref2;
      return (_ref2 = this.body) != null ? _ref2.unwrap() : void 0;
    };
    If.prototype.elseBodyNode = function() {
      var _ref2;
      return (_ref2 = this.elseBody) != null ? _ref2.unwrap() : void 0;
    };
    If.prototype.addElse = function(elseBody) {
      if (this.isChain) {
        this.elseBodyNode().addElse(elseBody);
      } else {
        this.isChain = elseBody instanceof If;
        this.elseBody = this.ensureBlock(elseBody);
      }
      return this;
    };
    If.prototype.isStatement = function(o) {
      var _ref2;
      return (o != null ? o.level : void 0) === LEVEL_TOP || this.bodyNode().isStatement(o) || ((_ref2 = this.elseBodyNode()) != null ? _ref2.isStatement(o) : void 0);
    };
    If.prototype.jumps = function(o) {
      var _ref2;
      return this.body.jumps(o) || ((_ref2 = this.elseBody) != null ? _ref2.jumps(o) : void 0);
    };
    If.prototype.compileNode = function(o) {
      if (this.isStatement(o)) {
        return this.compileStatement(o);
      } else {
        return this.compileExpression(o);
      }
    };
    If.prototype.makeReturn = function() {
      this.body && (this.body = new Block([this.body.makeReturn()]));
      this.elseBody && (this.elseBody = new Block([this.elseBody.makeReturn()]));
      return this;
    };
    If.prototype.ensureBlock = function(node) {
      if (node instanceof Block) {
        return node;
      } else {
        return new Block([node]);
      }
    };
    If.prototype.compileStatement = function(o) {
      var body, child, cond, exeq, ifPart;
      child = del(o, 'chainChild');
      exeq = del(o, 'isExistentialEquals');
      if (exeq) {
        return new If(this.condition.invert(), this.elseBodyNode(), {
          type: 'if'
        }).compile(o);
      }
      cond = this.condition.compile(o, LEVEL_PAREN);
      o.indent += TAB;
      body = this.ensureBlock(this.body).compile(o);
      if (body) {
        body = "\n" + body + "\n" + this.tab;
      }
      ifPart = "if (" + cond + ") {" + body + "}";
      if (!child) {
        ifPart = this.tab + ifPart;
      }
      if (!this.elseBody) {
        return ifPart;
      }
      return ifPart + ' else ' + (this.isChain ? (o.indent = this.tab, o.chainChild = true, this.elseBody.unwrap().compile(o, LEVEL_TOP)) : "{\n" + (this.elseBody.compile(o, LEVEL_TOP)) + "\n" + this.tab + "}");
    };
    If.prototype.compileExpression = function(o) {
      var alt, body, code, cond;
      cond = this.condition.compile(o, LEVEL_COND);
      body = this.bodyNode().compile(o, LEVEL_LIST);
      alt = this.elseBodyNode() ? this.elseBodyNode().compile(o, LEVEL_LIST) : 'void 0';
      code = "" + cond + " ? " + body + " : " + alt;
      if (o.level >= LEVEL_COND) {
        return "(" + code + ")";
      } else {
        return code;
      }
    };
    If.prototype.unfoldSoak = function() {
      return this.soak && this;
    };
    return If;
  })();
  Push = {
    wrap: function(name, exps) {
      if (exps.isEmpty() || last(exps.expressions).jumps()) {
        return exps;
      }
      return exps.push(new Call(new Value(new Literal(name), [new Access(new Literal('push'))]), [exps.pop()]));
    }
  };
  Closure = {
    wrap: function(expressions, statement, noReturn) {
      var args, call, func, mentionsArgs, meth;
      if (expressions.jumps()) {
        return expressions;
      }
      func = new Code([], Block.wrap([expressions]));
      args = [];
      if ((mentionsArgs = expressions.contains(this.literalArgs)) || expressions.contains(this.literalThis)) {
        meth = new Literal(mentionsArgs ? 'apply' : 'call');
        args = [new Literal('this')];
        if (mentionsArgs) {
          args.push(new Literal('arguments'));
        }
        func = new Value(func, [new Access(meth)]);
      }
      func.noReturn = noReturn;
      call = new Call(func, args);
      if (statement) {
        return Block.wrap([call]);
      } else {
        return call;
      }
    },
    literalArgs: function(node) {
      return node instanceof Literal && node.value === 'arguments' && !node.asKey;
    },
    literalThis: function(node) {
      return (node instanceof Literal && node.value === 'this' && !node.asKey) || (node instanceof Code && node.bound);
    }
  };
  unfoldSoak = function(o, parent, name) {
    var ifn;
    if (!(ifn = parent[name].unfoldSoak(o))) {
      return;
    }
    parent[name] = ifn.body;
    ifn.body = new Value(parent);
    return ifn;
  };
  UTILITIES = {
    "extends": 'function(child, parent) {\n  for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }\n  function ctor() { this.constructor = child; }\n  ctor.prototype = parent.prototype;\n  child.prototype = new ctor;\n  child.__super__ = parent.prototype;\n  return child;\n}',
    bind: 'function(fn, me){ return function(){ return fn.apply(me, arguments); }; }',
    indexOf: 'Array.prototype.indexOf || function(item) {\n  for (var i = 0, l = this.length; i < l; i++) {\n    if (this[i] === item) return i;\n  }\n  return -1;\n}',
    hasProp: 'Object.prototype.hasOwnProperty',
    slice: 'Array.prototype.slice'
  };
  LEVEL_TOP = 1;
  LEVEL_PAREN = 2;
  LEVEL_LIST = 3;
  LEVEL_COND = 4;
  LEVEL_OP = 5;
  LEVEL_ACCESS = 6;
  TAB = '  ';
  IDENTIFIER = /^[$A-Za-z_\x7f-\uffff][$\w\x7f-\uffff]*$/;
  SIMPLENUM = /^[+-]?\d+$/;
  METHOD_DEF = /^(?:([$A-Za-z_][$\w\x7f-\uffff]*)\.prototype\.)?([$A-Za-z_][$\w\x7f-\uffff]*)$/;
  IS_STRING = /^['"]/;
  utility = function(name) {
    var ref;
    ref = "__" + name;
    Scope.root.assign(ref, UTILITIES[name]);
    return ref;
  };
  multident = function(code, tab) {
    return code.replace(/\n/g, '$&' + tab);
  };
});
