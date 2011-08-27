/* ***** BEGIN LICENSE BLOCK *****
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
 * The Original Code is Ajax.org Code Editor (ACE).
 *
 * The Initial Developer of the Original Code is
 * Ajax.org B.V.
 * Portions created by the Initial Developer are Copyright (C) 2010
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *      Fabian Jakobs <fabian AT ajax DOT org>
 *      Shlomo Zalman Heigh <shlomozalmanheigh AT gmail DOT com>
 *      Carin Meier
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

define(function(require, exports, module) {

var oop = require("pilot/oop");
var lang = require("pilot/lang");
var TextHighlightRules = require("ace/mode/text_highlight_rules").TextHighlightRules;



var ClojureHighlightRules = function() {

       var builtinFunctions = lang.arrayToMap(
        ('* *1 *2 *3 *agent* *allow-unresolved-vars* *assert* *clojure-version* ' +
            '*command-line-args* *compile-files* *compile-path* *e *err* *file* ' +
            '*flush-on-newline* *in* *macro-meta* *math-context* *ns* *out* ' +
            '*print-dup* *print-length* *print-level* *print-meta* *print-readably* ' +
            '*read-eval* *source-path* *use-context-classloader* ' +
            '*warn-on-reflection* + - -> -&gt; ->> -&gt;&gt; .. / < &lt; <= &lt;= = ' +
            '== > &gt; >= &gt;= accessor aclone ' +
            'add-classpath add-watch agent agent-errors aget alength alias all-ns ' +
            'alter alter-meta! alter-var-root amap ancestors and apply areduce ' +
            'array-map aset aset-boolean aset-byte aset-char aset-double aset-float ' +
            'aset-int aset-long aset-short assert assoc assoc! assoc-in associative? ' +
            'atom await await-for await1 bases bean bigdec bigint binding bit-and ' +
            'bit-and-not bit-clear bit-flip bit-not bit-or bit-set bit-shift-left ' +
            'bit-shift-right bit-test bit-xor boolean boolean-array booleans ' +
            'bound-fn bound-fn* butlast byte byte-array bytes cast char char-array ' +
            'char-escape-string char-name-string char? chars chunk chunk-append ' +
            'chunk-buffer chunk-cons chunk-first chunk-next chunk-rest chunked-seq? ' +
            'class class? clear-agent-errors clojure-version coll? comment commute ' +
            'comp comparator compare compare-and-set! compile complement concat cond ' +
            'condp conj conj! cons constantly construct-proxy contains? count ' +
            'counted? create-ns create-struct cycle dec decimal? declare definline ' +
            'defmacro defmethod defmulti defn defn- defonce defstruct delay delay? ' +
            'deliver deref derive descendants destructure disj disj! dissoc dissoc! ' +
            'distinct distinct? doall doc dorun doseq dosync dotimes doto double ' +
            'double-array doubles drop drop-last drop-while empty empty? ensure ' +
            'enumeration-seq eval even? every? false? ffirst file-seq filter find ' +
            'find-doc find-ns find-var first float float-array float? floats flush ' +
            'fn fn? fnext for force format future future-call future-cancel ' +
            'future-cancelled? future-done? future? gen-class gen-interface gensym ' +
            'get get-in get-method get-proxy-class get-thread-bindings get-validator ' +
            'hash hash-map hash-set identical? identity if-let if-not ifn? import ' +
            'in-ns inc init-proxy instance? int int-array integer? interleave intern ' +
            'interpose into into-array ints io! isa? iterate iterator-seq juxt key ' +
            'keys keyword keyword? last lazy-cat lazy-seq let letfn line-seq list ' +
            'list* list? load load-file load-reader load-string loaded-libs locking ' +
            'long long-array longs loop macroexpand macroexpand-1 make-array ' +
            'make-hierarchy map map? mapcat max max-key memfn memoize merge ' +
            'merge-with meta method-sig methods min min-key mod name namespace neg? ' +
            'newline next nfirst nil? nnext not not-any? not-empty not-every? not= ' +
            'ns ns-aliases ns-imports ns-interns ns-map ns-name ns-publics ' +
            'ns-refers ns-resolve ns-unalias ns-unmap nth nthnext num number? odd? ' +
            'or parents partial partition pcalls peek persistent! pmap pop pop! ' +
            'pop-thread-bindings pos? pr pr-str prefer-method prefers ' +
            'primitives-classnames print print-ctor print-doc print-dup print-method ' +
            'print-namespace-doc print-simple print-special-doc print-str printf ' +
            'println println-str prn prn-str promise proxy proxy-call-with-super ' +
            'proxy-mappings proxy-name proxy-super push-thread-bindings pvalues quot ' +
            'rand rand-int range ratio? rational? rationalize re-find re-groups ' +
            're-matcher re-matches re-pattern re-seq read read-line read-string ' +
            'reduce ref ref-history-count ref-max-history ref-min-history ref-set ' +
            'refer refer-clojure release-pending-sends rem remove remove-method ' +
            'remove-ns remove-watch repeat repeatedly replace replicate require ' +
            'reset! reset-meta! resolve rest resultset-seq reverse reversible? rseq ' +
            'rsubseq second select-keys send send-off seq seq? seque sequence ' +
            'sequential? set set-validator! set? short short-array shorts ' +
            'shutdown-agents slurp some sort sort-by sorted-map sorted-map-by ' +
            'sorted-set sorted-set-by sorted? special-form-anchor special-symbol? ' +
            'split-at split-with str stream? string? struct struct-map subs subseq ' +
            'subvec supers swap! symbol symbol? sync syntax-symbol-anchor take ' +
            'take-last take-nth take-while test the-ns time to-array to-array-2d ' +
            'trampoline transient tree-seq true? type unchecked-add unchecked-dec ' +
            'unchecked-divide unchecked-inc unchecked-multiply unchecked-negate ' +
            'unchecked-remainder unchecked-subtract underive unquote ' +
            'unquote-splicing update-in update-proxy use val vals var-get var-set ' +
            'var? vary-meta vec vector vector? when when-first when-let when-not ' +
            'while with-bindings with-bindings* with-in-str with-loading-context ' +
            'with-local-vars with-meta with-open with-out-str with-precision xml-seq ' +
            'zero? zipmap ').split(" ")
    );

    var keywords = lang.arrayToMap(
        ('def do fn if let loop monitor-enter monitor-exit new quote recur set! ' +
            'throw try var').split(" ")
    );

    var buildinConstants = lang.arrayToMap(
        ("true false nil").split(" ")
    );


    // regexp must not have capturing parentheses. Use (?:) instead.
    // regexps are ordered -> the first match is used

    this.$rules = {
        "start" : [
            {
                token : "comment",
                regex : ";.*$"
            }, {
                    token : "comment", // multi line comment
                    regex : "^\=begin$",
                    next : "comment"
            }, {
                token : "keyword", //parens
                regex : "[\\(|\\)]"
            }, {
                token : "keyword", //lists
                regex : "[\\'\\(]"
            }, {
                token : "keyword", //vectors
                regex : "[\\[|\\]]"
            }, {
                token : "keyword", //sets and maps
                regex : "[\\{|\\}|\\#\\{|\\#\\}]"
            }, {
                    token : "keyword", // ampersands
                    regex : '[\\&]'
            }, {
                    token : "keyword", // metadata
                    regex : '[\\#\\^\\{]'
            }, {
                    token : "keyword", // anonymous fn syntactic sugar
                    regex : '[\\%]'
            }, {
                    token : "keyword", // deref reader macro
                    regex : '[@]'
            }, {
                token : "constant.numeric", // hex
                regex : "0[xX][0-9a-fA-F]+\\b"
            }, {
                token : "constant.numeric", // float
                regex : "[+-]?\\d+(?:(?:\\.\\d*)?(?:[eE][+-]?\\d+)?)?\\b"
            }, {
                token : "constant.language",
                regex : '[!|\\$|%|&|\\*|\\-\\-|\\-|\\+\\+|\\+||=|!=|<=|>=|<>|<|>|!|&&]'
            }, {
                token : function(value) {
                    if (keywords.hasOwnProperty(value))
                        return "keyword";
                    else if (buildinConstants.hasOwnProperty(value))
                        return "constant.language";
                        else if (builtinFunctions.hasOwnProperty(value))
                        return "support.function";
                    else
                        return "identifier";
                },
                // TODO: Unicode escape sequences
                // TODO: Unicode identifiers
                regex : "[a-zA-Z_$][a-zA-Z0-9_$]*\\b"
            }, {
                token : "string", // single line
                regex : '["](?:(?:\\\\.)|(?:[^"\\\\]))*?["]'
            }, {
                token : "string", // symbol
                regex : "[:](?:[a-zA-Z]|\d)+"
            }, {
            token : "string.regexp", //Regular Expressions
            regex : '/#"(?:\.|(\\\")|[^\""\n])*"/g'
            }
              
        ],
        "comment" : [
            {
                token : "comment", // closing comment
                regex : "^\=end$",
                next : "start"
            }, {
                token : "comment", // comment spanning whole line
                merge : true,
                regex : ".+"
            }
        ]
    };
};

oop.inherits(ClojureHighlightRules, TextHighlightRules);

exports.ClojureHighlightRules = ClojureHighlightRules;
});
