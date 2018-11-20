/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { Event, Emitter } from 'vs/base/common/event';
import { IInstantiationService } from 'vs/platform/instantiation/common/instantiation';
import { IExtensionHostProfile, ProfileSession, IExtensionService } from 'vs/workbench/services/extensions/common/extensions';
import { Disposable, IDisposable, dispose } from 'vs/base/common/lifecycle';
import { onUnexpectedError } from 'vs/base/common/errors';
import { append, $, addDisposableListener } from 'vs/base/browser/dom';
import { IStatusbarRegistry, StatusbarItemDescriptor, Extensions, IStatusbarItem } from 'vs/workbench/browser/parts/statusbar/statusbar';
import { StatusbarAlignment } from 'vs/platform/statusbar/common/statusbar';
import { Registry } from 'vs/platform/registry/common/platform';
import { IExtensionHostProfileService, ProfileSessionState } from 'vs/workbench/parts/extensions/electron-browser/runtimeExtensionsEditor';
import { IEditorService } from 'vs/workbench/services/editor/common/editorService';
import { IWindowsService } from 'vs/platform/windows/common/windows';
import { IDialogService } from 'vs/platform/dialogs/common/dialogs';
import { randomPort } from 'vs/base/node/ports';
import product from 'vs/platform/node/product';
import { RuntimeExtensionsInput } from 'vs/workbench/services/extensions/electron-browser/runtimeExtensionsInput';

export class ExtensionHostProfileService extends Disposable implements IExtensionHostProfileService {

	_serviceBrand: any;

	private readonly _onDidChangeState: Emitter<void> = this._register(new Emitter<void>());
	public readonly onDidChangeState: Event<void> = this._onDidChangeState.event;

	private readonly _onDidChangeLastProfile: Emitter<void> = this._register(new Emitter<void>());
	public readonly onDidChangeLastProfile: Event<void> = this._onDidChangeLastProfile.event;

	private _profile: IExtensionHostProfile;
	private _profileSession: ProfileSession;
	private _state: ProfileSessionState;

	public get state() { return this._state; }
	public get lastProfile() { return this._profile; }

	constructor(
		@IExtensionService private readonly _extensionService: IExtensionService,
		@IEditorService private readonly _editorService: IEditorService,
		@IInstantiationService private readonly _instantiationService: IInstantiationService,
		@IWindowsService private readonly _windowsService: IWindowsService,
		@IDialogService private readonly _dialogService: IDialogService
	) {
		super();
		this._profile = null;
		this._profileSession = null;
		this._setState(ProfileSessionState.None);
	}

	private _setState(state: ProfileSessionState): void {
		if (this._state === state) {
			return;
		}
		this._state = state;

		if (this._state === ProfileSessionState.Running) {
			ProfileExtHostStatusbarItem.instance.show(() => {
				this.stopProfiling();
				this._editorService.openEditor(this._instantiationService.createInstance(RuntimeExtensionsInput), { revealIfOpened: true });
			});
		} else if (this._state === ProfileSessionState.Stopping) {
			ProfileExtHostStatusbarItem.instance.hide();
		}

		this._onDidChangeState.fire(void 0);
	}

	public startProfiling(): Thenable<any> {
		if (this._state !== ProfileSessionState.None) {
			return null;
		}

		if (!this._extensionService.canProfileExtensionHost()) {
			return this._dialogService.confirm({
				type: 'info',
				message: nls.localize('restart1', "Profile Extensions"),
				detail: nls.localize('restart2', "In order to profile extensions a restart is required. Do you want to restart '{0}' now?", product.nameLong),
				primaryButton: nls.localize('restart3', "Restart"),
				secondaryButton: nls.localize('cancel', "Cancel")
			}).then(res => {
				if (res.confirmed) {
					this._windowsService.relaunch({ addArgs: [`--inspect-extensions=${randomPort()}`] });
				}
			});
		}

		this._setState(ProfileSessionState.Starting);

		return this._extensionService.startExtensionHostProfile().then((value) => {
			this._profileSession = value;
			this._setState(ProfileSessionState.Running);
		}, (err) => {
			onUnexpectedError(err);
			this._setState(ProfileSessionState.None);
		});
	}

	public stopProfiling(): void {
		if (this._state !== ProfileSessionState.Running) {
			return;
		}

		this._setState(ProfileSessionState.Stopping);
		this._profileSession.stop().then((result) => {
			this._setLastProfile(result);
			this._setState(ProfileSessionState.None);
		}, (err) => {
			onUnexpectedError(err);
			this._setState(ProfileSessionState.None);
		});
		this._profileSession = null;
	}

	private _setLastProfile(profile: IExtensionHostProfile) {
		this._profile = profile;
		this._onDidChangeLastProfile.fire(void 0);
	}

	public getLastProfile(): IExtensionHostProfile {
		return this._profile;
	}

	public clearLastProfile(): void {
		this._setLastProfile(null);
	}
}

export class ProfileExtHostStatusbarItem implements IStatusbarItem {

	public static instance: ProfileExtHostStatusbarItem;

	private toDispose: IDisposable[];
	private statusBarItem: HTMLElement;
	private label: HTMLElement;
	private timeStarted: number;
	private labelUpdater: any;
	private clickHandler: () => void;

	constructor() {
		ProfileExtHostStatusbarItem.instance = this;
		this.toDispose = [];
		this.timeStarted = 0;
	}

	public show(clickHandler: () => void) {
		this.clickHandler = clickHandler;
		if (this.timeStarted === 0) {
			this.timeStarted = new Date().getTime();
			this.statusBarItem.hidden = false;
			this.labelUpdater = setInterval(() => {
				this.updateLabel();
			}, 1000);
			this.updateLabel();
		}
	}

	public hide() {
		this.clickHandler = null;
		this.statusBarItem.hidden = true;
		this.timeStarted = 0;
		clearInterval(this.labelUpdater);
		this.labelUpdater = null;
	}

	public render(container: HTMLElement): IDisposable {
		if (!this.statusBarItem && container) {
			this.statusBarItem = append(container, $('.profileExtHost-statusbar-item'));
			this.toDispose.push(addDisposableListener(this.statusBarItem, 'click', () => {
				if (this.clickHandler) {
					this.clickHandler();
				}
			}));
			this.statusBarItem.title = nls.localize('selectAndStartDebug', "Click to stop profiling.");
			const a = append(this.statusBarItem, $('a'));
			append(a, $('.icon'));
			this.label = append(a, $('span.label'));
			this.updateLabel();
			this.statusBarItem.hidden = true;
		}
		return this;
	}

	private updateLabel() {
		let label = 'Profiling Extension Host';
		if (this.timeStarted > 0) {
			let secondsRecoreded = (new Date().getTime() - this.timeStarted) / 1000;
			label = `Profiling Extension Host (${Math.round(secondsRecoreded)} sec)`;
		}
		this.label.textContent = label;
	}

	public dispose(): void {
		this.toDispose = dispose(this.toDispose);
	}
}

Registry.as<IStatusbarRegistry>(Extensions.Statusbar).registerStatusbarItem(
	new StatusbarItemDescriptor(ProfileExtHostStatusbarItem, StatusbarAlignment.RIGHT)
);
