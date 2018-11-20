/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { ExtHostCommands } from 'vs/workbench/api/node/extHostCommands';
import { MainThreadCommandsShape } from 'vs/workbench/api/node/extHost.protocol';
import { CommandsRegistry } from 'vs/platform/commands/common/commands';
import { SingleProxyRPCProtocol } from './testRPCProtocol';
import { mock } from 'vs/workbench/test/electron-browser/api/mock';
import { NullLogService } from 'vs/platform/log/common/log';

suite('ExtHostCommands', function () {

	test('dispose calls unregister', function () {

		let lastUnregister: string;

		const shape = new class extends mock<MainThreadCommandsShape>() {
			$registerCommand(id: string): void {
				//
			}
			$unregisterCommand(id: string): void {
				lastUnregister = id;
			}
		};

		const commands = new ExtHostCommands(SingleProxyRPCProtocol(shape), undefined, new NullLogService());
		commands.registerCommand(true, 'foo', (): any => { }).dispose();
		assert.equal(lastUnregister, 'foo');
		assert.equal(CommandsRegistry.getCommand('foo'), undefined);

	});

	test('dispose bubbles only once', function () {

		let unregisterCounter = 0;

		const shape = new class extends mock<MainThreadCommandsShape>() {
			$registerCommand(id: string): void {
				//
			}
			$unregisterCommand(id: string): void {
				unregisterCounter += 1;
			}
		};

		const commands = new ExtHostCommands(SingleProxyRPCProtocol(shape), undefined, new NullLogService());
		const reg = commands.registerCommand(true, 'foo', (): any => { });
		reg.dispose();
		reg.dispose();
		reg.dispose();
		assert.equal(unregisterCounter, 1);
	});
});
