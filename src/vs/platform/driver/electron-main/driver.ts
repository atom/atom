/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IDriver, DriverChannel, IElement, WindowDriverChannelClient, IWindowDriverRegistry, WindowDriverRegistryChannel, IWindowDriver, IDriverOptions } from 'vs/platform/driver/node/driver';
import { IWindowsMainService } from 'vs/platform/windows/electron-main/windows';
import { serve as serveNet } from 'vs/base/parts/ipc/node/ipc.net';
import { combinedDisposable, IDisposable } from 'vs/base/common/lifecycle';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { IPCServer, StaticRouter } from 'vs/base/parts/ipc/node/ipc';
import { SimpleKeybinding, KeyCode } from 'vs/base/common/keyCodes';
import { USLayoutResolvedKeybinding } from 'vs/platform/keybinding/common/usLayoutResolvedKeybinding';
import { OS } from 'vs/base/common/platform';
import { Emitter, toPromise } from 'vs/base/common/event';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { ScanCodeBinding } from 'vs/base/common/scanCode';
import { KeybindingParser } from 'vs/base/common/keybindingParser';
import { timeout } from 'vs/base/common/async';

function isSilentKeyCode(keyCode: KeyCode) {
	return keyCode < KeyCode.KEY_0;
}

export class Driver implements IDriver, IWindowDriverRegistry {

	_serviceBrand: any;

	private registeredWindowIds = new Set<number>();
	private reloadingWindowIds = new Set<number>();
	private onDidReloadingChange = new Emitter<void>();

	constructor(
		private windowServer: IPCServer,
		private options: IDriverOptions,
		@IWindowsMainService private windowsService: IWindowsMainService
	) { }

	async registerWindowDriver(windowId: number): Promise<IDriverOptions> {
		this.registeredWindowIds.add(windowId);
		this.reloadingWindowIds.delete(windowId);
		this.onDidReloadingChange.fire();
		return this.options;
	}

	async reloadWindowDriver(windowId: number): Promise<void> {
		this.reloadingWindowIds.add(windowId);
	}

	async getWindowIds(): Promise<number[]> {
		return this.windowsService.getWindows()
			.map(w => w.id)
			.filter(id => this.registeredWindowIds.has(id) && !this.reloadingWindowIds.has(id));
	}

	async capturePage(windowId: number): Promise<string> {
		await this.whenUnfrozen(windowId);

		const window = this.windowsService.getWindowById(windowId);
		const webContents = window.win.webContents;
		const image = await new Promise<Electron.NativeImage>(c => webContents.capturePage(c));

		return image.toPNG().toString('base64');
	}

	async reloadWindow(windowId: number): Promise<void> {
		await this.whenUnfrozen(windowId);

		const window = this.windowsService.getWindowById(windowId);
		this.reloadingWindowIds.add(windowId);
		this.windowsService.reload(window);
	}

	async dispatchKeybinding(windowId: number, keybinding: string): Promise<void> {
		await this.whenUnfrozen(windowId);

		const [first, second] = KeybindingParser.parseUserBinding(keybinding);

		if (!first) {
			return;
		}

		await this._dispatchKeybinding(windowId, first);

		if (second) {
			await this._dispatchKeybinding(windowId, second);
		}
	}

	private async _dispatchKeybinding(windowId: number, keybinding: SimpleKeybinding | ScanCodeBinding): Promise<void> {
		if (keybinding instanceof ScanCodeBinding) {
			throw new Error('ScanCodeBindings not supported');
		}

		const window = this.windowsService.getWindowById(windowId);
		const webContents = window.win.webContents;
		const noModifiedKeybinding = new SimpleKeybinding(false, false, false, false, keybinding.keyCode);
		const resolvedKeybinding = new USLayoutResolvedKeybinding(noModifiedKeybinding, OS);
		const keyCode = resolvedKeybinding.getElectronAccelerator();

		const modifiers: string[] = [];

		if (keybinding.ctrlKey) {
			modifiers.push('ctrl');
		}

		if (keybinding.metaKey) {
			modifiers.push('meta');
		}

		if (keybinding.shiftKey) {
			modifiers.push('shift');
		}

		if (keybinding.altKey) {
			modifiers.push('alt');
		}

		webContents.sendInputEvent({ type: 'keyDown', keyCode, modifiers } as any);

		if (!isSilentKeyCode(keybinding.keyCode)) {
			webContents.sendInputEvent({ type: 'char', keyCode, modifiers } as any);
		}

		webContents.sendInputEvent({ type: 'keyUp', keyCode, modifiers } as any);

		await timeout(100);
	}

	async click(windowId: number, selector: string, xoffset?: number, yoffset?: number): Promise<void> {
		const windowDriver = await this.getWindowDriver(windowId);
		await windowDriver.click(selector, xoffset, yoffset);
	}

	async doubleClick(windowId: number, selector: string): Promise<void> {
		const windowDriver = await this.getWindowDriver(windowId);
		await windowDriver.doubleClick(selector);
	}

	async setValue(windowId: number, selector: string, text: string): Promise<void> {
		const windowDriver = await this.getWindowDriver(windowId);
		await windowDriver.setValue(selector, text);
	}

	async getTitle(windowId: number): Promise<string> {
		const windowDriver = await this.getWindowDriver(windowId);
		return await windowDriver.getTitle();
	}

	async isActiveElement(windowId: number, selector: string): Promise<boolean> {
		const windowDriver = await this.getWindowDriver(windowId);
		return await windowDriver.isActiveElement(selector);
	}

	async getElements(windowId: number, selector: string, recursive: boolean): Promise<IElement[]> {
		const windowDriver = await this.getWindowDriver(windowId);
		return await windowDriver.getElements(selector, recursive);
	}

	async typeInEditor(windowId: number, selector: string, text: string): Promise<void> {
		const windowDriver = await this.getWindowDriver(windowId);
		await windowDriver.typeInEditor(selector, text);
	}

	async getTerminalBuffer(windowId: number, selector: string): Promise<string[]> {
		const windowDriver = await this.getWindowDriver(windowId);
		return await windowDriver.getTerminalBuffer(selector);
	}

	async writeInTerminal(windowId: number, selector: string, text: string): Promise<void> {
		const windowDriver = await this.getWindowDriver(windowId);
		await windowDriver.writeInTerminal(selector, text);
	}

	private async getWindowDriver(windowId: number): Promise<IWindowDriver> {
		await this.whenUnfrozen(windowId);

		const id = `window:${windowId}`;
		const router = new StaticRouter(ctx => ctx === id);
		const windowDriverChannel = this.windowServer.getChannel('windowDriver', router);
		return new WindowDriverChannelClient(windowDriverChannel);
	}

	private async whenUnfrozen(windowId: number): Promise<void> {
		while (this.reloadingWindowIds.has(windowId)) {
			await toPromise(this.onDidReloadingChange.event);
		}
	}
}

export async function serve(
	windowServer: IPCServer,
	handle: string,
	environmentService: IEnvironmentService,
	instantiationService: IInstantiationService
): Promise<IDisposable> {
	const verbose = environmentService.driverVerbose;
	const driver = instantiationService.createInstance(Driver, windowServer, { verbose });

	const windowDriverRegistryChannel = new WindowDriverRegistryChannel(driver);
	windowServer.registerChannel('windowDriverRegistry', windowDriverRegistryChannel);

	const server = await serveNet(handle);
	const channel = new DriverChannel(driver);
	server.registerChannel('driver', channel);

	return combinedDisposable([server, windowServer]);
}
