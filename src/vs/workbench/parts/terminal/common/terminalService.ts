/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Event, Emitter } from 'vs/base/common/event';
import { IContextKeyService, IContextKey } from 'vs/platform/contextkey/common/contextkey';
import { ILifecycleService } from 'vs/platform/lifecycle/common/lifecycle';
import { IPanelService } from 'vs/workbench/services/panel/common/panelService';
import { IPartService } from 'vs/workbench/services/part/common/partService';
import { ITerminalService, ITerminalInstance, IShellLaunchConfig, ITerminalConfigHelper, KEYBINDING_CONTEXT_TERMINAL_FOCUS, KEYBINDING_CONTEXT_TERMINAL_FIND_WIDGET_VISIBLE, TERMINAL_PANEL_ID, ITerminalTab, ITerminalProcessExtHostProxy, ITerminalProcessExtHostRequest, KEYBINDING_CONTEXT_TERMINAL_IS_OPEN } from 'vs/workbench/parts/terminal/common/terminal';
import { IStorageService } from 'vs/platform/storage/common/storage';
import { FindReplaceState } from 'vs/editor/contrib/find/findState';

export abstract class TerminalService implements ITerminalService {
	public _serviceBrand: any;

	protected _isShuttingDown: boolean;
	protected _terminalFocusContextKey: IContextKey<boolean>;
	protected _findWidgetVisible: IContextKey<boolean>;
	protected _terminalContainer: HTMLElement;
	protected _terminalTabs: ITerminalTab[];
	protected abstract _terminalInstances: ITerminalInstance[];
	private _findState: FindReplaceState;

	private _activeTabIndex: number;

	public get activeTabIndex(): number { return this._activeTabIndex; }
	public get terminalInstances(): ITerminalInstance[] { return this._terminalInstances; }
	public get terminalTabs(): ITerminalTab[] { return this._terminalTabs; }

	private readonly _onActiveTabChanged: Emitter<void> = new Emitter<void>();
	public get onActiveTabChanged(): Event<void> { return this._onActiveTabChanged.event; }
	protected readonly _onInstanceCreated: Emitter<ITerminalInstance> = new Emitter<ITerminalInstance>();
	public get onInstanceCreated(): Event<ITerminalInstance> { return this._onInstanceCreated.event; }
	protected readonly _onInstanceDisposed: Emitter<ITerminalInstance> = new Emitter<ITerminalInstance>();
	public get onInstanceDisposed(): Event<ITerminalInstance> { return this._onInstanceDisposed.event; }
	protected readonly _onInstanceProcessIdReady: Emitter<ITerminalInstance> = new Emitter<ITerminalInstance>();
	public get onInstanceProcessIdReady(): Event<ITerminalInstance> { return this._onInstanceProcessIdReady.event; }
	protected readonly _onInstanceRequestExtHostProcess: Emitter<ITerminalProcessExtHostRequest> = new Emitter<ITerminalProcessExtHostRequest>();
	public get onInstanceRequestExtHostProcess(): Event<ITerminalProcessExtHostRequest> { return this._onInstanceRequestExtHostProcess.event; }
	protected readonly _onInstanceDimensionsChanged: Emitter<ITerminalInstance> = new Emitter<ITerminalInstance>();
	public get onInstanceDimensionsChanged(): Event<ITerminalInstance> { return this._onInstanceDimensionsChanged.event; }
	protected readonly _onInstancesChanged: Emitter<void> = new Emitter<void>();
	public get onInstancesChanged(): Event<void> { return this._onInstancesChanged.event; }
	protected readonly _onInstanceTitleChanged: Emitter<ITerminalInstance> = new Emitter<ITerminalInstance>();
	public get onInstanceTitleChanged(): Event<ITerminalInstance> { return this._onInstanceTitleChanged.event; }
	protected readonly _onActiveInstanceChanged: Emitter<ITerminalInstance> = new Emitter<ITerminalInstance>();
	public get onActiveInstanceChanged(): Event<ITerminalInstance> { return this._onActiveInstanceChanged.event; }
	protected readonly _onTabDisposed: Emitter<ITerminalTab> = new Emitter<ITerminalTab>();
	public get onTabDisposed(): Event<ITerminalTab> { return this._onTabDisposed.event; }

	public abstract get configHelper(): ITerminalConfigHelper;

	constructor(
		@IContextKeyService private readonly _contextKeyService: IContextKeyService,
		@IPanelService protected readonly _panelService: IPanelService,
		@IPartService private readonly _partService: IPartService,
		@ILifecycleService lifecycleService: ILifecycleService,
		@IStorageService protected readonly _storageService: IStorageService
	) {
		this._activeTabIndex = 0;
		this._isShuttingDown = false;
		this._findState = new FindReplaceState();
		lifecycleService.onWillShutdown(event => event.veto(this._onWillShutdown()));
		lifecycleService.onShutdown(() => this._onShutdown());
		this._terminalFocusContextKey = KEYBINDING_CONTEXT_TERMINAL_FOCUS.bindTo(this._contextKeyService);
		this._findWidgetVisible = KEYBINDING_CONTEXT_TERMINAL_FIND_WIDGET_VISIBLE.bindTo(this._contextKeyService);
		this.onTabDisposed(tab => this._removeTab(tab));

		this._handleContextKeys();
	}

	private _handleContextKeys(): void {
		const terminalIsOpenContext = KEYBINDING_CONTEXT_TERMINAL_IS_OPEN.bindTo(this._contextKeyService);

		const updateTerminalContextKeys = () => {
			terminalIsOpenContext.set(this.terminalInstances.length > 0);
		};

		this.onInstancesChanged(() => updateTerminalContextKeys());
	}

	protected abstract _showTerminalCloseConfirmation(): PromiseLike<boolean>;
	protected abstract _showNotEnoughSpaceToast(): void;
	public abstract createTerminal(shell?: IShellLaunchConfig, wasNewTerminalAction?: boolean): ITerminalInstance;
	public abstract createTerminalRenderer(name: string): ITerminalInstance;
	public abstract createInstance(terminalFocusContextKey: IContextKey<boolean>, configHelper: ITerminalConfigHelper, container: HTMLElement, shellLaunchConfig: IShellLaunchConfig, doCreateProcess: boolean): ITerminalInstance;
	public abstract getActiveOrCreateInstance(wasNewTerminalAction?: boolean): ITerminalInstance;
	public abstract selectDefaultWindowsShell(): Promise<string>;
	public abstract setContainers(panelContainer: HTMLElement, terminalContainer: HTMLElement): void;
	public abstract requestExtHostProcess(proxy: ITerminalProcessExtHostProxy, shellLaunchConfig: IShellLaunchConfig, cols: number, rows: number): void;

	private _onWillShutdown(): boolean | PromiseLike<boolean> {
		if (this.terminalInstances.length === 0) {
			// No terminal instances, don't veto
			return false;
		}

		if (this.configHelper.config.confirmOnExit) {
			// veto if configured to show confirmation and the user choosed not to exit
			return this._showTerminalCloseConfirmation().then(veto => {
				if (!veto) {
					this._isShuttingDown = true;
				}
				return veto;
			});
		}

		this._isShuttingDown = true;

		return false;
	}

	private _onShutdown(): void {
		// Dispose of all instances
		this.terminalInstances.forEach(instance => instance.dispose(true));
	}

	public getTabLabels(): string[] {
		return this._terminalTabs.filter(tab => tab.terminalInstances.length > 0).map((tab, index) => `${index + 1}: ${tab.title ? tab.title : ''}`);
	}

	public getFindState(): FindReplaceState {
		return this._findState;
	}

	private _removeTab(tab: ITerminalTab): void {
		// Get the index of the tab and remove it from the list
		const index = this._terminalTabs.indexOf(tab);
		const wasActiveTab = tab === this.getActiveTab();
		if (index !== -1) {
			this._terminalTabs.splice(index, 1);
		}

		// Adjust focus if the tab was active
		if (wasActiveTab && this._terminalTabs.length > 0) {
			// TODO: Only focus the new tab if the removed tab had focus?
			// const hasFocusOnExit = tab.activeInstance.hadFocusOnExit;
			const newIndex = index < this._terminalTabs.length ? index : this._terminalTabs.length - 1;
			this.setActiveTabByIndex(newIndex);
			const activeInstance = this.getActiveInstance();
			if (activeInstance) {
				activeInstance.focus(true);
			}
		}

		// Hide the panel if there are no more instances, provided that VS Code is not shutting
		// down. When shutting down the panel is locked in place so that it is restored upon next
		// launch.
		if (this._terminalTabs.length === 0 && !this._isShuttingDown) {
			this.hidePanel();
			this._onActiveInstanceChanged.fire(undefined);
		}

		// Fire events
		this._onInstancesChanged.fire();
		if (wasActiveTab) {
			this._onActiveTabChanged.fire();
		}
	}

	public getActiveTab(): ITerminalTab | null {
		if (this._activeTabIndex < 0 || this._activeTabIndex >= this._terminalTabs.length) {
			return null;
		}
		return this._terminalTabs[this._activeTabIndex];
	}

	public getActiveInstance(): ITerminalInstance | null {
		const tab = this.getActiveTab();
		if (!tab) {
			return null;
		}
		return tab.activeInstance;
	}

	public getInstanceFromId(terminalId: number): ITerminalInstance {
		return this.terminalInstances[this._getIndexFromId(terminalId)];
	}

	public getInstanceFromIndex(terminalIndex: number): ITerminalInstance {
		return this.terminalInstances[terminalIndex];
	}

	public setActiveInstance(terminalInstance: ITerminalInstance): void {
		this.setActiveInstanceByIndex(this._getIndexFromId(terminalInstance.id));
	}

	public setActiveTabByIndex(tabIndex: number): void {
		if (tabIndex >= this._terminalTabs.length) {
			return;
		}

		const didTabChange = this._activeTabIndex !== tabIndex;
		this._activeTabIndex = tabIndex;

		this._terminalTabs.forEach((t, i) => t.setVisible(i === this._activeTabIndex));
		if (didTabChange) {
			this._onActiveTabChanged.fire();
		}
	}

	private _getInstanceFromGlobalInstanceIndex(index: number): { tab: ITerminalTab, tabIndex: number, instance: ITerminalInstance, localInstanceIndex: number } | null {
		let currentTabIndex = 0;
		while (index >= 0 && currentTabIndex < this._terminalTabs.length) {
			const tab = this._terminalTabs[currentTabIndex];
			const count = tab.terminalInstances.length;
			if (index < count) {
				return {
					tab,
					tabIndex: currentTabIndex,
					instance: tab.terminalInstances[index],
					localInstanceIndex: index
				};
			}
			index -= count;
			currentTabIndex++;
		}
		return null;
	}

	public setActiveInstanceByIndex(terminalIndex: number): void {
		const query = this._getInstanceFromGlobalInstanceIndex(terminalIndex);
		if (!query) {
			return;
		}

		query.tab.setActiveInstanceByIndex(query.localInstanceIndex);
		const didTabChange = this._activeTabIndex !== query.tabIndex;
		this._activeTabIndex = query.tabIndex;
		this._terminalTabs.forEach((t, i) => t.setVisible(i === query.tabIndex));

		// Only fire the event if there was a change
		if (didTabChange) {
			this._onActiveTabChanged.fire();
		}
	}

	public setActiveTabToNext(): void {
		if (this._terminalTabs.length <= 1) {
			return;
		}
		let newIndex = this._activeTabIndex + 1;
		if (newIndex >= this._terminalTabs.length) {
			newIndex = 0;
		}
		this.setActiveTabByIndex(newIndex);
	}

	public setActiveTabToPrevious(): void {
		if (this._terminalTabs.length <= 1) {
			return;
		}
		let newIndex = this._activeTabIndex - 1;
		if (newIndex < 0) {
			newIndex = this._terminalTabs.length - 1;
		}
		this.setActiveTabByIndex(newIndex);
	}

	public splitInstance(instanceToSplit: ITerminalInstance, shellLaunchConfig: IShellLaunchConfig = {}): void {
		const tab = this._getTabForInstance(instanceToSplit);
		if (!tab) {
			return;
		}

		const instance = tab.split(this._terminalFocusContextKey, this.configHelper, shellLaunchConfig);
		if (instance) {
			this._initInstanceListeners(instance);
			this._onInstancesChanged.fire();

			this._terminalTabs.forEach((t, i) => t.setVisible(i === this._activeTabIndex));
		} else {
			this._showNotEnoughSpaceToast();
		}
	}

	protected _initInstanceListeners(instance: ITerminalInstance): void {
		instance.addDisposable(instance.onDisposed(this._onInstanceDisposed.fire, this._onInstanceDisposed));
		instance.addDisposable(instance.onTitleChanged(this._onInstanceTitleChanged.fire, this._onInstanceTitleChanged));
		instance.addDisposable(instance.onProcessIdReady(this._onInstanceProcessIdReady.fire, this._onInstanceProcessIdReady));
		instance.addDisposable(instance.onDimensionsChanged(() => this._onInstanceDimensionsChanged.fire(instance)));
		instance.addDisposable(instance.onFocus(this._onActiveInstanceChanged.fire, this._onActiveInstanceChanged));
	}

	private _getTabForInstance(instance: ITerminalInstance): ITerminalTab | null {
		for (let i = 0; i < this._terminalTabs.length; i++) {
			const tab = this._terminalTabs[i];
			if (tab.terminalInstances.indexOf(instance) !== -1) {
				return tab;
			}
		}
		return null;
	}

	public showPanel(focus?: boolean): Promise<void> {
		return new Promise<void>((complete) => {
			const panel = this._panelService.getActivePanel();
			if (!panel || panel.getId() !== TERMINAL_PANEL_ID) {
				this._panelService.openPanel(TERMINAL_PANEL_ID, focus);
				if (focus) {
					// Do the focus call asynchronously as going through the
					// command palette will force editor focus
					setTimeout(() => {
						const instance = this.getActiveInstance();
						if (instance) {
							instance.focusWhenReady(true).then(() => complete(void 0));
						} else {
							complete(void 0);
						}
					}, 0);
				} else {
					complete(void 0);
				}
			} else {
				if (focus) {
					// Do the focus call asynchronously as going through the
					// command palette will force editor focus
					setTimeout(() => {
						const instance = this.getActiveInstance();
						if (instance) {
							instance.focusWhenReady(true).then(() => complete(void 0));
						} else {
							complete(void 0);
						}
					}, 0);
				} else {
					complete(void 0);
				}
			}
			return undefined;
		});
	}

	public hidePanel(): void {
		const panel = this._panelService.getActivePanel();
		if (panel && panel.getId() === TERMINAL_PANEL_ID) {
			this._partService.setPanelHidden(true);
		}
	}

	public abstract focusFindWidget(): Promise<void>;
	public abstract hideFindWidget(): void;

	public abstract findNext(): void;
	public abstract findPrevious(): void;

	private _getIndexFromId(terminalId: number): number {
		let terminalIndex = -1;
		this.terminalInstances.forEach((terminalInstance, i) => {
			if (terminalInstance.id === terminalId) {
				terminalIndex = i;
			}
		});
		if (terminalIndex === -1) {
			throw new Error(`Terminal with ID ${terminalId} does not exist (has it already been disposed?)`);
		}
		return terminalIndex;
	}

	public setWorkspaceShellAllowed(isAllowed: boolean): void {
		this.configHelper.setWorkspaceShellAllowed(isAllowed);
	}
}
