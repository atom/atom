/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { URI, UriComponents } from 'vs/base/common/uri';
import { DiagnosticCollection, ExtHostDiagnostics } from 'vs/workbench/api/node/extHostDiagnostics';
import { Diagnostic, DiagnosticSeverity, Range, DiagnosticRelatedInformation, Location } from 'vs/workbench/api/node/extHostTypes';
import { MainThreadDiagnosticsShape, IMainContext } from 'vs/workbench/api/node/extHost.protocol';
import { IMarkerData, MarkerSeverity } from 'vs/platform/markers/common/markers';
import { mock } from 'vs/workbench/test/electron-browser/api/mock';
import { Emitter, toPromise } from 'vs/base/common/event';

suite('ExtHostDiagnostics', () => {

	class DiagnosticsShape extends mock<MainThreadDiagnosticsShape>() {
		$changeMany(owner: string, entries: [UriComponents, IMarkerData[]][]): void {
			//
		}
		$clear(owner: string): void {
			//
		}
	}

	test('disposeCheck', () => {

		const collection = new DiagnosticCollection('test', 'test', 100, new DiagnosticsShape(), new Emitter());

		collection.dispose();
		collection.dispose(); // that's OK
		assert.throws(() => collection.name);
		assert.throws(() => collection.clear());
		assert.throws(() => collection.delete(URI.parse('aa:bb')));
		// tslint:disable-next-line:semicolon
		assert.throws(() => collection.forEach(() => { ; }));
		assert.throws(() => collection.get(URI.parse('aa:bb')));
		assert.throws(() => collection.has(URI.parse('aa:bb')));
		assert.throws(() => collection.set(URI.parse('aa:bb'), []));
		assert.throws(() => collection.set(URI.parse('aa:bb'), undefined));
	});


	test('diagnostic collection, forEach, clear, has', function () {
		let collection = new DiagnosticCollection('test', 'test', 100, new DiagnosticsShape(), new Emitter());
		assert.equal(collection.name, 'test');
		collection.dispose();
		assert.throws(() => collection.name);

		let c = 0;
		collection = new DiagnosticCollection('test', 'test', 100, new DiagnosticsShape(), new Emitter());
		collection.forEach(() => c++);
		assert.equal(c, 0);

		collection.set(URI.parse('foo:bar'), [
			new Diagnostic(new Range(0, 0, 1, 1), 'message-1'),
			new Diagnostic(new Range(0, 0, 1, 1), 'message-2')
		]);
		collection.forEach(() => c++);
		assert.equal(c, 1);

		c = 0;
		collection.clear();
		collection.forEach(() => c++);
		assert.equal(c, 0);

		collection.set(URI.parse('foo:bar1'), [
			new Diagnostic(new Range(0, 0, 1, 1), 'message-1'),
			new Diagnostic(new Range(0, 0, 1, 1), 'message-2')
		]);
		collection.set(URI.parse('foo:bar2'), [
			new Diagnostic(new Range(0, 0, 1, 1), 'message-1'),
			new Diagnostic(new Range(0, 0, 1, 1), 'message-2')
		]);
		collection.forEach(() => c++);
		assert.equal(c, 2);

		assert.ok(collection.has(URI.parse('foo:bar1')));
		assert.ok(collection.has(URI.parse('foo:bar2')));
		assert.ok(!collection.has(URI.parse('foo:bar3')));
		collection.delete(URI.parse('foo:bar1'));
		assert.ok(!collection.has(URI.parse('foo:bar1')));

		collection.dispose();
	});

	test('diagnostic collection, immutable read', function () {
		let collection = new DiagnosticCollection('test', 'test', 100, new DiagnosticsShape(), new Emitter());
		collection.set(URI.parse('foo:bar'), [
			new Diagnostic(new Range(0, 0, 1, 1), 'message-1'),
			new Diagnostic(new Range(0, 0, 1, 1), 'message-2')
		]);

		let array = collection.get(URI.parse('foo:bar'));
		assert.throws(() => array.length = 0);
		assert.throws(() => array.pop());
		assert.throws(() => array[0] = new Diagnostic(new Range(0, 0, 0, 0), 'evil'));

		collection.forEach((uri, array) => {
			assert.throws(() => array.length = 0);
			assert.throws(() => array.pop());
			assert.throws(() => array[0] = new Diagnostic(new Range(0, 0, 0, 0), 'evil'));
		});

		array = collection.get(URI.parse('foo:bar'));
		assert.equal(array.length, 2);

		collection.dispose();
	});


	test('diagnostics collection, set with dupliclated tuples', function () {
		let collection = new DiagnosticCollection('test', 'test', 100, new DiagnosticsShape(), new Emitter());
		let uri = URI.parse('sc:hightower');
		collection.set([
			[uri, [new Diagnostic(new Range(0, 0, 0, 1), 'message-1')]],
			[URI.parse('some:thing'), [new Diagnostic(new Range(0, 0, 1, 1), 'something')]],
			[uri, [new Diagnostic(new Range(0, 0, 0, 1), 'message-2')]],
		]);

		let array = collection.get(uri);
		assert.equal(array.length, 2);
		let [first, second] = array;
		assert.equal(first.message, 'message-1');
		assert.equal(second.message, 'message-2');

		// clear
		collection.delete(uri);
		assert.ok(!collection.has(uri));

		// bad tuple clears 1/2
		collection.set([
			[uri, [new Diagnostic(new Range(0, 0, 0, 1), 'message-1')]],
			[URI.parse('some:thing'), [new Diagnostic(new Range(0, 0, 1, 1), 'something')]],
			[uri, undefined]
		]);
		assert.ok(!collection.has(uri));

		// clear
		collection.delete(uri);
		assert.ok(!collection.has(uri));

		// bad tuple clears 2/2
		collection.set([
			[uri, [new Diagnostic(new Range(0, 0, 0, 1), 'message-1')]],
			[URI.parse('some:thing'), [new Diagnostic(new Range(0, 0, 1, 1), 'something')]],
			[uri, undefined],
			[uri, [new Diagnostic(new Range(0, 0, 0, 1), 'message-2')]],
			[uri, [new Diagnostic(new Range(0, 0, 0, 1), 'message-3')]],
		]);

		array = collection.get(uri);
		assert.equal(array.length, 2);
		[first, second] = array;
		assert.equal(first.message, 'message-2');
		assert.equal(second.message, 'message-3');

		collection.dispose();
	});

	test('diagnostics collection, set tuple overrides, #11547', function () {

		let lastEntries: [UriComponents, IMarkerData[]][];
		let collection = new DiagnosticCollection('test', 'test', 100, new class extends DiagnosticsShape {
			$changeMany(owner: string, entries: [UriComponents, IMarkerData[]][]): void {
				lastEntries = entries;
				return super.$changeMany(owner, entries);
			}
		}, new Emitter());
		let uri = URI.parse('sc:hightower');

		collection.set([[uri, [new Diagnostic(new Range(0, 0, 1, 1), 'error')]]]);
		assert.equal(collection.get(uri).length, 1);
		assert.equal(collection.get(uri)[0].message, 'error');
		assert.equal(lastEntries.length, 1);
		let [[, data1]] = lastEntries;
		assert.equal(data1.length, 1);
		assert.equal(data1[0].message, 'error');
		lastEntries = undefined;

		collection.set([[uri, [new Diagnostic(new Range(0, 0, 1, 1), 'warning')]]]);
		assert.equal(collection.get(uri).length, 1);
		assert.equal(collection.get(uri)[0].message, 'warning');
		assert.equal(lastEntries.length, 1);
		let [[, data2]] = lastEntries;
		assert.equal(data2.length, 1);
		assert.equal(data2[0].message, 'warning');
		lastEntries = undefined;
	});

	test('don\'t send message when not making a change', function () {

		let changeCount = 0;
		let eventCount = 0;

		const emitter = new Emitter<any>();
		emitter.event(_ => eventCount += 1);
		const collection = new DiagnosticCollection('test', 'test', 100, new class extends DiagnosticsShape {
			$changeMany() {
				changeCount += 1;
			}
		}, emitter);

		let uri = URI.parse('sc:hightower');
		let diag = new Diagnostic(new Range(0, 0, 0, 1), 'ffff');

		collection.set(uri, [diag]);
		assert.equal(changeCount, 1);
		assert.equal(eventCount, 1);

		collection.set(uri, [diag]);
		assert.equal(changeCount, 1);
		assert.equal(eventCount, 2);
	});

	test('diagnostics collection, tuples and undefined (small array), #15585', function () {

		const collection = new DiagnosticCollection('test', 'test', 100, new DiagnosticsShape(), new Emitter());
		let uri = URI.parse('sc:hightower');
		let uri2 = URI.parse('sc:nomad');
		let diag = new Diagnostic(new Range(0, 0, 0, 1), 'ffff');

		collection.set([
			[uri, [diag, diag, diag]],
			[uri, undefined],
			[uri, [diag]],

			[uri2, [diag, diag]],
			[uri2, undefined],
			[uri2, [diag]],
		]);

		assert.equal(collection.get(uri).length, 1);
		assert.equal(collection.get(uri2).length, 1);
	});

	test('diagnostics collection, tuples and undefined (large array), #15585', function () {

		const collection = new DiagnosticCollection('test', 'test', 100, new DiagnosticsShape(), new Emitter());
		const tuples: [URI, Diagnostic[]][] = [];

		for (let i = 0; i < 500; i++) {
			let uri = URI.parse('sc:hightower#' + i);
			let diag = new Diagnostic(new Range(0, 0, 0, 1), i.toString());

			tuples.push([uri, [diag, diag, diag]]);
			tuples.push([uri, undefined]);
			tuples.push([uri, [diag]]);
		}

		collection.set(tuples);

		for (let i = 0; i < 500; i++) {
			let uri = URI.parse('sc:hightower#' + i);
			assert.equal(collection.has(uri), true);
			assert.equal(collection.get(uri).length, 1);
		}
	});

	test('diagnostic capping', function () {

		let lastEntries: [UriComponents, IMarkerData[]][];
		let collection = new DiagnosticCollection('test', 'test', 250, new class extends DiagnosticsShape {
			$changeMany(owner: string, entries: [UriComponents, IMarkerData[]][]): void {
				lastEntries = entries;
				return super.$changeMany(owner, entries);
			}
		}, new Emitter());
		let uri = URI.parse('aa:bb');

		let diagnostics: Diagnostic[] = [];
		for (let i = 0; i < 500; i++) {
			diagnostics.push(new Diagnostic(new Range(i, 0, i + 1, 0), `error#${i}`, i < 300
				? DiagnosticSeverity.Warning
				: DiagnosticSeverity.Error));
		}

		collection.set(uri, diagnostics);
		assert.equal(collection.get(uri).length, 500);
		assert.equal(lastEntries.length, 1);
		assert.equal(lastEntries[0][1].length, 251);
		assert.equal(lastEntries[0][1][0].severity, MarkerSeverity.Error);
		assert.equal(lastEntries[0][1][200].severity, MarkerSeverity.Warning);
		assert.equal(lastEntries[0][1][250].severity, MarkerSeverity.Info);
	});

	test('diagnostic eventing', async function () {
		let emitter = new Emitter<(string | URI)[]>();
		let collection = new DiagnosticCollection('ddd', 'test', 100, new DiagnosticsShape(), emitter);

		let diag1 = new Diagnostic(new Range(1, 1, 2, 3), 'diag1');
		let diag2 = new Diagnostic(new Range(1, 1, 2, 3), 'diag2');
		let diag3 = new Diagnostic(new Range(1, 1, 2, 3), 'diag3');

		let p = toPromise(emitter.event).then(a => {
			assert.equal(a.length, 1);
			assert.equal(a[0].toString(), 'aa:bb');
			assert.ok(URI.isUri(a[0]));
		});
		collection.set(URI.parse('aa:bb'), []);
		await p;

		p = toPromise(emitter.event).then(e => {
			assert.equal(e.length, 2);
			assert.ok(URI.isUri(e[0]));
			assert.ok(URI.isUri(e[1]));
			assert.equal(e[0].toString(), 'aa:bb');
			assert.equal(e[1].toString(), 'aa:cc');
		});
		collection.set([
			[URI.parse('aa:bb'), [diag1]],
			[URI.parse('aa:cc'), [diag2, diag3]],
		]);
		await p;

		p = toPromise(emitter.event).then(e => {
			assert.equal(e.length, 2);
			assert.ok(typeof e[0] === 'string');
			assert.ok(typeof e[1] === 'string');
		});
		collection.clear();
		await p;
	});

	test('vscode.languages.onDidChangeDiagnostics Does Not Provide Document URI #49582', async function () {
		let emitter = new Emitter<(string | URI)[]>();
		let collection = new DiagnosticCollection('ddd', 'test', 100, new DiagnosticsShape(), emitter);

		let diag1 = new Diagnostic(new Range(1, 1, 2, 3), 'diag1');

		// delete
		collection.set(URI.parse('aa:bb'), [diag1]);
		let p = toPromise(emitter.event).then(e => {
			assert.equal(e[0].toString(), 'aa:bb');
		});
		collection.delete(URI.parse('aa:bb'));
		await p;

		// set->undefined (as delete)
		collection.set(URI.parse('aa:bb'), [diag1]);
		p = toPromise(emitter.event).then(e => {
			assert.equal(e[0].toString(), 'aa:bb');
		});
		collection.set(URI.parse('aa:bb'), undefined);
		await p;
	});

	test('diagnostics with related information', function (done) {

		let collection = new DiagnosticCollection('ddd', 'test', 100, new class extends DiagnosticsShape {
			$changeMany(owner: string, entries: [UriComponents, IMarkerData[]][]) {

				let [[, data]] = entries;
				assert.equal(entries.length, 1);
				assert.equal(data.length, 1);

				let [diag] = data;
				assert.equal(diag.relatedInformation.length, 2);
				assert.equal(diag.relatedInformation[0].message, 'more1');
				assert.equal(diag.relatedInformation[1].message, 'more2');
				done();
			}
		}, new Emitter<any>());

		let diag = new Diagnostic(new Range(0, 0, 1, 1), 'Foo');
		diag.relatedInformation = [
			new DiagnosticRelatedInformation(new Location(URI.parse('cc:dd'), new Range(0, 0, 0, 0)), 'more1'),
			new DiagnosticRelatedInformation(new Location(URI.parse('cc:ee'), new Range(0, 0, 0, 0)), 'more2')
		];

		collection.set(URI.parse('aa:bb'), [diag]);
	});

	test('vscode.languages.getDiagnostics appears to return old diagnostics in some circumstances #54359', function () {
		const ownerHistory: string[] = [];
		const diags = new ExtHostDiagnostics(new class implements IMainContext {
			getProxy(id: any): any {
				return new class DiagnosticsShape {
					$clear(owner: string): void {
						ownerHistory.push(owner);
					}
				};
			}
			set(): any {
				return null;
			}
			assertRegistered(): void {

			}
		});

		let collection1 = diags.createDiagnosticCollection('foo');
		let collection2 = diags.createDiagnosticCollection('foo'); // warns, uses a different owner

		collection1.clear();
		collection2.clear();

		assert.equal(ownerHistory.length, 2);
		assert.equal(ownerHistory[0], 'foo');
		assert.equal(ownerHistory[1], 'foo0');
	});

	test('Error updating diagnostics from extension #60394', function () {
		let callCount = 0;
		let collection = new DiagnosticCollection('ddd', 'test', 100, new class extends DiagnosticsShape {
			$changeMany(owner: string, entries: [UriComponents, IMarkerData[]][]) {
				callCount += 1;
			}
		}, new Emitter<any>());

		let array: Diagnostic[] = [];
		let diag1 = new Diagnostic(new Range(0, 0, 1, 1), 'Foo');
		let diag2 = new Diagnostic(new Range(0, 0, 1, 1), 'Bar');

		array.push(diag1, diag2);

		collection.set(URI.parse('test:me'), array);
		assert.equal(callCount, 1);

		collection.set(URI.parse('test:me'), array);
		assert.equal(callCount, 1); // equal array

		array.push(diag2);
		collection.set(URI.parse('test:me'), array);
		assert.equal(callCount, 2); // same but un-equal array
	});
});
