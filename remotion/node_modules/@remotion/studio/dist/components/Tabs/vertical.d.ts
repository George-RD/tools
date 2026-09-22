import React from 'react';
export declare const VerticalTab: React.FC<{
    readonly children: string;
    readonly onClick: React.MouseEventHandler<HTMLButtonElement>;
    readonly renderIcon?: (color: string) => React.ReactNode;
    readonly style?: React.CSSProperties;
    readonly selected: boolean;
    readonly autoFocus?: boolean;
}>;
