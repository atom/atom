/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Registry } from 'vs/platform/registry/common/platform';
import { KeybindingsRegistry, KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { ICommandHandler, CommandsRegistry } from 'vs/platform/commands/common/commands';
import { SyncActionDescriptor, MenuRegistry, MenuId } from 'vs/platform/actions/common/actions';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { IDisposable, combinedDisposable } from 'vs/base/common/lifecycle';
import { ILifecycleService, LifecyclePhase } from 'vs/platform/lifecycle/common/lifecycle';
import { INotificationService } from 'vs/platform/notification/common/notification';
import { ContextKeyExpr } from 'vs/platform/contextkey/common/contextkey';

export const Extensions = {
	WorkbenchActions: 'workbench.contributions.actions'
};

export interface IWorkbenchActionRegistry {

	/**
	 * Registers a workbench action to the platform. Workbench actions are not
	 * visible by default and can only be invoked through a keybinding if provided.
	 */
	registerWorkbenchAction(descriptor: SyncActionDescriptor, alias: string, category?: string, when?: ContextKeyExpr): IDisposable;
}

Registry.add(Extensions.WorkbenchActions, new class implements IWorkbenchActionRegistry {

	registerWorkbenchAction(descriptor: SyncActionDescriptor, alias: string, category?: string, when?: ContextKeyExpr): IDisposable {
		return this.registerWorkbenchCommandFromAction(descriptor, alias, category, when);
	}

	private registerWorkbenchCommandFromAction(descriptor: SyncActionDescriptor, alias: string, category?: string, when?: ContextKeyExpr): IDisposable {
		let registrations: IDisposable[] = [];

		// command
		registrations.push(CommandsRegistry.registerCommand(descriptor.id, this.createCommandHandler(descriptor)));

		// keybinding
		const weight = (typeof descriptor.keybindingWeight === 'undefined' ? KeybindingWeight.WorkbenchContrib : descriptor.keybindingWeight);
		const keybindings = descriptor.keybindings;
		KeybindingsRegistry.registerKeybindingRule({
			id: descriptor.id,
			weight: weight,
			when: descriptor.keybindingContext,
			primary: keybindings ? keybindings.primary : 0,
			secondary: keybindings && keybindings.secondary,
			win: keybindings && keybindings.win,
			mac: keybindings && keybindings.mac,
			linux: keybindings && keybindings.linux
		});

		// menu item
		// TODO@Rob slightly weird if-check required because of
		// https://github.com/Microsoft/vscode/blob/master/src/vs/workbench/parts/search/electron-browser/search.contribution.ts#L266
		if (descriptor.label) {

			let idx = alias.indexOf(': ');
			let categoryOriginal;
			if (idx > 0) {
				categoryOriginal = alias.substr(0, idx);
				alias = alias.substr(idx + 2);
			}

			const command = {
				id: descriptor.id,
				title: { value: descriptor.label, original: alias },
				category: category && { value: category, original: categoryOriginal }
			};

			MenuRegistry.addCommand(command);

			registrations.push(MenuRegistry.appendMenuItem(MenuId.CommandPalette, { command, when }));
		}

		// TODO@alex,joh
		// support removal of keybinding rule
		// support removal of command-ui
		return combinedDisposable(registrations);
	}

	private createCommandHandler(descriptor: SyncActionDescriptor): ICommandHandler {
		return (accessor, args) => {
			const notificationService = accessor.get(INotificationService);
			const instantiationService = accessor.get(IInstantiationService);
			const lifecycleService = accessor.get(ILifecycleService);

			Promise.resolve(this.triggerAndDisposeAction(instantiationService, lifecycleService, descriptor, args)).then(null, err => {
				notificationService.error(err);
			});
		};
	}

	private triggerAndDisposeAction(instantiationService: IInstantiationService, lifecycleService: ILifecycleService, descriptor: SyncActionDescriptor, args: any): Thenable<void> {

		// run action when workbench is created
		return lifecycleService.when(LifecyclePhase.Running).then(() => {
			const actionInstance = instantiationService.createInstance(descriptor.syncDescriptor);
			try {
				actionInstance.label = descriptor.label || actionInstance.label;

				// don't run the action when not enabled
				if (!actionInstance.enabled) {
					actionInstance.dispose();

					return void 0;
				}

				const from = args && args.from || 'keybinding';

				return Promise.resolve(actionInstance.run(undefined, { from })).then(() => {
					actionInstance.dispose();
				}, err => {
					actionInstance.dispose();

					return Promise.reject(err);
				});
			} catch (err) {
				actionInstance.dispose();

				return Promise.reject(err);
			}
		});
	}
});
