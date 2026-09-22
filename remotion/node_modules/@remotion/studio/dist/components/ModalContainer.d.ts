import React from 'react';
export declare const getMaxModalWidth: (width: number) => string;
export declare const getMaxModalHeight: (height: number) => string;
export declare const ModalContainer: React.FC<{
    readonly ariaLabel?: string;
    readonly ariaLabelledBy?: string;
    readonly onEscape: () => void;
    readonly onOutsideClick: () => void;
    readonly children: React.ReactNode;
    readonly noZIndex?: boolean;
    readonly panelStyle?: React.CSSProperties;
}>;
