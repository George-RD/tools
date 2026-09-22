import React from 'react';
import type { AssetStructure } from '../helpers/create-folder-tree';
import type { ComboboxValue } from './NewComposition/ComboBox';
export { getAssetActionAvailability, getAssetContextMenuItems, } from './asset-context-menu';
export declare const getCanDragAsset: ({ readOnlyStudio, relativePath, }: {
    readOnlyStudio: boolean;
    relativePath: string;
}) => boolean;
export declare const getAssetFolderContextMenuItems: ({ folderPath, fileManagerName, copyFolderPath, copyAbsolutePath, openFolderInExplorer, uploadAssets, fileExplorerAvailable, fileExplorerDisabled, mutationsDisabled, }: {
    folderPath: string;
    fileManagerName: string;
    copyFolderPath: () => void;
    copyAbsolutePath: (() => void) | null;
    openFolderInExplorer: () => void;
    uploadAssets: () => void;
    fileExplorerAvailable: boolean;
    fileExplorerDisabled: boolean;
    mutationsDisabled: boolean;
}) => ComboboxValue[];
export declare const AssetFolderTree: React.FC<{
    readonly item: AssetStructure;
    readonly name: string | null;
    readonly parentFolder: string | null;
    readonly level: number;
    readonly tabIndex: number;
    readonly toggleFolder: (folderName: string, parentName: string | null) => void;
    readonly dropLocation: string | null;
    readonly setDropLocation: React.Dispatch<React.SetStateAction<string | null>>;
    readonly readOnlyStudio: boolean;
    readonly uploadAssets: (assetPath: string | null) => void;
}>;
