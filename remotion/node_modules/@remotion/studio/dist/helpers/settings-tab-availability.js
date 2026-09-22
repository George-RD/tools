"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSafeSettingsTab = exports.getAvailableSettingsTabs = exports.canInstallPackagesInStudio = exports.canEditStudioConfig = void 0;
const canEditStudioConfig = ({ isBrowserStudio, previewServerConnected, readOnlyStudio, }) => {
    return previewServerConnected && !readOnlyStudio && !isBrowserStudio;
};
exports.canEditStudioConfig = canEditStudioConfig;
const canInstallPackagesInStudio = (studioMode) => {
    return studioMode.isBrowserStudio || (0, exports.canEditStudioConfig)(studioMode);
};
exports.canInstallPackagesInStudio = canInstallPackagesInStudio;
const getAvailableSettingsTabs = ({ isBrowserStudio, packageManagerAvailable, previewServerConnected, readOnlyStudio, showUpdates, }) => {
    const studioMode = {
        isBrowserStudio,
        previewServerConnected,
        readOnlyStudio,
    };
    const canEditConfig = (0, exports.canEditStudioConfig)(studioMode);
    const canInstallPackages = (0, exports.canInstallPackagesInStudio)(studioMode) &&
        (isBrowserStudio || packageManagerAvailable);
    return [
        ...(canEditConfig ? ['studio', 'rendering'] : []),
        'shortcuts',
        ...(canInstallPackages ? ['packages'] : []),
        ...(canEditConfig ? ['skills'] : []),
        ...(isBrowserStudio || !readOnlyStudio ? ['models'] : []),
        ...(canEditConfig ? ['apps', 'license'] : []),
        ...(showUpdates ? ['updates'] : []),
    ];
};
exports.getAvailableSettingsTabs = getAvailableSettingsTabs;
const getSafeSettingsTab = (requestedTab, availableTabs) => {
    return availableTabs.includes(requestedTab) ? requestedTab : 'shortcuts';
};
exports.getSafeSettingsTab = getSafeSettingsTab;
