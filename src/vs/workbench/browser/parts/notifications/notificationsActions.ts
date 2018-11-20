/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/css!./media/notificationsActions';
import { INotificationViewItem } from 'vs/workbench/common/notifications';
import { localize } from 'vs/nls';
import { Action, IAction, ActionRunner } from 'vs/base/common/actions';
import { ITelemetryService } from 'vs/platform/telemetry/common/telemetry';
import { INotificationService } from 'vs/platform/notification/common/notification';
import { CLEAR_NOTIFICATION, EXPAND_NOTIFICATION, COLLAPSE_NOTIFICATION, CLEAR_ALL_NOTIFICATIONS, HIDE_NOTIFICATIONS_CENTER } from 'vs/workbench/browser/parts/notifications/notificationsCommands';
import { ICommandService } from 'vs/platform/commands/common/commands';
import { IClipboardService } from 'vs/platform/clipboard/common/clipboardService';

export class ClearNotificationAction extends Action {

	static readonly ID = CLEAR_NOTIFICATION;
	static readonly LABEL = localize('clearNotification', "Clear Notification");

	constructor(
		id: string,
		label: string,
		@ICommandService private commandService: ICommandService
	) {
		super(id, label, 'clear-notification-action');
	}

	run(notification: INotificationViewItem): Promise<any> {
		this.commandService.executeCommand(CLEAR_NOTIFICATION, notification);

		return Promise.resolve(void 0);
	}
}

export class ClearAllNotificationsAction extends Action {

	static readonly ID = CLEAR_ALL_NOTIFICATIONS;
	static readonly LABEL = localize('clearNotifications', "Clear All Notifications");

	constructor(
		id: string,
		label: string,
		@ICommandService private commandService: ICommandService
	) {
		super(id, label, 'clear-all-notifications-action');
	}

	run(notification: INotificationViewItem): Promise<any> {
		this.commandService.executeCommand(CLEAR_ALL_NOTIFICATIONS);

		return Promise.resolve(void 0);
	}
}

export class HideNotificationsCenterAction extends Action {

	static readonly ID = HIDE_NOTIFICATIONS_CENTER;
	static readonly LABEL = localize('hideNotificationsCenter', "Hide Notifications");

	constructor(
		id: string,
		label: string,
		@ICommandService private commandService: ICommandService
	) {
		super(id, label, 'hide-all-notifications-action');
	}

	run(notification: INotificationViewItem): Promise<any> {
		this.commandService.executeCommand(HIDE_NOTIFICATIONS_CENTER);

		return Promise.resolve(void 0);
	}
}

export class ExpandNotificationAction extends Action {

	static readonly ID = EXPAND_NOTIFICATION;
	static readonly LABEL = localize('expandNotification', "Expand Notification");

	constructor(
		id: string,
		label: string,
		@ICommandService private commandService: ICommandService
	) {
		super(id, label, 'expand-notification-action');
	}

	run(notification: INotificationViewItem): Promise<any> {
		this.commandService.executeCommand(EXPAND_NOTIFICATION, notification);

		return Promise.resolve(void 0);
	}
}

export class CollapseNotificationAction extends Action {

	static readonly ID = COLLAPSE_NOTIFICATION;
	static readonly LABEL = localize('collapseNotification', "Collapse Notification");

	constructor(
		id: string,
		label: string,
		@ICommandService private commandService: ICommandService
	) {
		super(id, label, 'collapse-notification-action');
	}

	run(notification: INotificationViewItem): Promise<any> {
		this.commandService.executeCommand(COLLAPSE_NOTIFICATION, notification);

		return Promise.resolve(void 0);
	}
}

export class ConfigureNotificationAction extends Action {

	static readonly ID = 'workbench.action.configureNotification';
	static readonly LABEL = localize('configureNotification', "Configure Notification");

	constructor(
		id: string,
		label: string,
		private _configurationActions: IAction[]
	) {
		super(id, label, 'configure-notification-action');
	}

	get configurationActions(): IAction[] {
		return this._configurationActions;
	}
}

export class CopyNotificationMessageAction extends Action {

	static readonly ID = 'workbench.action.copyNotificationMessage';
	static readonly LABEL = localize('copyNotification', "Copy Text");

	constructor(
		id: string,
		label: string,
		@IClipboardService private clipboardService: IClipboardService
	) {
		super(id, label);
	}

	run(notification: INotificationViewItem): Promise<any> {
		this.clipboardService.writeText(notification.message.raw);

		return Promise.resolve(void 0);
	}
}

export class NotificationActionRunner extends ActionRunner {

	constructor(
		@ITelemetryService private telemetryService: ITelemetryService,
		@INotificationService private notificationService: INotificationService
	) {
		super();
	}

	protected runAction(action: IAction, context: INotificationViewItem): Promise<any> {

		/* __GDPR__
			"workbenchActionExecuted" : {
				"id" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" },
				"from": { "classification": "SystemMetaData", "purpose": "FeatureInsight" }
			}
		*/
		this.telemetryService.publicLog('workbenchActionExecuted', { id: action.id, from: 'message' });

		// Run and make sure to notify on any error again
		super.runAction(action, context).then(null, error => this.notificationService.error(error));

		return Promise.resolve(void 0);
	}
}
