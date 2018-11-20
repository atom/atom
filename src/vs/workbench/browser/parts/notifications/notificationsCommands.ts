/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { CommandsRegistry } from 'vs/platform/commands/common/commands';
import { RawContextKey, ContextKeyExpr } from 'vs/platform/contextkey/common/contextkey';
import { KeybindingsRegistry, KeybindingWeight } from 'vs/platform/keybinding/common/keybindingsRegistry';
import { KeyCode, KeyMod } from 'vs/base/common/keyCodes';
import { INotificationViewItem, isNotificationViewItem } from 'vs/workbench/common/notifications';
import { MenuRegistry, MenuId } from 'vs/platform/actions/common/actions';
import { localize } from 'vs/nls';
import { IListService, WorkbenchList } from 'vs/platform/list/browser/listService';

// Center
export const SHOW_NOTIFICATIONS_CENTER = 'notifications.showList';
export const HIDE_NOTIFICATIONS_CENTER = 'notifications.hideList';
export const TOGGLE_NOTIFICATIONS_CENTER = 'notifications.toggleList';

// Toasts
export const HIDE_NOTIFICATION_TOAST = 'notifications.hideToasts';
export const FOCUS_NOTIFICATION_TOAST = 'notifications.focusToasts';
export const FOCUS_NEXT_NOTIFICATION_TOAST = 'notifications.focusNextToast';
export const FOCUS_PREVIOUS_NOTIFICATION_TOAST = 'notifications.focusPreviousToast';
export const FOCUS_FIRST_NOTIFICATION_TOAST = 'notifications.focusFirstToast';
export const FOCUS_LAST_NOTIFICATION_TOAST = 'notifications.focusLastToast';

// Notification
export const COLLAPSE_NOTIFICATION = 'notification.collapse';
export const EXPAND_NOTIFICATION = 'notification.expand';
export const TOGGLE_NOTIFICATION = 'notification.toggle';
export const CLEAR_NOTIFICATION = 'notification.clear';
export const CLEAR_ALL_NOTIFICATIONS = 'notifications.clearAll';

const notificationFocusedId = 'notificationFocus';
export const NotificationFocusedContext = new RawContextKey<boolean>(notificationFocusedId, true);

const notificationsCenterVisibleId = 'notificationCenterVisible';
export const NotificationsCenterVisibleContext = new RawContextKey<boolean>(notificationsCenterVisibleId, false);

const notificationsToastsVisibleId = 'notificationToastsVisible';
export const NotificationsToastsVisibleContext = new RawContextKey<boolean>(notificationsToastsVisibleId, false);

export interface INotificationsCenterController {
	readonly isVisible: boolean;

	show(): void;
	hide(): void;

	clearAll(): void;
}

export interface INotificationsToastController {
	focus(): void;
	focusNext(): void;
	focusPrevious(): void;
	focusFirst(): void;
	focusLast(): void;

	hide(): void;
}

export function registerNotificationCommands(center: INotificationsCenterController, toasts: INotificationsToastController): void {

	function getNotificationFromContext(listService: IListService, context?: any): INotificationViewItem {
		if (isNotificationViewItem(context)) {
			return context;
		}

		const list = listService.lastFocusedList;
		if (list instanceof WorkbenchList) {
			const focusedElement = list.getFocusedElements()[0];
			if (isNotificationViewItem(focusedElement)) {
				return focusedElement;
			}
		}

		return void 0;
	}

	// Show Notifications Cneter
	CommandsRegistry.registerCommand(SHOW_NOTIFICATIONS_CENTER, () => {
		center.show();
	});

	// Hide Notifications Center
	KeybindingsRegistry.registerCommandAndKeybindingRule({
		id: HIDE_NOTIFICATIONS_CENTER,
		weight: KeybindingWeight.WorkbenchContrib + 50,
		when: NotificationsCenterVisibleContext,
		primary: KeyCode.Escape,
		handler: accessor => center.hide()
	});

	// Toggle Notifications Center
	CommandsRegistry.registerCommand(TOGGLE_NOTIFICATIONS_CENTER, accessor => {
		if (center.isVisible) {
			center.hide();
		} else {
			center.show();
		}
	});

	// Clear Notification
	KeybindingsRegistry.registerCommandAndKeybindingRule({
		id: CLEAR_NOTIFICATION,
		weight: KeybindingWeight.WorkbenchContrib,
		when: NotificationFocusedContext,
		primary: KeyCode.Delete,
		mac: {
			primary: KeyMod.CtrlCmd | KeyCode.Backspace
		},
		handler: (accessor, args?: any) => {
			const notification = getNotificationFromContext(accessor.get(IListService), args);
			if (notification) {
				notification.close();
			}
		}
	});

	// Expand Notification
	KeybindingsRegistry.registerCommandAndKeybindingRule({
		id: EXPAND_NOTIFICATION,
		weight: KeybindingWeight.WorkbenchContrib,
		when: NotificationFocusedContext,
		primary: KeyCode.RightArrow,
		handler: (accessor, args?: any) => {
			const notification = getNotificationFromContext(accessor.get(IListService), args);
			if (notification) {
				notification.expand();
			}
		}
	});

	// Collapse Notification
	KeybindingsRegistry.registerCommandAndKeybindingRule({
		id: COLLAPSE_NOTIFICATION,
		weight: KeybindingWeight.WorkbenchContrib,
		when: NotificationFocusedContext,
		primary: KeyCode.LeftArrow,
		handler: (accessor, args?: any) => {
			const notification = getNotificationFromContext(accessor.get(IListService), args);
			if (notification) {
				notification.collapse();
			}
		}
	});

	// Toggle Notification
	KeybindingsRegistry.registerCommandAndKeybindingRule({
		id: TOGGLE_NOTIFICATION,
		weight: KeybindingWeight.WorkbenchContrib,
		when: NotificationFocusedContext,
		primary: KeyCode.Space,
		secondary: [KeyCode.Enter],
		handler: accessor => {
			const notification = getNotificationFromContext(accessor.get(IListService));
			if (notification) {
				notification.toggle();
			}
		}
	});

	// Hide Toasts
	KeybindingsRegistry.registerCommandAndKeybindingRule({
		id: HIDE_NOTIFICATION_TOAST,
		weight: KeybindingWeight.WorkbenchContrib + 50,
		when: NotificationsToastsVisibleContext,
		primary: KeyCode.Escape,
		handler: accessor => toasts.hide()
	});

	// Focus Toasts
	CommandsRegistry.registerCommand(FOCUS_NOTIFICATION_TOAST, () => toasts.focus());

	// Focus Next Toast
	KeybindingsRegistry.registerCommandAndKeybindingRule({
		id: FOCUS_NEXT_NOTIFICATION_TOAST,
		weight: KeybindingWeight.WorkbenchContrib,
		when: ContextKeyExpr.and(NotificationFocusedContext, NotificationsToastsVisibleContext),
		primary: KeyCode.DownArrow,
		handler: (accessor) => {
			toasts.focusNext();
		}
	});

	// Focus Previous Toast
	KeybindingsRegistry.registerCommandAndKeybindingRule({
		id: FOCUS_PREVIOUS_NOTIFICATION_TOAST,
		weight: KeybindingWeight.WorkbenchContrib,
		when: ContextKeyExpr.and(NotificationFocusedContext, NotificationsToastsVisibleContext),
		primary: KeyCode.UpArrow,
		handler: (accessor) => {
			toasts.focusPrevious();
		}
	});

	// Focus First Toast
	KeybindingsRegistry.registerCommandAndKeybindingRule({
		id: FOCUS_FIRST_NOTIFICATION_TOAST,
		weight: KeybindingWeight.WorkbenchContrib,
		when: ContextKeyExpr.and(NotificationFocusedContext, NotificationsToastsVisibleContext),
		primary: KeyCode.PageUp,
		secondary: [KeyCode.Home],
		handler: (accessor) => {
			toasts.focusFirst();
		}
	});

	// Focus Last Toast
	KeybindingsRegistry.registerCommandAndKeybindingRule({
		id: FOCUS_LAST_NOTIFICATION_TOAST,
		weight: KeybindingWeight.WorkbenchContrib,
		when: ContextKeyExpr.and(NotificationFocusedContext, NotificationsToastsVisibleContext),
		primary: KeyCode.PageDown,
		secondary: [KeyCode.End],
		handler: (accessor) => {
			toasts.focusLast();
		}
	});

	/// Clear All Notifications
	CommandsRegistry.registerCommand(CLEAR_ALL_NOTIFICATIONS, () => center.clearAll());

	// Commands for Command Palette
	const category = localize('notifications', "Notifications");
	MenuRegistry.appendMenuItem(MenuId.CommandPalette, { command: { id: SHOW_NOTIFICATIONS_CENTER, title: { value: localize('showNotifications', "Show Notifications"), original: 'Notifications: Show Notifications' }, category }, when: NotificationsCenterVisibleContext.toNegated() });
	MenuRegistry.appendMenuItem(MenuId.CommandPalette, { command: { id: HIDE_NOTIFICATIONS_CENTER, title: { value: localize('hideNotifications', "Hide Notifications"), original: 'Notifications: Hide Notifications' }, category }, when: NotificationsCenterVisibleContext });
	MenuRegistry.appendMenuItem(MenuId.CommandPalette, { command: { id: CLEAR_ALL_NOTIFICATIONS, title: { value: localize('clearAllNotifications', "Clear All Notifications"), original: 'Notifications: Clear All Notifications' }, category } });
}