export type SettingsTab = 'apps' | 'rendering' | 'studio' | 'packages' | 'models' | 'shortcuts' | 'skills' | 'license' | 'updates';
type StudioMode = {
    readonly isBrowserStudio: boolean;
    readonly previewServerConnected: boolean;
    readonly readOnlyStudio: boolean;
};
export declare const canEditStudioConfig: ({ isBrowserStudio, previewServerConnected, readOnlyStudio, }: StudioMode) => boolean;
export declare const canInstallPackagesInStudio: (studioMode: StudioMode) => boolean;
export declare const getAvailableSettingsTabs: ({ isBrowserStudio, packageManagerAvailable, previewServerConnected, readOnlyStudio, showUpdates, }: StudioMode & {
    readonly packageManagerAvailable: boolean;
    readonly showUpdates: boolean;
}) => SettingsTab[];
export declare const getSafeSettingsTab: (requestedTab: SettingsTab, availableTabs: readonly SettingsTab[]) => SettingsTab;
export {};
