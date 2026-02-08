import { create } from 'zustand';

interface Zone {
    zone_id: string;
    label: string;
    owner_gang: string;
    color?: string;
    current_status?: string;
    polygon_points: { x: number, y: number }[];
    // Add other properties as needed
}

interface AppState {
    open: boolean;
    tab: 'map' | 'wars' | 'admin';
    gangName: string;
    isAdmin: boolean;
    zones: Record<string, Zone>;
    availableGangs: any[];
    selectedZoneId: string | null;
    activeWars: any; // Using any for simplicity, ideally define War interface
    warRequests: any[];
    gangGrade: number;
    isBoss: boolean;
    captureState?: {
        active: boolean;
        zoneId: string;
        progress: number;
        status: string;
        attacker: string;
        defender: string;
        attackerCount: number;
        defenderCount: number;
    };
    warAlert?: {
        message: string;
        subMessage?: string;
        type: 'warning' | 'error' | 'info';
        endTime?: number;
    };

    setOpen: (open: boolean) => void;
    setTab: (tab: 'map' | 'wars' | 'admin') => void;
    setGangName: (name: string) => void;
    setIsAdmin: (isAdmin: boolean) => void;
    setZones: (zones: Record<string, Zone>) => void;
    setAvailableGangs: (gangs: any[]) => void;
    setSelectedZoneId: (id: string | null) => void;
    setActiveWars: (wars: any) => void;
    setWarRequests: (requests: any[]) => void;
    showWarAlert: (alert: AppState['warAlert']) => void;
    hideWarAlert: () => void;

    // Actions for NUI
    receiveNuiMessage: (data: any) => void;

    upgradesConfig: any; // Store configuration for upgrades
}

export const useAppStore = create<AppState>((set) => ({
    open: false, // Default hidden
    tab: 'map',
    gangName: 'Desconhecido',
    isAdmin: false,
    zones: {},
    availableGangs: [],
    selectedZoneId: null,
    activeWars: {}, // Key: zoneId
    warRequests: [], // Initialized warRequests
    gangGrade: 0,
    isBoss: false,
    captureState: undefined,
    warAlert: undefined,
    upgradesConfig: {},

    setOpen: (open) => set({ open }),
    setTab: (tab) => set({ tab }),
    setGangName: (gangName) => set({ gangName }),
    setIsAdmin: (isAdmin) => set({ isAdmin }),
    setZones: (zones) => set({ zones }),
    setAvailableGangs: (availableGangs) => set({ availableGangs }),
    setSelectedZoneId: (selectedZoneId) => set({ selectedZoneId }),
    setActiveWars: (wars) => set({ activeWars: wars }),
    setWarRequests: (warRequests) => set({ warRequests }), // Added setter implementation
    showWarAlert: (warAlert) => set({ warAlert }),
    hideWarAlert: () => set({ warAlert: undefined }),

    receiveNuiMessage: (data) => {
        if (data.action === 'open') {
            set({
                open: true,
                gangName: data.gangName || 'Desconhecido',
                isAdmin: !!data.isAdmin,
                zones: formatZones(data.zones),
                availableGangs: data.availableGangs || [],
                activeWars: data.activeWars || {}, // Ensure activeWars is set on open
                warRequests: data.warRequests || [], // Set warRequests on open
                gangGrade: data.gangGrade || 0,
                isBoss: !!data.isBoss,
                upgradesConfig: data.upgradesConfig || {}
            });
        } else if (data.action === 'close') {
            set({ open: false });
        } else if (data.action === 'updateZones') {
            set({ zones: formatZones(data.zones) });
        } else if (data.action === 'warUpdate') {
            set({ activeWars: data.wars || {} });
        } else if (data.action === 'warRequestsUpdate') {
            set({ warRequests: data.requests || [] });
        } else if (data.action === 'captureUpdate') {
            set({ captureState: data.state });
        } else if (data.action === 'warAlert') {
            if (data.alert) {
                set({ warAlert: data.alert });
            } else {
                set({ warAlert: undefined });
            }
        }
    }
}));


function formatZones(zonesData: any): Record<string, Zone> {
    if (!zonesData) return {};

    // If it's already an object (not array), return it
    if (!Array.isArray(zonesData) && typeof zonesData === 'object') {
        return zonesData;
    }

    // If it's an array, convert to object by zone_id
    if (Array.isArray(zonesData)) {
        const zonesMap: Record<string, Zone> = {};
        zonesData.forEach((zone: any) => {
            if (zone.zone_id) {
                zonesMap[zone.zone_id] = zone;
            }
        });
        return zonesMap;
    }

    return {};
}
