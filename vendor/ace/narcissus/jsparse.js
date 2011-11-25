/* -*- Mode: JS; tab-width: 4; indent-tabs-mode: nil; -*-
 * vim: set sw=4 ts=4 et tw=78:
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the Narcissus JavaScript engine.
 *
 * The Initial Developer of the Original Code is
 * Brendan Eich <brendan@mozilla.org>.
 * Portions created by the Initial Developer are Copyright (C) 2004
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Tom Austin <taustin@ucsc.edu>
 *   Brendan Eich <brendan@mozilla.org>
 *   Shu-Yu Guo <shu@rfrn.org>
 *   Dave Herman <dherman@mozilla.com>
 *   Dimitris Vardoulakis <dimvar@ccs.neu.edu>
 *   Patrick Walton <pcwalton@mozilla.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

/*
 * Narcissus - JS implemented in JS.
 *
 * Parser.
 */

define(function(require, exports, module) {

    var lexer = require("./jslex");
    var definitions = require("./jsdefs");

    const StringMap = definitions.StringMap;
    const Stack = definitions.Stack;

    // Set constants in the local scope.
    eval(definitions.consts);

    // Banned statement types by language version.
    const blackLists = { 160: {}, 185: {}, harmony: {} };
    blackLists[160][IMPORT] = true;
    blackLists[160][EXPORT] = true;
    blackLists[160][LET] = true;
    blackLists[160][MODULE] = true;
    blackLists[160][YIELD] = true;
    blackLists[185][IMPORT] = true;
    blackLists[185][EXPORT] = true;
    blackLists[185][MODULE] = true;
    blackLists.harmony[WITH] = true;

    /*
     * pushDestructuringVarDecls :: (node, hoisting node) -> void
     *
     * Recursively add all destructured declarations to varDecls.
     */
    function pushDestructuringVarDecls(n, s) {
        for (var i in n) {
            var sub = n[i];
            if (sub.type === IDENTIFIER) {
                s.varDecls.push(sub);
            } else {
                pushDestructuringVarDecls(sub, s);
            }
        }
    }

    function StaticContext(parentScript, parentBlock, inModule, inFunction) {
        this.parentScript = parentScript;
        this.parentBlock = parentBlock || parentScript;
        this.inModule = inModule || false;
        this.inFunction = inFunction || false;
        this.inForLoopInit = false;
        this.topLevel = true;
        this.allLabels = new Stack();
        this.currentLabels = new Stack();
        this.labeledTargets = new Stack();
        this.defaultLoopTarget = null;
        this.defaultTarget = null;
        this.blackList = blackLists[Narcissus.options.version];
        Narcissus.options.ecma3OnlyMode && (this.ecma3OnlyMode = true);
        Narcissus.options.parenFreeMode && (this.parenFreeMode = true);
    }

    StaticContext.prototype = {
        ecma3OnlyMode: false,
        parenFreeMode: false,
        // non-destructive update via prototype extension
        update: function(ext) {
            var desc = {};
            for (var key in ext) {
                desc[key] = {
                    value: ext[key],
                    writable: true,
                    enumerable: true,
                    configurable: true
                }
            }
            return Object.create(this, desc);
        },
        pushLabel: function(label) {
            return this.update({ currentLabels: this.currentLabels.push(label),
                                 allLabels: this.allLabels.push(label) });
        },
        pushTarget: function(target) {
            var isDefaultLoopTarget = target.isLoop;
            var isDefaultTarget = isDefaultLoopTarget || target.type === SWITCH;

            if (this.currentLabels.isEmpty()) {
                if (isDefaultLoopTarget) this.update({ defaultLoopTarget: target });
                if (isDefaultTarget) this.update({ defaultTarget: target });
                return this;
            }

            target.labels = new StringMap();
            this.currentLabels.forEach(function(label) {
                target.labels.set(label, true);
            });
            return this.update({ currentLabels: new Stack(),
                                 labeledTargets: this.labeledTargets.push(target),
                                 defaultLoopTarget: isDefaultLoopTarget
                                                    ? target
                                                    : this.defaultLoopTarget,
                                 defaultTarget: isDefaultTarget
                                                ? target
                                                : this.defaultTarget });
        },
        nest: function() {
            return this.topLevel ? this.update({ topLevel: false }) : this;
        },
        allow: function(type) {
            switch (type) {
              case EXPORT:
                if (!this.inModule || this.inFunction || !this.topLevel)
                    return false;
                // FALL THROUGH

              case IMPORT:
                return !this.inFunction && this.topLevel;

              case MODULE:
                return !this.inFunction && this.topLevel;

              default:
                return true;
            }
        }
    };

    /*
     * Script :: (tokenizer, boolean, boolean) -> node
     *
     * Parses the toplevel and module/function bodies.
     */
    function Script(t, inModule, inFunction) {
        var n = new Node(t, scriptInit());
        Statements(t, new StaticContext(n, n, inModule, inFunction), n);
        return n;
    }

    // We extend Array slightly with a top-of-stack method.
    definitions.defineProperty(Array.prototype, "top",
                               function() {
                                   return this.length && this[this.length-1];
                               }, false, false, true);

    /*
     * Node :: (tokenizer, optional init object) -> node
     */
    function Node(t, init) {
        var token = t.token;
        if (token) {
            // If init.type exists it will override token.type.
            this.type = token.type;
            this.value = token.value;
            this.lineno = token.lineno;

            // Start and end are file positions for error handling.
            this.start = token.start;
            this.end = token.end;
        } else {
            this.lineno = t.lineno;
        }

        // Node uses a tokenizer for debugging (getSource, filename getter).
        this.tokenizer = t;
        this.children = [];

        for (var prop in init)
            this[prop] = init[prop];
    }

    /*
     * SyntheticNode :: (tokenizer, optional init object) -> node
     */
    function SyntheticNode(t, init) {
        // print("SYNTHETIC NODE");
        // if (init.type === COMMA) {
        //     print("SYNTHETIC COMMA");
        //     print(init);
        // }
        this.tokenizer = t;
        this.children = [];
        for (var prop in init)
            this[prop] = init[prop];
        this.synthetic = true;
    }

    var Np = Node.prototype = SyntheticNode.prototype = {};
    Np.constructor = Node;

    const TO_SOURCE_SKIP = {
        type: true,
        value: true,
        lineno: true,
        start: true,
        end: true,
        tokenizer: true,
        assignOp: true
    };
    function unevalableConst(code) {
        var token = definitions.tokens[code];
        var constName = definitions.opTypeNames.hasOwnProperty(token)
                      ? definitions.opTypeNames[token]
                      : token in definitions.keywords
                      ? token.toUpperCase()
                      : token;
        return { toSource: function() { return constName } };
    }
    Np.toSource = function toSource() {
        var mock = {};
        var self = this;
        mock.type = unevalableConst(this.type);
        if ("value" in this)
            mock.value = this.value;
        if ("lineno" in this)
            mock.lineno = this.lineno;
        if ("start" in this)
            mock.start = this.start;
        if ("end" in this)
            mock.end = this.end;
        if (this.assignOp)
            mock.assignOp = unevalableConst(this.assignOp);
        for (var key in this) {
            if (this.hasOwnProperty(key) && !(key in TO_SOURCE_SKIP))
                mock[key] = this[key];
        }
        return mock.toSource();
    };

    // Always use push to add operands to an expression, to update start and end.
    Np.push = function (kid) {
        // kid can be null e.g. [1, , 2].
        if (kid !== null) {
            if (kid.start < this.start)
                this.start = kid.start;
            if (this.end < kid.end)
                this.end = kid.end;
        }
        return this.children.push(kid);
    }

    Node.indentLevel = 0;

    function tokenString(tt) {
        var t = definitions.tokens[tt];
        return /^\W/.test(t) ? definitions.opTypeNames[t] : t.toUpperCase();
    }

    Np.toString = function () {
        var a = [];
        for (var i in this) {
            if (this.hasOwnProperty(i) && i !== 'type' && i !== 'target')
                a.push({id: i, value: this[i]});
        }
        a.sort(function (a,b) { return (a.id < b.id) ? -1 : 1; });
        const INDENTATION = "    ";
        var n = ++Node.indentLevel;
        var s = "{\n" + INDENTATION.repeat(n) + "type: " + tokenString(this.type);
        for (i = 0; i < a.length; i++)
            s += ",\n" + INDENTATION.repeat(n) + a[i].id + ": " + a[i].value;
        n = --Node.indentLevel;
        s += "\n" + INDENTATION.repeat(n) + "}";
        return s;
    }

    Np.getSource = function () {
        return this.tokenizer.source.slice(this.start, this.end);
    };

    /*
     * Helper init objects for common nodes.
     */

    const LOOP_INIT = { isLoop: true };

    function blockInit() {
        return { type: BLOCK, varDecls: [] };
    }

    function scriptInit() {
        return { type: SCRIPT,
                 funDecls: [],
                 varDecls: [],
                 modDefns: new StringMap(),
                 modAssns: new StringMap(),
                 modDecls: new StringMap(),
                 modLoads: new StringMap(),
                 impDecls: [],
                 expDecls: [],
                 exports: new StringMap(),
                 hasEmptyReturn: false,
                 hasReturnWithValue: false,
                 isGenerator: false };
    }

    definitions.defineGetter(Np, "filename",
                             function() {
                                 return this.tokenizer.filename;
                             });

    definitions.defineGetter(Np, "length",
                             function() {
                                 throw new Error("Node.prototype.length is gone; " +
                                                 "use n.children.length instead");
                             });

    definitions.defineProperty(String.prototype, "repeat",
                               function(n) {
                                   var s = "", t = this + s;
                                   while (--n >= 0)
                                       s += t;
                                   return s;
                               }, false, false, true);

    function MaybeLeftParen(t, x) {
        if (x.parenFreeMode)
            return t.match(LEFT_PAREN) ? LEFT_PAREN : END;
        return t.mustMatch(LEFT_PAREN).type;
    }

    function MaybeRightParen(t, p) {
        if (p === LEFT_PAREN)
            t.mustMatch(RIGHT_PAREN);
    }

    /*
     * Statements :: (tokenizer, compiler context, node) -> void
     *
     * Parses a sequence of Statements.
     */
    function Statements(t, x, n) {
        try {
            while (!t.done && t.peek(true) !== RIGHT_CURLY)
                n.push(Statement(t, x));
        } catch (e) {
            if (t.done)
                t.unexpectedEOF = true;
            throw e;
        }
    }

    function Block(t, x) {
        t.mustMatch(LEFT_CURLY);
        var n = new Node(t, blockInit());
        Statements(t, x.update({ parentBlock: n }).pushTarget(n), n);
        t.mustMatch(RIGHT_CURLY);
        return n;
    }

    const DECLARED_FORM = 0, EXPRESSED_FORM = 1, STATEMENT_FORM = 2;

    /*
     * Export :: (binding node, boolean) -> Export
     *
     * Static semantic representation of a module export.
     */
    function Export(node, isDefinition) {
        this.node = node;                 // the AST node declaring this individual export
        this.isDefinition = isDefinition; // is the node an 'export'-annotated definition?
        this.resolved = null;             // resolved pointer to the target of this export
    }

    /*
     * registerExport :: (StringMap, EXPORT node) -> void
     */
    function registerExport(exports, decl) {
        function register(name, exp) {
            if (exports.has(name))
                throw new SyntaxError("multiple exports of " + name);
            exports.set(name, exp);
        }

        switch (decl.type) {
          case MODULE:
          case FUNCTION:
            register(decl.name, new Export(decl, true));
            break;

          case VAR:
            for (var i = 0; i < decl.children.length; i++)
                register(decl.children[i].name, new Export(decl.children[i], true));
            break;

          case LET:
          case CONST:
            throw new Error("NYI: " + definitions.tokens[decl.type]);

          case EXPORT:
            for (var i = 0; i < decl.pathList.length; i++) {
                var path = decl.pathList[i];
                switch (path.type) {
                  case OBJECT_INIT:
                    for (var j = 0; j < path.children.length; j++) {
                        // init :: IDENTIFIER | PROPERTY_INIT
                        var init = path.children[j];
                        if (init.type === IDENTIFIER)
                            register(init.value, new Export(init, false));
                        else
                            register(init.children[0].value, new Export(init.children[1], false));
                    }
                    break;

                  case DOT:
                    register(path.children[1].value, new Export(path, false));
                    break;

                  case IDENTIFIER:
                    register(path.value, new Export(path, false));
                    break;

                  default:
                    throw new Error("unexpected export path: " + definitions.tokens[path.type]);
                }
            }
            break;

          default:
            throw new Error("unexpected export decl: " + definitions.tokens[exp.type]);
        }
    }

    /*
     * Module :: (node) -> Module
     *
     * Static semantic representation of a module.
     */
    function Module(node) {
        var exports = node.body.exports;
        var modDefns = node.body.modDefns;

        var exportedModules = new StringMap();

        exports.forEach(function(name, exp) {
            var node = exp.node;
            if (node.type === MODULE) {
                exportedModules.set(name, node);
            } else if (!exp.isDefinition && node.type === IDENTIFIER && modDefns.has(node.value)) {
                var mod = modDefns.get(node.value);
                exportedModules.set(name, mod);
            }
        });

        this.node = node;
        this.exports = exports;
        this.exportedModules = exportedModules;
    }

    /*
     * Statement :: (tokenizer, compiler context) -> node
     *
     * Parses a Statement.
     */
    function Statement(t, x) {
        var i, label, n, n2, p, c, ss, tt = t.get(true), tt2, x2, x3;

        var comments = t.blockComments;

        if (x.blackList[tt])
            throw t.newSyntaxError(definitions.tokens[tt] + " statements only allowed in Harmony");
        if (!x.allow(tt))
            throw t.newSyntaxError(definitions.tokens[tt] + " statement in illegal context");

        // Cases for statements ending in a right curly return early, avoiding the
        // common semicolon insertion magic after this switch.
        switch (tt) {
          case IMPORT:
            n = new Node(t);
            n.pathList = ImportPathList(t, x);
            x.parentScript.impDecls.push(n);
            break;

          case EXPORT:
            switch (t.peek()) {
              case MODULE:
              case FUNCTION:
              case LET:
              case VAR:
              case CONST:
                n = Statement(t, x);
                n.blockComments = comments;
                n.exported = true;
                x.parentScript.expDecls.push(n);
                registerExport(x.parentScript.exports, n);
                return n;

              default:
                n = new Node(t);
                n.pathList = ExportPathList(t, x);
                break;
            }
            x.parentScript.expDecls.push(n);
            registerExport(x.parentScript.exports, n);
            break;

          case MODULE:
            n = new Node(t);
            n.blockComments = comments;
            t.mustMatch(IDENTIFIER);
            label = t.token.value;

            if (t.match(LEFT_CURLY)) {
                n.name = label;
                n.body = Script(t, true, false);
                n.module = new Module(n);
                t.mustMatch(RIGHT_CURLY);
                x.parentScript.modDefns.set(n.name, n);
                return n;
            }

            t.unget();
            ModuleVariables(t, x, n);
            return n;

          case FUNCTION:
            // DECLARED_FORM extends funDecls of x, STATEMENT_FORM doesn't.
            return FunctionDefinition(t, x, true, x.topLevel ? DECLARED_FORM : STATEMENT_FORM, comments);

          case LEFT_CURLY:
            n = new Node(t, blockInit());
            Statements(t, x.update({ parentBlock: n }).pushTarget(n).nest(), n);
            t.mustMatch(RIGHT_CURLY);
            return n;

          case IF:
            n = new Node(t);
            n.condition = HeadExpression(t, x);
            x2 = x.pushTarget(n).nest();
            n.thenPart = Statement(t, x2);
            n.elsePart = t.match(ELSE, true) ? Statement(t, x2) : null;
            return n;

          case SWITCH:
            // This allows CASEs after a DEFAULT, which is in the standard.
            n = new Node(t, { cases: [], defaultIndex: -1 });
            n.discriminant = HeadExpression(t, x);
            x2 = x.pushTarget(n).nest();
            t.mustMatch(LEFT_CURLY);
            while ((tt = t.get()) !== RIGHT_CURLY) {
                switch (tt) {
                  case DEFAULT:
                    if (n.defaultIndex >= 0)
                        throw t.newSyntaxError("More than one switch default");
                    // FALL THROUGH
                  case CASE:
                    n2 = new Node(t);
                    if (tt === DEFAULT)
                        n.defaultIndex = n.cases.length;
                    else
                        n2.caseLabel = Expression(t, x2, COLON);
                    break;

                  default:
                    throw t.newSyntaxError("Invalid switch case");
                }
                t.mustMatch(COLON);
                n2.statements = new Node(t, blockInit());
                while ((tt=t.peek(true)) !== CASE && tt !== DEFAULT &&
                        tt !== RIGHT_CURLY)
                    n2.statements.push(Statement(t, x2));
                n.cases.push(n2);
            }
            return n;

          case FOR:
            n = new Node(t, LOOP_INIT);
            n.blockComments = comments;
            if (t.match(IDENTIFIER)) {
                if (t.token.value === "each")
                    n.isEach = true;
                else
                    t.unget();
            }
            if (!x.parenFreeMode)
                t.mustMatch(LEFT_PAREN);
            x2 = x.pushTarget(n).nest();
            x3 = x.update({ inForLoopInit: true });
            n2 = null;
            if ((tt = t.peek(true)) !== SEMICOLON) {
                if (tt === VAR || tt === CONST) {
                    t.get();
                    n2 = Variables(t, x3);
                } else if (tt === LET) {
                    t.get();
                    if (t.peek() === LEFT_PAREN) {
                        n2 = LetBlock(t, x3, false);
                    } else {
                        // Let in for head, we need to add an implicit block
                        // around the rest of the for.
                        x3.parentBlock = n;
                        n.varDecls = [];
                        n2 = Variables(t, x3);
                    }
                } else {
                    n2 = Expression(t, x3);
                }
            }
            if (n2 && t.match(IN)) {
                n.type = FOR_IN;
                n.object = Expression(t, x3);
                if (n2.type === VAR || n2.type === LET) {
                    c = n2.children;

                    // Destructuring turns one decl into multiples, so either
                    // there must be only one destructuring or only one
                    // decl.
                    if (c.length !== 1 && n2.destructurings.length !== 1) {
                        throw new SyntaxError("Invalid for..in left-hand side",
                                              t.filename, n2.lineno);
                    }
                    if (n2.destructurings.length > 0) {
                        n.iterator = n2.destructurings[0];
                    } else {
                        n.iterator = c[0];
                    }
                    n.varDecl = n2;
                } else {
                    if (n2.type === ARRAY_INIT || n2.type === OBJECT_INIT) {
                        n2.destructuredNames = checkDestructuring(t, x3, n2);
                    }
                    n.iterator = n2;
                }
            } else {
                x3.inForLoopInit = false;
                n.setup = n2;
                t.mustMatch(SEMICOLON);
                if (n.isEach)
                    throw t.newSyntaxError("Invalid for each..in loop");
                n.condition = (t.peek(true) === SEMICOLON)
                              ? null
                              : Expression(t, x3);
                t.mustMatch(SEMICOLON);
                tt2 = t.peek(true);
                n.update = (x.parenFreeMode
                            ? tt2 === LEFT_CURLY || definitions.isStatementStartCode[tt2]
                            : tt2 === RIGHT_PAREN)
                           ? null
                           : Expression(t, x3);
            }
            if (!x.parenFreeMode)
                t.mustMatch(RIGHT_PAREN);
            n.body = Statement(t, x2);
            return n;

          case WHILE:
            n = new Node(t, { isLoop: true });
            n.blockComments = comments;
            n.condition = HeadExpression(t, x);
            n.body = Statement(t, x.pushTarget(n).nest());
            return n;

          case DO:
            n = new Node(t, { isLoop: true });
            n.blockComments = comments;
            n.body = Statement(t, x.pushTarget(n).nest());
            t.mustMatch(WHILE);
            n.condition = HeadExpression(t, x);
            if (!x.ecmaStrictMode) {
                // <script language="JavaScript"> (without version hints) may need
                // automatic semicolon insertion without a newline after do-while.
                // See http://bugzilla.mozilla.org/show_bug.cgi?id=238945.
                t.match(SEMICOLON);
                return n;
            }
            break;

          case BREAK:
          case CONTINUE:
            n = new Node(t);
            n.blockComments = comments;

            // handle the |foo: break foo;| corner case
            x2 = x.pushTarget(n);

            if (t.peekOnSameLine() === IDENTIFIER) {
                t.get();
                n.label = t.token.value;
            }

            if (n.label) {
                n.target = x2.labeledTargets.find(function(target) { return target.labels.has(n.label) });
            } else if (tt === CONTINUE) {
                n.target = x2.defaultLoopTarget;
            } else {
                n.target = x2.defaultTarget;
            }

            if (!n.target)
                throw t.newSyntaxError("Invalid " + ((tt === BREAK) ? "break" : "continue"));
            if (!n.target.isLoop && tt === CONTINUE)
                throw t.newSyntaxError("Invalid continue");

            break;

          case TRY:
            n = new Node(t, { catchClauses: [] });
            n.blockComments = comments;
            n.tryBlock = Block(t, x);
            while (t.match(CATCH)) {
                n2 = new Node(t);
                p = MaybeLeftParen(t, x);
                switch (t.get()) {
                  case LEFT_BRACKET:
                  case LEFT_CURLY:
                    // Destructured catch identifiers.
                    t.unget();
                    n2.varName = DestructuringExpression(t, x, true);
                    break;
                  case IDENTIFIER:
                    n2.varName = t.token.value;
                    break;
                  default:
                    throw t.newSyntaxError("missing identifier in catch");
                    break;
                }
                if (t.match(IF)) {
                    if (x.ecma3OnlyMode)
                        throw t.newSyntaxError("Illegal catch guard");
                    if (n.catchClauses.length && !n.catchClauses.top().guard)
                        throw t.newSyntaxError("Guarded catch after unguarded");
                    n2.guard = Expression(t, x);
                }
                MaybeRightParen(t, p);
                n2.block = Block(t, x);
                n.catchClauses.push(n2);
            }
            if (t.match(FINALLY))
                n.finallyBlock = Block(t, x);
            if (!n.catchClauses.length && !n.finallyBlock)
                throw t.newSyntaxError("Invalid try statement");
            return n;

          case CATCH:
          case FINALLY:
            throw t.newSyntaxError(definitions.tokens[tt] + " without preceding try");

          case THROW:
            n = new Node(t);
            n.exception = Expression(t, x);
            break;

          case RETURN:
            n = ReturnOrYield(t, x);
            break;

          case WITH:
            n = new Node(t);
            n.blockComments = comments;
            n.object = HeadExpression(t, x);
            n.body = Statement(t, x.pushTarget(n).nest());
            return n;

          case VAR:
          case CONST:
            n = Variables(t, x);
            break;

          case LET:
            if (t.peek() === LEFT_PAREN)
                n = LetBlock(t, x, true);
            else
                n = Variables(t, x);
            break;

          case DEBUGGER:
            n = new Node(t);
            break;

          case NEWLINE:
          case SEMICOLON:
            n = new Node(t, { type: SEMICOLON });
            n.blockComments = comments;
            n.expression = null;
            return n;

          default:
            if (tt === IDENTIFIER) {
                tt = t.peek();
                // Labeled statement.
                if (tt === COLON) {
                    label = t.token.value;
                    if (x.allLabels.has(label))
                        throw t.newSyntaxError("Duplicate label");
                    t.get();
                    n = new Node(t, { type: LABEL, label: label });
                    n.blockComments = comments;
                    n.statement = Statement(t, x.pushLabel(label).nest());
                    n.target = (n.statement.type === LABEL) ? n.statement.target : n.statement;
                    return n;
                }
            }

            // Expression statement.
            // We unget the current token to parse the expression as a whole.
            n = new Node(t, { type: SEMICOLON });
            t.unget();
            n.blockComments = comments;
            n.expression = Expression(t, x);
            n.end = n.expression.end;
            break;
        }

        n.blockComments = comments;
        MagicalSemicolon(t);
        return n;
    }

    /*
     * MagicalSemicolon :: (tokenizer) -> void
     */
    function MagicalSemicolon(t) {
        var tt;
        if (t.lineno === t.token.lineno) {
            tt = t.peekOnSameLine();
            if (tt !== END && tt !== NEWLINE && tt !== SEMICOLON && tt !== RIGHT_CURLY)
                throw t.newSyntaxError("missing ; before statement");
        }
        t.match(SEMICOLON);
    }

    /*
     * ReturnOrYield :: (tokenizer, compiler context) -> (RETURN | YIELD) node
     */
    function ReturnOrYield(t, x) {
        var n, b, tt = t.token.type, tt2;

        var parentScript = x.parentScript;

        if (tt === RETURN) {
            if (!x.inFunction)
                throw t.newSyntaxError("Return not in function");
        } else /* if (tt === YIELD) */ {
            if (!x.inFunction)
                throw t.newSyntaxError("Yield not in function");
            parentScript.isGenerator = true;
        }
        n = new Node(t, { value: undefined });

        tt2 = (tt === RETURN) ? t.peekOnSameLine(true) : t.peek(true);
        if (tt2 !== END && tt2 !== NEWLINE &&
            tt2 !== SEMICOLON && tt2 !== RIGHT_CURLY
            && (tt !== YIELD ||
                (tt2 !== tt && tt2 !== RIGHT_BRACKET && tt2 !== RIGHT_PAREN &&
                 tt2 !== COLON && tt2 !== COMMA))) {
            if (tt === RETURN) {
                n.value = Expression(t, x);
                parentScript.hasReturnWithValue = true;
            } else {
                n.value = AssignExpression(t, x);
            }
        } else if (tt === RETURN) {
            parentScript.hasEmptyReturn = true;
        }

        // Disallow return v; in generator.
        if (parentScript.hasReturnWithValue && parentScript.isGenerator)
            throw t.newSyntaxError("Generator returns a value");

        return n;
    }

    /*
     * ModuleExpression :: (tokenizer, compiler context) -> (STRING | IDENTIFIER | DOT) node
     */
    function ModuleExpression(t, x) {
        return t.match(STRING) ? new Node(t) : QualifiedPath(t, x);
    }

    /*
     * ImportPathList :: (tokenizer, compiler context) -> Array[DOT node]
     */
    function ImportPathList(t, x) {
        var a = [];
        do {
            a.push(ImportPath(t, x));
        } while (t.match(COMMA));
        return a;
    }

    /*
     * ImportPath :: (tokenizer, compiler context) -> DOT node
     */
    function ImportPath(t, x) {
        var n = QualifiedPath(t, x);
        if (!t.match(DOT)) {
            if (n.type === IDENTIFIER)
                throw t.newSyntaxError("cannot import local variable");
            return n;
        }

        var n2 = new Node(t);
        n2.push(n);
        n2.push(ImportSpecifierSet(t, x));
        return n2;
    }

    /*
     * ExplicitSpecifierSet :: (tokenizer, compiler context, (tokenizer, compiler context) -> node)
     *                      -> OBJECT_INIT node
     */
    function ExplicitSpecifierSet(t, x, SpecifierRHS) {
        var n, n2, id, tt;

        n = new Node(t, { type: OBJECT_INIT });
        t.mustMatch(LEFT_CURLY);

        if (!t.match(RIGHT_CURLY)) {
            do {
                id = Identifier(t, x);
                if (t.match(COLON)) {
                    n2 = new Node(t, { type: PROPERTY_INIT });
                    n2.push(id);
                    n2.push(SpecifierRHS(t, x));
                    n.push(n2);
                } else {
                    n.push(id);
                }
            } while (!t.match(RIGHT_CURLY) && t.mustMatch(COMMA));
        }

        return n;
    }

    /*
     * ImportSpecifierSet :: (tokenizer, compiler context) -> (IDENTIFIER | OBJECT_INIT) node
     */
    function ImportSpecifierSet(t, x) {
        return t.match(MUL)
             ? new Node(t, { type: IDENTIFIER, name: "*" })
             : ExplicitSpecifierSet(t, x, Identifier);
    }

    /*
     * Identifier :: (tokenizer, compiler context) -> IDENTIFIER node
     */
    function Identifier(t, x) {
        t.mustMatch(IDENTIFIER);
        return new Node(t, { type: IDENTIFIER });
    }

    /*
     * IdentifierName :: (tokenizer) -> IDENTIFIER node
     */
    function IdentifierName(t) {
        if (t.match(IDENTIFIER))
            return new Node(t, { type: IDENTIFIER });
        t.get();
        if (t.token.value in definitions.keywords)
            return new Node(t, { type: IDENTIFIER });
        throw t.newSyntaxError("missing IdentifierName");
    }

    /*
     * QualifiedPath :: (tokenizer, compiler context) -> (IDENTIFIER | DOT) node
     */
    function QualifiedPath(t, x) {
        var n, n2;

        n = Identifier(t, x);

        while (t.match(DOT)) {
            if (t.peek() !== IDENTIFIER) {
                // Unget the '.' token, which isn't part of the QualifiedPath.
                t.unget();
                break;
            }
            n2 = new Node(t);
            n2.push(n);
            n2.push(Identifier(t, x));
            n = n2;
        }

        return n;
    }

    /*
     * ExportPath :: (tokenizer, compiler context) -> (IDENTIFIER | DOT | OBJECT_INIT) node
     */
    function ExportPath(t, x) {
        if (t.peek() === LEFT_CURLY)
            return ExplicitSpecifierSet(t, x, QualifiedPath);
        return QualifiedPath(t, x);
    }

    /*
     * ExportPathList :: (tokenizer, compiler context)
     *                -> Array[(IDENTIFIER | DOT | OBJECT_INIT) node]
     */
    function ExportPathList(t, x) {
        var a = [];
        do {
            a.push(ExportPath(t, x));
        } while (t.match(COMMA));
        return a;
    }

    /*
     * FunctionDefinition :: (tokenizer, compiler context, boolean,
     *                        DECLARED_FORM or EXPRESSED_FORM or STATEMENT_FORM,
     *                        [string] or null or undefined)
     *                    -> node
     */
    function FunctionDefinition(t, x, requireName, functionForm, comments) {
        var tt;
        var f = new Node(t, { params: [], paramComments: [] });
        if (typeof comment === "undefined")
            comment = null;
        f.blockComments = comments;
        if (f.type !== FUNCTION)
            f.type = (f.value === "get") ? GETTER : SETTER;
        if (t.match(IDENTIFIER))
            f.name = t.token.value;
        else if (requireName)
            throw t.newSyntaxError("missing function identifier");

        var inModule = x ? x.inModule : false;
        var x2 = new StaticContext(null, null, inModule, true);

        t.mustMatch(LEFT_PAREN);
        if (!t.match(RIGHT_PAREN)) {
            do {
                tt = t.get();
                f.paramComments.push(t.lastBlockComment());
                switch (tt) {
                  case LEFT_BRACKET:
                  case LEFT_CURLY:
                    // Destructured formal parameters.
                    t.unget();
                    f.params.push(DestructuringExpression(t, x2));
                    break;
                  case IDENTIFIER:
                    f.params.push(t.token.value);
                    break;
                  default:
                    throw t.newSyntaxError("missing formal parameter");
                    break;
                }
            } while (t.match(COMMA));
            t.mustMatch(RIGHT_PAREN);
        }

        // Do we have an expression closure or a normal body?
        tt = t.get();
        if (tt !== LEFT_CURLY)
            t.unget();

        if (tt !== LEFT_CURLY) {
            f.body = AssignExpression(t, x2);
            if (f.body.isGenerator)
                throw t.newSyntaxError("Generator returns a value");
        } else {
            f.body = Script(t, inModule, true);
        }

        if (tt === LEFT_CURLY)
            t.mustMatch(RIGHT_CURLY);

        f.end = t.token.end;
        f.functionForm = functionForm;
        if (functionForm === DECLARED_FORM)
            x.parentScript.funDecls.push(f);
        return f;
    }

    /*
     * ModuleVariables :: (tokenizer, compiler context, MODULE node) -> void
     *
     * Parses a comma-separated list of module declarations (and maybe
     * initializations).
     */
    function ModuleVariables(t, x, n) {
        var n1, n2;
        do {
            n1 = Identifier(t, x);
            if (t.match(ASSIGN)) {
                n2 = ModuleExpression(t, x);
                n1.initializer = n2;
                if (n2.type === STRING)
                    x.parentScript.modLoads.set(n1.value, n2.value);
                else
                    x.parentScript.modAssns.set(n1.value, n1);
            }
            n.push(n1);
        } while (t.match(COMMA));
    }

    /*
     * Variables :: (tokenizer, compiler context) -> node
     *
     * Parses a comma-separated list of var declarations (and maybe
     * initializations).
     */
    function Variables(t, x, letBlock) {
        var n, n2, ss, i, s, tt;

        tt = t.token.type;
        switch (tt) {
          case VAR:
          case CONST:
            s = x.parentScript;
            break;
          case LET:
            s = x.parentBlock;
            break;
          case LEFT_PAREN:
            tt = LET;
            s = letBlock;
            break;
        }

        n = new Node(t, { type: tt, destructurings: [] });

        do {
            tt = t.get();
            if (tt === LEFT_BRACKET || tt === LEFT_CURLY) {
                // Need to unget to parse the full destructured expression.
                t.unget();

                var dexp = DestructuringExpression(t, x, true);

                n2 = new Node(t, { type: IDENTIFIER,
                                   name: dexp,
                                   readOnly: n.type === CONST });
                n.push(n2);
                pushDestructuringVarDecls(n2.name.destructuredNames, s);
                n.destructurings.push({ exp: dexp, decl: n2 });

                if (x.inForLoopInit && t.peek() === IN) {
                    continue;
                }

                t.mustMatch(ASSIGN);
                if (t.token.assignOp)
                    throw t.newSyntaxError("Invalid variable initialization");

                n2.blockComment = t.lastBlockComment();
                n2.initializer = AssignExpression(t, x);

                continue;
            }

            if (tt !== IDENTIFIER)
                throw t.newSyntaxError("missing variable name");

            n2 = new Node(t, { type: IDENTIFIER,
                               name: t.token.value,
                               readOnly: n.type === CONST });
            n.push(n2);
            s.varDecls.push(n2);

            if (t.match(ASSIGN)) {
                var comment = t.lastBlockComment();
                if (t.token.assignOp)
                    throw t.newSyntaxError("Invalid variable initialization");

                n2.initializer = AssignExpression(t, x);
            } else {
                var comment = t.lastBlockComment();
            }
            n2.blockComment = comment;
        } while (t.match(COMMA));

        return n;
    }

    /*
     * LetBlock :: (tokenizer, compiler context, boolean) -> node
     *
     * Does not handle let inside of for loop init.
     */
    function LetBlock(t, x, isStatement) {
        var n, n2;

        // t.token.type must be LET
        n = new Node(t, { type: LET_BLOCK, varDecls: [] });
        t.mustMatch(LEFT_PAREN);
        n.variables = Variables(t, x, n);
        t.mustMatch(RIGHT_PAREN);

        if (isStatement && t.peek() !== LEFT_CURLY) {
            /*
             * If this is really an expression in let statement guise, then we
             * need to wrap the LET_BLOCK node in a SEMICOLON node so that we pop
             * the return value of the expression.
             */
            n2 = new Node(t, { type: SEMICOLON,
                               expression: n });
            isStatement = false;
        }

        if (isStatement)
            n.block = Block(t, x);
        else
            n.expression = AssignExpression(t, x);

        return n;
    }

    function checkDestructuring(t, x, n, simpleNamesOnly) {
        if (n.type === ARRAY_COMP)
            throw t.newSyntaxError("Invalid array comprehension left-hand side");
        if (n.type !== ARRAY_INIT && n.type !== OBJECT_INIT)
            return;

        var lhss = {};
        var nn, n2, idx, sub, cc, c = n.children;
        for (var i = 0, j = c.length; i < j; i++) {
            if (!(nn = c[i]))
                continue;
            if (nn.type === PROPERTY_INIT) {
                cc = nn.children;
                sub = cc[1];
                idx = cc[0].value;
            } else if (n.type === OBJECT_INIT) {
                // Do we have destructuring shorthand {foo, bar}?
                sub = nn;
                idx = nn.value;
            } else {
                sub = nn;
                idx = i;
            }

            if (sub.type === ARRAY_INIT || sub.type === OBJECT_INIT) {
                lhss[idx] = checkDestructuring(t, x, sub, simpleNamesOnly);
            } else {
                if (simpleNamesOnly && sub.type !== IDENTIFIER) {
                    // In declarations, lhs must be simple names
                    throw t.newSyntaxError("missing name in pattern");
                }

                lhss[idx] = sub;
            }
        }

        return lhss;
    }

    function DestructuringExpression(t, x, simpleNamesOnly) {
        var n = PrimaryExpression(t, x);
        // Keep the list of lefthand sides for varDecls
        n.destructuredNames = checkDestructuring(t, x, n, simpleNamesOnly);
        return n;
    }

    function GeneratorExpression(t, x, e) {
        return new Node(t, { type: GENERATOR,
                             expression: e,
                             tail: ComprehensionTail(t, x) });
    }

    function ComprehensionTail(t, x) {
        var body, n, n2, n3, p;

        // t.token.type must be FOR
        body = new Node(t, { type: COMP_TAIL });

        do {
            // Comprehension tails are always for..in loops.
            n = new Node(t, { type: FOR_IN, isLoop: true });
            if (t.match(IDENTIFIER)) {
                // But sometimes they're for each..in.
                if (t.token.value === "each")
                    n.isEach = true;
                else
                    t.unget();
            }
            p = MaybeLeftParen(t, x);
            switch(t.get()) {
              case LEFT_BRACKET:
              case LEFT_CURLY:
                t.unget();
                // Destructured left side of for in comprehension tails.
                n.iterator = DestructuringExpression(t, x);
                break;

              case IDENTIFIER:
                n.iterator = n3 = new Node(t, { type: IDENTIFIER });
                n3.name = n3.value;
                n.varDecl = n2 = new Node(t, { type: VAR });
                n2.push(n3);
                x.parentScript.varDecls.push(n3);
                // Don't add to varDecls since the semantics of comprehensions is
                // such that the variables are in their own function when
                // desugared.
                break;

              default:
                throw t.newSyntaxError("missing identifier");
            }
            t.mustMatch(IN);
            n.object = Expression(t, x);
            MaybeRightParen(t, p);
            body.push(n);
        } while (t.match(FOR));

        // Optional guard.
        if (t.match(IF))
            body.guard = HeadExpression(t, x);

        return body;
    }

    function HeadExpression(t, x) {
        var p = MaybeLeftParen(t, x);
        var n = ParenExpression(t, x);
        MaybeRightParen(t, p);
        if (p === END && !n.parenthesized) {
            var tt = t.peek();
            if (tt !== LEFT_CURLY && !definitions.isStatementStartCode[tt])
                throw t.newSyntaxError("Unparenthesized head followed by unbraced body");
        }
        return n;
    }

    function ParenExpression(t, x) {
        // Always accept the 'in' operator in a parenthesized expression,
        // where it's unambiguous, even if we might be parsing the init of a
        // for statement.
        var n = Expression(t, x.update({ inForLoopInit: x.inForLoopInit &&
                                                        (t.token.type === LEFT_PAREN) }));

        if (t.match(FOR)) {
            if (n.type === YIELD && !n.parenthesized)
                throw t.newSyntaxError("Yield expression must be parenthesized");
            if (n.type === COMMA && !n.parenthesized)
                throw t.newSyntaxError("Generator expression must be parenthesized");
            n = GeneratorExpression(t, x, n);
        }

        return n;
    }

    /*
     * Expression :: (tokenizer, compiler context) -> node
     *
     * Top-down expression parser matched against SpiderMonkey.
     */
    function Expression(t, x) {
        var n, n2;

        n = AssignExpression(t, x);
        if (t.match(COMMA)) {
            n2 = new Node(t, { type: COMMA });
            n2.push(n);
            n = n2;
            do {
                n2 = n.children[n.children.length-1];
                if (n2.type === YIELD && !n2.parenthesized)
                    throw t.newSyntaxError("Yield expression must be parenthesized");
                n.push(AssignExpression(t, x));
            } while (t.match(COMMA));
        }

        return n;
    }

    function AssignExpression(t, x) {
        var n, lhs;

        // Have to treat yield like an operand because it could be the leftmost
        // operand of the expression.
        if (t.match(YIELD, true))
            return ReturnOrYield(t, x);

        n = new Node(t, { type: ASSIGN });
        lhs = ConditionalExpression(t, x);

        if (!t.match(ASSIGN)) {
            return lhs;
        }

        n.blockComment = t.lastBlockComment();

        switch (lhs.type) {
          case OBJECT_INIT:
          case ARRAY_INIT:
            lhs.destructuredNames = checkDestructuring(t, x, lhs);
            // FALL THROUGH
          case IDENTIFIER: case DOT: case INDEX: case CALL:
            break;
          default:
            throw t.newSyntaxError("Bad left-hand side of assignment");
            break;
        }

        n.assignOp = lhs.assignOp = t.token.assignOp;
        n.push(lhs);
        n.push(AssignExpression(t, x));

        return n;
    }

    function ConditionalExpression(t, x) {
        var n, n2;

        n = OrExpression(t, x);
        if (t.match(HOOK)) {
            n2 = n;
            n = new Node(t, { type: HOOK });
            n.push(n2);
            /*
             * Always accept the 'in' operator in the middle clause of a ternary,
             * where it's unambiguous, even if we might be parsing the init of a
             * for statement.
             */
            n.push(AssignExpression(t, x.update({ inForLoopInit: false })));
            if (!t.match(COLON))
                throw t.newSyntaxError("missing : after ?");
            n.push(AssignExpression(t, x));
        }

        return n;
    }

    function OrExpression(t, x) {
        var n, n2;

        n = AndExpression(t, x);
        while (t.match(OR)) {
            n2 = new Node(t);
            n2.push(n);
            n2.push(AndExpression(t, x));
            n = n2;
        }

        return n;
    }

    function AndExpression(t, x) {
        var n, n2;

        n = BitwiseOrExpression(t, x);
        while (t.match(AND)) {
            n2 = new Node(t);
            n2.push(n);
            n2.push(BitwiseOrExpression(t, x));
            n = n2;
        }

        return n;
    }

    function BitwiseOrExpression(t, x) {
        var n, n2;

        n = BitwiseXorExpression(t, x);
        while (t.match(BITWISE_OR)) {
            n2 = new Node(t);
            n2.push(n);
            n2.push(BitwiseXorExpression(t, x));
            n = n2;
        }

        return n;
    }

    function BitwiseXorExpression(t, x) {
        var n, n2;

        n = BitwiseAndExpression(t, x);
        while (t.match(BITWISE_XOR)) {
            n2 = new Node(t);
            n2.push(n);
            n2.push(BitwiseAndExpression(t, x));
            n = n2;
        }

        return n;
    }

    function BitwiseAndExpression(t, x) {
        var n, n2;

        n = EqualityExpression(t, x);
        while (t.match(BITWISE_AND)) {
            n2 = new Node(t);
            n2.push(n);
            n2.push(EqualityExpression(t, x));
            n = n2;
        }

        return n;
    }

    function EqualityExpression(t, x) {
        var n, n2;

        n = RelationalExpression(t, x);
        while (t.match(EQ) || t.match(NE) ||
               t.match(STRICT_EQ) || t.match(STRICT_NE)) {
            n2 = new Node(t);
            n2.push(n);
            n2.push(RelationalExpression(t, x));
            n = n2;
        }

        return n;
    }

    function RelationalExpression(t, x) {
        var n, n2;

        /*
         * Uses of the in operator in shiftExprs are always unambiguous,
         * so unset the flag that prohibits recognizing it.
         */
        var x2 = x.update({ inForLoopInit: false });
        n = ShiftExpression(t, x2);
        while ((t.match(LT) || t.match(LE) || t.match(GE) || t.match(GT) ||
               (!x.inForLoopInit && t.match(IN)) ||
               t.match(INSTANCEOF))) {
            n2 = new Node(t);
            n2.push(n);
            n2.push(ShiftExpression(t, x2));
            n = n2;
        }

        return n;
    }

    function ShiftExpression(t, x) {
        var n, n2;

        n = AddExpression(t, x);
        while (t.match(LSH) || t.match(RSH) || t.match(URSH)) {
            n2 = new Node(t);
            n2.push(n);
            n2.push(AddExpression(t, x));
            n = n2;
        }

        return n;
    }

    function AddExpression(t, x) {
        var n, n2;

        n = MultiplyExpression(t, x);
        while (t.match(PLUS) || t.match(MINUS)) {
            n2 = new Node(t);
            n2.push(n);
            n2.push(MultiplyExpression(t, x));
            n = n2;
        }

        return n;
    }

    function MultiplyExpression(t, x) {
        var n, n2;

        n = UnaryExpression(t, x);
        while (t.match(MUL) || t.match(DIV) || t.match(MOD)) {
            n2 = new Node(t);
            n2.push(n);
            n2.push(UnaryExpression(t, x));
            n = n2;
        }

        return n;
    }

    function UnaryExpression(t, x) {
        var n, n2, tt;

        switch (tt = t.get(true)) {
          case DELETE: case VOID: case TYPEOF:
          case NOT: case BITWISE_NOT: case PLUS: case MINUS:
            if (tt === PLUS)
                n = new Node(t, { type: UNARY_PLUS });
            else if (tt === MINUS)
                n = new Node(t, { type: UNARY_MINUS });
            else
                n = new Node(t);
            n.push(UnaryExpression(t, x));
            break;

          case INCREMENT:
          case DECREMENT:
            // Prefix increment/decrement.
            n = new Node(t);
            n.push(MemberExpression(t, x, true));
            break;

          default:
            t.unget();
            n = MemberExpression(t, x, true);

            // Don't look across a newline boundary for a postfix {in,de}crement.
            if (t.tokens[(t.tokenIndex + t.lookahead - 1) & 3].lineno ===
                t.lineno) {
                if (t.match(INCREMENT) || t.match(DECREMENT)) {
                    n2 = new Node(t, { postfix: true });
                    n2.push(n);
                    n = n2;
                }
            }
            break;
        }

        return n;
    }

    function MemberExpression(t, x, allowCallSyntax) {
        var n, n2, name, tt;

        if (t.match(NEW)) {
            n = new Node(t);
            n.push(MemberExpression(t, x, false));
            if (t.match(LEFT_PAREN)) {
                n.type = NEW_WITH_ARGS;
                n.push(ArgumentList(t, x));
            }
        } else {
            n = PrimaryExpression(t, x);
        }

        while ((tt = t.get()) !== END) {
            switch (tt) {
              case DOT:
                n2 = new Node(t);
                n2.push(n);
                n2.push(IdentifierName(t));
                break;

              case LEFT_BRACKET:
                n2 = new Node(t, { type: INDEX });
                n2.push(n);
                n2.push(Expression(t, x));
                t.mustMatch(RIGHT_BRACKET);
                break;

              case LEFT_PAREN:
                if (allowCallSyntax) {
                    n2 = new Node(t, { type: CALL });
                    n2.push(n);
                    n2.push(ArgumentList(t, x));
                    break;
                }

                // FALL THROUGH
              default:
                t.unget();
                return n;
            }

            n = n2;
        }

        return n;
    }

    function ArgumentList(t, x) {
        var n, n2;

        n = new Node(t, { type: LIST });
        if (t.match(RIGHT_PAREN, true))
            return n;
        do {
            n2 = AssignExpression(t, x);
            if (n2.type === YIELD && !n2.parenthesized && t.peek() === COMMA)
                throw t.newSyntaxError("Yield expression must be parenthesized");
            if (t.match(FOR)) {
                n2 = GeneratorExpression(t, x, n2);
                if (n.children.length > 1 || t.peek(true) === COMMA)
                    throw t.newSyntaxError("Generator expression must be parenthesized");
            }
            n.push(n2);
        } while (t.match(COMMA));
        t.mustMatch(RIGHT_PAREN);

        return n;
    }

    function PrimaryExpression(t, x) {
        var n, n2, tt = t.get(true);

        switch (tt) {
          case FUNCTION:
            n = FunctionDefinition(t, x, false, EXPRESSED_FORM);
            break;

          case LEFT_BRACKET:
            n = new Node(t, { type: ARRAY_INIT });
            while ((tt = t.peek(true)) !== RIGHT_BRACKET) {
                if (tt === COMMA) {
                    t.get();
                    n.push(null);
                    continue;
                }
                n.push(AssignExpression(t, x));
                if (tt !== COMMA && !t.match(COMMA))
                    break;
            }

            // If we matched exactly one element and got a FOR, we have an
            // array comprehension.
            if (n.children.length === 1 && t.match(FOR)) {
                n2 = new Node(t, { type: ARRAY_COMP,
                                   expression: n.children[0],
                                   tail: ComprehensionTail(t, x) });
                n = n2;
            }
            t.mustMatch(RIGHT_BRACKET);
            break;

          case LEFT_CURLY:
            var id, fd;
            n = new Node(t, { type: OBJECT_INIT });

          object_init:
            if (!t.match(RIGHT_CURLY)) {
                do {
                    tt = t.get();
                    if ((t.token.value === "get" || t.token.value === "set") &&
                        t.peek() === IDENTIFIER) {
                        if (x.ecma3OnlyMode)
                            throw t.newSyntaxError("Illegal property accessor");
                        n.push(FunctionDefinition(t, x, true, EXPRESSED_FORM));
                    } else {
                        var comments = t.blockComments;
                        switch (tt) {
                          case IDENTIFIER: case NUMBER: case STRING:
                            id = new Node(t, { type: IDENTIFIER });
                            break;
                          case RIGHT_CURLY:
                            if (x.ecma3OnlyMode)
                                throw t.newSyntaxError("Illegal trailing ,");
                            break object_init;
                          default:
                            if (t.token.value in definitions.keywords) {
                                id = new Node(t, { type: IDENTIFIER });
                                break;
                            }
                            throw t.newSyntaxError("Invalid property name");
                        }
                        if (t.match(COLON)) {
                            n2 = new Node(t, { type: PROPERTY_INIT });
                            n2.push(id);
                            n2.push(AssignExpression(t, x));
                            n2.blockComments = comments;
                            n.push(n2);
                        } else {
                            // Support, e.g., |var {x, y} = o| as destructuring shorthand
                            // for |var {x: x, y: y} = o|, per proposed JS2/ES4 for JS1.8.
                            if (t.peek() !== COMMA && t.peek() !== RIGHT_CURLY)
                                throw t.newSyntaxError("missing : after property");
                            n.push(id);
                        }
                    }
                } while (t.match(COMMA));
                t.mustMatch(RIGHT_CURLY);
            }
            break;

          case LEFT_PAREN:
            n = ParenExpression(t, x);
            t.mustMatch(RIGHT_PAREN);
            n.parenthesized = true;
            break;

          case LET:
            n = LetBlock(t, x, false);
            break;

          case NULL: case THIS: case TRUE: case FALSE:
          case IDENTIFIER: case NUMBER: case STRING: case REGEXP:
            n = new Node(t);
            break;

          default:
            throw t.newSyntaxError("missing operand");
            break;
        }

        return n;
    }

    /*
     * parse :: (source, filename, line number) -> node
     */
    function parse(s, f, l) {
        var t = new lexer.Tokenizer(s, f, l);
        var n = Script(t, false, false);
        if (!t.done)
            throw t.newSyntaxError("Syntax error");

        return n;
    }

    /*
     * parseStdin :: (source, {line number}, string, (string) -> boolean) -> program node
     */
    function parseStdin(s, ln, prefix, isCommand) {
        // the special .begin command is only recognized at the beginning
        if (s.match(/^[\s]*\.begin[\s]*$/)) {
            ++ln.value;
            return parseMultiline(ln, prefix);
        }

        // commands at the beginning are treated as the entire input
        if (isCommand(s.trim()))
            s = "";

        for (;;) {
            try {
                var t = new lexer.Tokenizer(s, "stdin", ln.value);
                var n = Script(t, false, false);
                ln.value = t.lineno;
                return n;
            } catch (e) {
                if (!t.unexpectedEOF)
                    throw e;

                // commands in the middle are not treated as part of the input
                var more;
                do {
                    if (prefix)
                        putstr(prefix);
                    more = readline();
                    if (!more)
                        throw e;
                } while (isCommand(more.trim()));

                s += "\n" + more;
            }
        }
    }

    /*
     * parseMultiline :: ({line number}, string | null) -> program node
     */
    function parseMultiline(ln, prefix) {
        var s = "";
        for (;;) {
            if (prefix)
                putstr(prefix);
            var more = readline();
            if (more === null)
                return null;
            // the only command recognized in multiline mode is .end
            if (more.match(/^[\s]*\.end[\s]*$/))
                break;
            s += "\n" + more;
        }
        var t = new lexer.Tokenizer(s, "stdin", ln.value);
        var n = Script(t, false, false);
        ln.value = t.lineno;
        return n;
    }

    module.exports = {
        parse: parse,
        parseStdin: parseStdin,
        Node: Node,
        SyntheticNode: SyntheticNode,
        DECLARED_FORM: DECLARED_FORM,
        EXPRESSED_FORM: EXPRESSED_FORM,
        STATEMENT_FORM: STATEMENT_FORM,
        Tokenizer: lexer.Tokenizer,
        FunctionDefinition: FunctionDefinition,
        Module: Module,
        Export: Export
    };

});