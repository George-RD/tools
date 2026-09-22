import React from 'react';
export declare const CollapsibleInspectorSectionHeader: React.FC<{
    readonly action: React.ReactNode;
    readonly expanded: boolean;
    readonly label: string;
    readonly onToggle: (() => void) | null;
}>;
