/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { MainThreadMessageService } from 'vs/workbench/api/electron-browser/mainThreadMessageService';
import { IDialogService } from 'vs/platform/dialogs/common/dialogs';
import { INotificationService, INotification, NoOpNotification, INotificationHandle, Severity, IPromptChoice, IPromptOptions } from 'vs/platform/notification/common/notification';
import { ICommandService } from 'vs/platform/commands/common/commands';
import { mock } from 'vs/workbench/test/electron-browser/api/mock';

const emptyDialogService = new class implements IDialogService {
	_serviceBrand: 'dialogService';
	show(): never {
		throw new Error('not implemented');
	}

	confirm(): never {
		throw new Error('not implemented');
	}
};

const emptyCommandService: ICommandService = {
	_serviceBrand: undefined,
	onWillExecuteCommand: () => ({ dispose: () => { } }),
	executeCommand: (commandId: string, ...args: any[]): Promise<any> => {
		return Promise.resolve(void 0);
	}
};

const emptyNotificationService = new class implements INotificationService {
	_serviceBrand: 'notificiationService';
	notify(...args: any[]): never {
		throw new Error('not implemented');
	}
	info(...args: any[]): never {
		throw new Error('not implemented');
	}
	warn(...args: any[]): never {
		throw new Error('not implemented');
	}
	error(...args: any[]): never {
		throw new Error('not implemented');
	}
	prompt(severity: Severity, message: string, choices: IPromptChoice[], options?: IPromptOptions): INotificationHandle {
		throw new Error('not implemented');
	}
};

class EmptyNotificationService implements INotificationService {

	_serviceBrand: any;

	constructor(private withNotify: (notification: INotification) => void) {
	}

	notify(notification: INotification): INotificationHandle {
		this.withNotify(notification);

		return new NoOpNotification();
	}
	info(message: any): void {
		throw new Error('Method not implemented.');
	}
	warn(message: any): void {
		throw new Error('Method not implemented.');
	}
	error(message: any): void {
		throw new Error('Method not implemented.');
	}
	prompt(severity: Severity, message: string, choices: IPromptChoice[], options?: IPromptOptions): INotificationHandle {
		throw new Error('not implemented');
	}
}

suite('ExtHostMessageService', function () {

	test('propagte handle on select', async function () {

		let service = new MainThreadMessageService(null, new EmptyNotificationService(notification => {
			assert.equal(notification.actions.primary.length, 1);
			setImmediate(() => notification.actions.primary[0].run());
		}), emptyCommandService, emptyDialogService);

		const handle = await service.$showMessage(1, 'h', {}, [{ handle: 42, title: 'a thing', isCloseAffordance: true }]);
		assert.equal(handle, 42);
	});

	suite('modal', () => {
		test('calls dialog service', async () => {
			const service = new MainThreadMessageService(null, emptyNotificationService, emptyCommandService, new class extends mock<IDialogService>() {
				show(severity, message, buttons) {
					assert.equal(severity, 1);
					assert.equal(message, 'h');
					assert.equal(buttons.length, 2);
					assert.equal(buttons[1], 'Cancel');
					return Promise.resolve(0);
				}
			} as IDialogService);

			const handle = await service.$showMessage(1, 'h', { modal: true }, [{ handle: 42, title: 'a thing', isCloseAffordance: false }]);
			assert.equal(handle, 42);
		});

		test('returns undefined when cancelled', async () => {
			const service = new MainThreadMessageService(null, emptyNotificationService, emptyCommandService, new class extends mock<IDialogService>() {
				show(severity, message, buttons) {
					return Promise.resolve(1);
				}
			} as IDialogService);

			const handle = await service.$showMessage(1, 'h', { modal: true }, [{ handle: 42, title: 'a thing', isCloseAffordance: false }]);
			assert.equal(handle, undefined);
		});

		test('hides Cancel button when not needed', async () => {
			const service = new MainThreadMessageService(null, emptyNotificationService, emptyCommandService, new class extends mock<IDialogService>() {
				show(severity, message, buttons) {
					assert.equal(buttons.length, 1);
					return Promise.resolve(0);
				}
			} as IDialogService);

			const handle = await service.$showMessage(1, 'h', { modal: true }, [{ handle: 42, title: 'a thing', isCloseAffordance: true }]);
			assert.equal(handle, 42);
		});
	});
});
