/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { ReplacePattern, ReplacePiece, parseReplaceString } from 'vs/editor/contrib/find/replacePattern';

suite('Replace Pattern test', () => {

	test('parse replace string', () => {
		let testParse = (input: string, expectedPieces: ReplacePiece[]) => {
			let actual = parseReplaceString(input);
			let expected = new ReplacePattern(expectedPieces);
			assert.deepEqual(actual, expected, 'Parsing ' + input);
		};

		// no backslash => no treatment
		testParse('hello', [ReplacePiece.staticValue('hello')]);

		// \t => TAB
		testParse('\\thello', [ReplacePiece.staticValue('\thello')]);
		testParse('h\\tello', [ReplacePiece.staticValue('h\tello')]);
		testParse('hello\\t', [ReplacePiece.staticValue('hello\t')]);

		// \n => LF
		testParse('\\nhello', [ReplacePiece.staticValue('\nhello')]);

		// \\t => \t
		testParse('\\\\thello', [ReplacePiece.staticValue('\\thello')]);
		testParse('h\\\\tello', [ReplacePiece.staticValue('h\\tello')]);
		testParse('hello\\\\t', [ReplacePiece.staticValue('hello\\t')]);

		// \\\t => \TAB
		testParse('\\\\\\thello', [ReplacePiece.staticValue('\\\thello')]);

		// \\\\t => \\t
		testParse('\\\\\\\\thello', [ReplacePiece.staticValue('\\\\thello')]);

		// \ at the end => no treatment
		testParse('hello\\', [ReplacePiece.staticValue('hello\\')]);

		// \ with unknown char => no treatment
		testParse('hello\\x', [ReplacePiece.staticValue('hello\\x')]);

		// \ with back reference => no treatment
		testParse('hello\\0', [ReplacePiece.staticValue('hello\\0')]);

		testParse('hello$&', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(0)]);
		testParse('hello$0', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(0)]);
		testParse('hello$02', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(0), ReplacePiece.staticValue('2')]);
		testParse('hello$1', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(1)]);
		testParse('hello$2', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(2)]);
		testParse('hello$9', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(9)]);
		testParse('$9hello', [ReplacePiece.matchIndex(9), ReplacePiece.staticValue('hello')]);

		testParse('hello$12', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(12)]);
		testParse('hello$99', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(99)]);
		testParse('hello$99a', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(99), ReplacePiece.staticValue('a')]);
		testParse('hello$1a', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(1), ReplacePiece.staticValue('a')]);
		testParse('hello$100', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(10), ReplacePiece.staticValue('0')]);
		testParse('hello$100a', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(10), ReplacePiece.staticValue('0a')]);
		testParse('hello$10a0', [ReplacePiece.staticValue('hello'), ReplacePiece.matchIndex(10), ReplacePiece.staticValue('a0')]);
		testParse('hello$$', [ReplacePiece.staticValue('hello$')]);
		testParse('hello$$0', [ReplacePiece.staticValue('hello$0')]);

		testParse('hello$`', [ReplacePiece.staticValue('hello$`')]);
		testParse('hello$\'', [ReplacePiece.staticValue('hello$\'')]);
	});

	test('replace has JavaScript semantics', () => {
		let testJSReplaceSemantics = (target: string, search: RegExp, replaceString: string, expected: string) => {
			let replacePattern = parseReplaceString(replaceString);
			let m = search.exec(target);
			let actual = replacePattern.buildReplaceString(m);

			assert.deepEqual(actual, expected, `${target}.replace(${search}, ${replaceString})`);
		};

		testJSReplaceSemantics('hi', /hi/, 'hello', 'hi'.replace(/hi/, 'hello'));
		testJSReplaceSemantics('hi', /hi/, '\\t', 'hi'.replace(/hi/, '\t'));
		testJSReplaceSemantics('hi', /hi/, '\\n', 'hi'.replace(/hi/, '\n'));
		testJSReplaceSemantics('hi', /hi/, '\\\\t', 'hi'.replace(/hi/, '\\t'));
		testJSReplaceSemantics('hi', /hi/, '\\\\n', 'hi'.replace(/hi/, '\\n'));

		// implicit capture group 0
		testJSReplaceSemantics('hi', /hi/, 'hello$&', 'hi'.replace(/hi/, 'hello$&'));
		testJSReplaceSemantics('hi', /hi/, 'hello$0', 'hi'.replace(/hi/, 'hello$&'));
		testJSReplaceSemantics('hi', /hi/, 'hello$&1', 'hi'.replace(/hi/, 'hello$&1'));
		testJSReplaceSemantics('hi', /hi/, 'hello$01', 'hi'.replace(/hi/, 'hello$&1'));

		// capture groups have funny semantics in replace strings
		// the replace string interprets $nn as a captured group only if it exists in the search regex
		testJSReplaceSemantics('hi', /(hi)/, 'hello$10', 'hi'.replace(/(hi)/, 'hello$10'));
		testJSReplaceSemantics('hi', /(hi)()()()()()()()()()/, 'hello$10', 'hi'.replace(/(hi)()()()()()()()()()/, 'hello$10'));
		testJSReplaceSemantics('hi', /(hi)/, 'hello$100', 'hi'.replace(/(hi)/, 'hello$100'));
		testJSReplaceSemantics('hi', /(hi)/, 'hello$20', 'hi'.replace(/(hi)/, 'hello$20'));
	});

	test('get replace string if given text is a complete match', () => {
		function assertReplace(target: string, search: RegExp, replaceString: string, expected: string): void {
			let replacePattern = parseReplaceString(replaceString);
			let m = search.exec(target);
			let actual = replacePattern.buildReplaceString(m);

			assert.equal(actual, expected, `${target}.replace(${search}, ${replaceString}) === ${expected}`);
		}

		assertReplace('bla', /bla/, 'hello', 'hello');
		assertReplace('bla', /(bla)/, 'hello', 'hello');
		assertReplace('bla', /(bla)/, 'hello$0', 'hellobla');

		let searchRegex = /let\s+(\w+)\s*=\s*require\s*\(\s*['"]([\w\.\-/]+)\s*['"]\s*\)\s*/;
		assertReplace('let fs = require(\'fs\')', searchRegex, 'import * as $1 from \'$2\';', 'import * as fs from \'fs\';');
		assertReplace('let something = require(\'fs\')', searchRegex, 'import * as $1 from \'$2\';', 'import * as something from \'fs\';');
		assertReplace('let something = require(\'fs\')', searchRegex, 'import * as $1 from \'$1\';', 'import * as something from \'something\';');
		assertReplace('let something = require(\'fs\')', searchRegex, 'import * as $2 from \'$1\';', 'import * as fs from \'something\';');
		assertReplace('let something = require(\'fs\')', searchRegex, 'import * as $0 from \'$0\';', 'import * as let something = require(\'fs\') from \'let something = require(\'fs\')\';');
		assertReplace('let fs = require(\'fs\')', searchRegex, 'import * as $1 from \'$2\';', 'import * as fs from \'fs\';');
		assertReplace('for ()', /for(.*)/, 'cat$1', 'cat ()');

		// issue #18111
		assertReplace('HRESULT OnAmbientPropertyChange(DISPID   dispid);', /\b\s{3}\b/, ' ', ' ');
	});

	test('get replace string if match is sub-string of the text', () => {
		function assertReplace(target: string, search: RegExp, replaceString: string, expected: string): void {
			let replacePattern = parseReplaceString(replaceString);
			let m = search.exec(target);
			let actual = replacePattern.buildReplaceString(m);

			assert.equal(actual, expected, `${target}.replace(${search}, ${replaceString}) === ${expected}`);
		}
		assertReplace('this is a bla text', /bla/, 'hello', 'hello');
		assertReplace('this is a bla text', /this(?=.*bla)/, 'that', 'that');
		assertReplace('this is a bla text', /(th)is(?=.*bla)/, '$1at', 'that');
		assertReplace('this is a bla text', /(th)is(?=.*bla)/, '$1e', 'the');
		assertReplace('this is a bla text', /(th)is(?=.*bla)/, '$1ere', 'there');
		assertReplace('this is a bla text', /(th)is(?=.*bla)/, '$1', 'th');
		assertReplace('this is a bla text', /(th)is(?=.*bla)/, 'ma$1', 'math');
		assertReplace('this is a bla text', /(th)is(?=.*bla)/, 'ma$1s', 'maths');
		assertReplace('this is a bla text', /(th)is(?=.*bla)/, '$0', 'this');
		assertReplace('this is a bla text', /(th)is(?=.*bla)/, '$0$1', 'thisth');
		assertReplace('this is a bla text', /bla(?=\stext$)/, 'foo', 'foo');
		assertReplace('this is a bla text', /b(la)(?=\stext$)/, 'f$1', 'fla');
		assertReplace('this is a bla text', /b(la)(?=\stext$)/, 'f$0', 'fbla');
		assertReplace('this is a bla text', /b(la)(?=\stext$)/, '$0ah', 'blaah');
	});

	test('issue #19740 Find and replace capture group/backreference inserts `undefined` instead of empty string', () => {
		let replacePattern = parseReplaceString('a{$1}');
		let matches = /a(z)?/.exec('abcd');
		let actual = replacePattern.buildReplaceString(matches);
		assert.equal(actual, 'a{}');
	});
});
