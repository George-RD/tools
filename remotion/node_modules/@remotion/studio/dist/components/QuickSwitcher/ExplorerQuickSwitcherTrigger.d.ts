import React from 'react';
import type { ComboboxValue } from '../NewComposition/ComboBox';
import type { QuickSwitcherMode } from './NoResults';
export declare const ExplorerQuickSwitcherTrigger: React.FC<{
    readonly mode: QuickSwitcherMode;
    readonly showShortcut: boolean;
    readonly tabIndex: number;
    readonly getActions: () => ComboboxValue[];
}>;
