import type { SelectedOutlineLayoutTarget, SelectedOutlineTarget } from './selected-outline-types';
export declare const useSelectedOutlineControlTarget: ({ getLatestTargetByKey, layoutTarget, }: {
    readonly getLatestTargetByKey: (key: string) => SelectedOutlineTarget | undefined;
    readonly layoutTarget: SelectedOutlineLayoutTarget | undefined;
}) => {
    controlTarget: SelectedOutlineTarget | undefined;
    getLayoutTarget: () => SelectedOutlineLayoutTarget | undefined;
    getTarget: () => SelectedOutlineTarget | undefined;
    hovered: boolean;
    onHoverChange: (key: string | null) => void;
};
