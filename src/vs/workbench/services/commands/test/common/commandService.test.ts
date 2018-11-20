/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as assert from 'assert';
import { IDisposable, dispose } from 'vs/base/common/lifecycle';
import { CommandsRegistry } from 'vs/platform/commands/common/commands';
import { CommandService } from 'vs/workbench/services/commands/common/commandService';
import { IExtensionService, ExtensionPointContribution, IExtensionDescription, ProfileSession } from 'vs/workbench/services/extensions/common/extensions';
import { InstantiationService } from 'vs/platform/instantiation/common/instantiationService';
import { IExtensionPoint } from 'vs/workbench/services/extensions/common/extensionsRegistry';
import { Event, Emitter } from 'vs/base/common/event';
import { NullLogService } from 'vs/platform/log/common/log';

class SimpleExtensionService implements IExtensionService {
	_serviceBrand: any;
	private _onDidRegisterExtensions = new Emitter<void>();
	get onDidRegisterExtensions(): Event<void> {
		return this._onDidRegisterExtensions.event;
	}
	onDidChangeExtensionsStatus = null;
	onWillActivateByEvent = null;
	onDidChangeResponsiveChange = null;
	activateByEvent(activationEvent: string): Promise<void> {
		return this.whenInstalledExtensionsRegistered().then(() => { });
	}
	whenInstalledExtensionsRegistered(): Promise<boolean> {
		return Promise.resolve(true);
	}
	readExtensionPointContributions<T>(extPoint: IExtensionPoint<T>): Promise<ExtensionPointContribution<T>[]> {
		return Promise.resolve([]);
	}
	getExtensionsStatus() {
		return undefined;
	}
	getExtensions(): Promise<IExtensionDescription[]> {
		return Promise.resolve([]);
	}
	canProfileExtensionHost() {
		return false;
	}
	startExtensionHostProfile(): Promise<ProfileSession> {
		throw new Error('Not implemented');
	}
	getInspectPort(): number {
		return 0;
	}
	restartExtensionHost(): void {
	}
	startExtensionHost(): void {
	}
	stopExtensionHost(): void {
	}
}

suite('CommandService', function () {

	let commandRegistration: IDisposable;

	setup(function () {
		commandRegistration = CommandsRegistry.registerCommand('foo', function () { });
	});

	teardown(function () {
		commandRegistration.dispose();
	});

	test('activateOnCommand', () => {

		let lastEvent: string;

		let service = new CommandService(new InstantiationService(), new class extends SimpleExtensionService {
			activateByEvent(activationEvent: string): Promise<void> {
				lastEvent = activationEvent;
				return super.activateByEvent(activationEvent);
			}
		}, new NullLogService());

		return service.executeCommand('foo').then(() => {
			assert.ok(lastEvent, 'onCommand:foo');
			return service.executeCommand('unknownCommandId');
		}).then(() => {
			assert.ok(false);
		}, () => {
			assert.ok(lastEvent, 'onCommand:unknownCommandId');
		});
	});

	test('fwd activation error', async function () {

		const extensionService = new class extends SimpleExtensionService {
			activateByEvent(activationEvent: string): Promise<void> {
				return Promise.reject(new Error('bad_activate'));
			}
		};

		let service = new CommandService(new InstantiationService(), extensionService, new NullLogService());

		await extensionService.whenInstalledExtensionsRegistered();

		return service.executeCommand('foo').then(() => assert.ok(false), err => {
			assert.equal(err.message, 'bad_activate');
		});
	});

	test('!onReady, but executeCommand', function () {

		let callCounter = 0;
		let reg = CommandsRegistry.registerCommand('bar', () => callCounter += 1);

		let service = new CommandService(new InstantiationService(), new class extends SimpleExtensionService {
			whenInstalledExtensionsRegistered() {
				return new Promise<boolean>(_resolve => { /*ignore*/ });
			}
		}, new NullLogService());

		service.executeCommand('bar');
		assert.equal(callCounter, 1);
		reg.dispose();
	});

	test('issue #34913: !onReady, unknown command', function () {

		let callCounter = 0;
		let resolveFunc: Function;
		const whenInstalledExtensionsRegistered = new Promise<boolean>(_resolve => { resolveFunc = _resolve; });

		let service = new CommandService(new InstantiationService(), new class extends SimpleExtensionService {
			whenInstalledExtensionsRegistered() {
				return whenInstalledExtensionsRegistered;
			}
		}, new NullLogService());

		let r = service.executeCommand('bar');
		assert.equal(callCounter, 0);

		let reg = CommandsRegistry.registerCommand('bar', () => callCounter += 1);
		resolveFunc(true);

		return r.then(() => {
			reg.dispose();
			assert.equal(callCounter, 1);
		});
	});

	test('Stop waiting for * extensions to activate when trigger is satisfied #62457', function () {

		let callCounter = 0;
		let dispoables: IDisposable[] = [];
		let events: string[] = [];
		let service = new CommandService(new InstantiationService(), new class extends SimpleExtensionService {

			activateByEvent(event: string): Promise<void> {
				events.push(event);
				if (event === '*') {
					return new Promise(() => { }); //forever promise...
				}
				if (event.indexOf('onCommand:') === 0) {
					return new Promise(resolve => {
						setTimeout(() => {
							let reg = CommandsRegistry.registerCommand(event.substr('onCommand:'.length), () => {
								callCounter += 1;
							});
							dispoables.push(reg);
							resolve();
						}, 0);
					});
				}
				return Promise.resolve();
			}

		}, new NullLogService());

		return service.executeCommand('farboo').then(() => {
			assert.equal(callCounter, 1);
			assert.deepEqual(events.sort(), ['*', 'onCommand:farboo'].sort());
			dispose(dispoables);
		});
	});
});
