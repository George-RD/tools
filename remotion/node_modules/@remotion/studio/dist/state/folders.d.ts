import React from 'react';
import type { ExpandedFoldersState } from '../helpers/persist-open-folders';
export type CompositionSortOrder = 'registration' | 'alphabetical';
type TFolderContext = {
    compositionFoldersExpanded: ExpandedFoldersState;
    setCompositionFoldersExpanded: React.Dispatch<React.SetStateAction<ExpandedFoldersState>>;
    assetFoldersExpanded: ExpandedFoldersState;
    setAssetFoldersExpanded: React.Dispatch<React.SetStateAction<ExpandedFoldersState>>;
    compositionSortOrder: CompositionSortOrder;
    setCompositionSortOrder: (sortOrder: CompositionSortOrder) => void;
};
export declare const FolderContext: React.Context<TFolderContext>;
export declare const FolderContextProvider: React.FC<{
    readonly children: React.ReactNode;
}>;
export {};
