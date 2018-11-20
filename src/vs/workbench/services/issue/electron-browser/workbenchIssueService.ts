/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IssueReporterStyles, IIssueService, IssueReporterData, ProcessExplorerData, IssueReporterExtensionData } from 'vs/platform/issue/common/issue';
import { ITheme, IThemeService } from 'vs/platform/theme/common/themeService';
import { textLinkForeground, inputBackground, inputBorder, inputForeground, buttonBackground, buttonHoverBackground, buttonForeground, inputValidationErrorBorder, foreground, inputActiveOptionBorder, scrollbarSliderActiveBackground, scrollbarSliderBackground, scrollbarSliderHoverBackground, editorBackground, editorForeground, listHoverBackground, listHoverForeground, listHighlightForeground, textLinkActiveForeground } from 'vs/platform/theme/common/colorRegistry';
import { SIDE_BAR_BACKGROUND } from 'vs/workbench/common/theme';
import { IExtensionManagementService, IExtensionEnablementService, LocalExtensionType } from 'vs/platform/extensionManagement/common/extensionManagement';
import { webFrame } from 'electron';
import { assign } from 'vs/base/common/objects';
import { IWorkbenchIssueService } from 'vs/workbench/services/issue/common/issue';
import { IWindowService } from 'vs/platform/windows/common/windows';

export class WorkbenchIssueService implements IWorkbenchIssueService {
	_serviceBrand: any;

	constructor(
		@IIssueService private issueService: IIssueService,
		@IThemeService private themeService: IThemeService,
		@IExtensionManagementService private extensionManagementService: IExtensionManagementService,
		@IExtensionEnablementService private extensionEnablementService: IExtensionEnablementService,
		@IWindowService private windowService: IWindowService
	) {
	}

	openReporter(dataOverrides: Partial<IssueReporterData> = {}): Promise<void> {
		return this.extensionManagementService.getInstalled(LocalExtensionType.User).then(extensions => {
			const enabledExtensions = extensions.filter(extension => this.extensionEnablementService.isEnabled(extension));
			const extensionData: IssueReporterExtensionData[] = enabledExtensions.map(extension => {
				const { manifest } = extension;
				const manifestKeys = manifest.contributes ? Object.keys(manifest.contributes) : [];
				const isTheme = !manifest.activationEvents && manifestKeys.length === 1 && manifestKeys[0] === 'themes';

				return {
					name: manifest.name,
					publisher: manifest.publisher,
					version: manifest.version,
					repositoryUrl: manifest.repository && manifest.repository.url,
					bugsUrl: manifest.bugs && manifest.bugs.url,
					displayName: manifest.displayName,
					id: extension.identifier.id,
					isTheme: isTheme
				};
			});
			const theme = this.themeService.getTheme();
			const issueReporterData: IssueReporterData = assign(
				{
					styles: getIssueReporterStyles(theme),
					zoomLevel: webFrame.getZoomLevel(),
					enabledExtensions: extensionData
				},
				dataOverrides);

			return this.issueService.openReporter(issueReporterData);
		});
	}

	openProcessExplorer(): Thenable<void> {
		const theme = this.themeService.getTheme();
		const data: ProcessExplorerData = {
			pid: this.windowService.getConfiguration().mainPid,
			zoomLevel: webFrame.getZoomLevel(),
			styles: {
				backgroundColor: theme.getColor(editorBackground) && theme.getColor(editorBackground).toString(),
				color: theme.getColor(editorForeground).toString(),
				hoverBackground: theme.getColor(listHoverBackground) && theme.getColor(listHoverBackground).toString(),
				hoverForeground: theme.getColor(listHoverForeground) && theme.getColor(listHoverForeground).toString(),
				highlightForeground: theme.getColor(listHighlightForeground) && theme.getColor(listHighlightForeground).toString()
			}
		};
		return this.issueService.openProcessExplorer(data);
	}
}

export function getIssueReporterStyles(theme: ITheme): IssueReporterStyles {
	return {
		backgroundColor: theme.getColor(SIDE_BAR_BACKGROUND) && theme.getColor(SIDE_BAR_BACKGROUND).toString(),
		color: theme.getColor(foreground).toString(),
		textLinkColor: theme.getColor(textLinkForeground) && theme.getColor(textLinkForeground).toString(),
		textLinkActiveForeground: theme.getColor(textLinkActiveForeground) && theme.getColor(textLinkActiveForeground).toString(),
		inputBackground: theme.getColor(inputBackground) && theme.getColor(inputBackground).toString(),
		inputForeground: theme.getColor(inputForeground) && theme.getColor(inputForeground).toString(),
		inputBorder: theme.getColor(inputBorder) && theme.getColor(inputBorder).toString(),
		inputActiveBorder: theme.getColor(inputActiveOptionBorder) && theme.getColor(inputActiveOptionBorder).toString(),
		inputErrorBorder: theme.getColor(inputValidationErrorBorder) && theme.getColor(inputValidationErrorBorder).toString(),
		buttonBackground: theme.getColor(buttonBackground) && theme.getColor(buttonBackground).toString(),
		buttonForeground: theme.getColor(buttonForeground) && theme.getColor(buttonForeground).toString(),
		buttonHoverBackground: theme.getColor(buttonHoverBackground) && theme.getColor(buttonHoverBackground).toString(),
		sliderActiveColor: theme.getColor(scrollbarSliderActiveBackground) && theme.getColor(scrollbarSliderActiveBackground).toString(),
		sliderBackgroundColor: theme.getColor(scrollbarSliderBackground) && theme.getColor(scrollbarSliderBackground).toString(),
		sliderHoverColor: theme.getColor(scrollbarSliderHoverBackground) && theme.getColor(scrollbarSliderHoverBackground).toString()
	};
}
