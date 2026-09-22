import React from 'react';
import type { MediaMetadata } from '../helpers/use-media-metadata';
export declare const CURRENT_ASSET_HEIGHT = 28;
export declare const getCurrentAssetMetadataSource: (assetName: string | null) => string | null;
export declare const getCurrentAssetImageMetadataSource: (assetName: string | null) => string | null;
type CurrentAssetDetail = {
    readonly label: string;
    readonly value: string;
};
export declare const getCurrentAssetMediaSections: (mediaMetadata: MediaMetadata) => {
    audio: CurrentAssetDetail[] | null;
    video: CurrentAssetDetail[] | null;
};
export declare const AssetInfo: React.FC<{
    readonly assetName: string | null;
    readonly contentSized?: boolean;
    readonly onAssetClick?: () => void;
    readonly readOnlyStudio: boolean;
}>;
export declare const CurrentAsset: React.FC<{
    readonly readOnlyStudio: boolean;
}>;
export {};
