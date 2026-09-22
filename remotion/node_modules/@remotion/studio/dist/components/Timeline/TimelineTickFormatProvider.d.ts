import React from 'react';
export declare const TimelineTickFormatContext: React.Context<{
    showFrames: boolean;
    setShowFrames: React.Dispatch<React.SetStateAction<boolean>>;
}>;
export declare const TimelineTickFormatProvider: React.FC<{
    readonly children: React.ReactNode;
}>;
