// SACRED VALUES - DO NOT TOUCH
const WORLD_SIZE = 16384.0;
const HALF_WORLD = WORLD_SIZE / 2;
const MAP_SIZE = 8192;
const OFFSET_X = -523;
const OFFSET_Y = -2214;
const ZONE_SCALE = 1.3;

declare const L: any;

const GANG_COLORS: Record<string, string> = {
    'ballas': '#9c27b0',
    'vagos': '#fbc02d',
    'families': '#2e7d32',
    'groove': '#2e7d32',
    'aztecas': '#00bcd4',
    'marabunta': '#0288d1',
    'bloods': '#d32f2f',
    'crips': '#1565c0',
    'lostmc': '#546e7a',
    'police': '#1a237e',
    'neutral': '#9e9e9e'
};

function stringToColor(str: string) {
    if (!str) return '#9e9e9e';
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        hash = str.charCodeAt(i) + ((hash << 5) - hash);
    }
    let color = '#';
    for (let i = 0; i < 3; i++) {
        let value = (hash >> (i * 8)) & 0xFF;
        color += ('00' + value.toString(16)).substr(-2);
    }
    return color;
}

function getGangColor(gangName: string) {
    if (!gangName) return GANG_COLORS['neutral'];
    const lower = gangName.toLowerCase();

    // Check for explicit color sent from backend (if passed as hex)
    if (gangName.startsWith('#')) return gangName;

    if (GANG_COLORS[lower]) return GANG_COLORS[lower];

    for (const [key, color] of Object.entries(GANG_COLORS)) {
        if (lower.includes(key)) return color;
    }
    return stringToColor(gangName);
}

function gtaToMap(x: number, y: number): [number, number] {
    const scaledX = (x + OFFSET_X) * ZONE_SCALE;
    const scaledY = (y + OFFSET_Y) * ZONE_SCALE;

    const mapX = ((scaledX + HALF_WORLD) / WORLD_SIZE) * MAP_SIZE;
    const mapY = ((HALF_WORLD - scaledY) / WORLD_SIZE) * MAP_SIZE;

    return [mapY, mapX];
}

let map: any = null;
let mapLayers: any[] = [];

export const MapModule = {
    initMap: () => {
        if (map) return;
        if (typeof L === 'undefined') {
            console.error("Leaflet (L) is not defined. Make sure to load Leaflet before MapModule.");
            return;
        }

        const factor = 1.0 / 32;
        const customCRS = L.Util.extend({}, L.CRS.Simple, {
            transformation: new L.Transformation(factor, 0, factor, 0)
        });

        map = L.map('game-map', {
            crs: customCRS,
            minZoom: 3,
            maxZoom: 7,
            zoomControl: false,
            attributionControl: false,
            center: [4096, 4096],
            zoom: 3,
            maxBoundsViscosity: 0.5
        });

        // Use absolute path for NUI
        const tileLayer = L.tileLayer('https://cfx-nui-it-drugs/tiles/satellite/{z}/{x}_{y}.png', {
            minZoom: 3,
            maxZoom: 7,
            maxNativeZoom: 5, // Fix: Upscale level 5 tiles for zoom 6-7
            tileSize: 256,
            noWrap: true,
            tms: false
        }).addTo(map);

        const bounds = [[0, 0], [MAP_SIZE, MAP_SIZE]];
        map.setMaxBounds(bounds);
        map.fitBounds(bounds);

        console.log("MapModule initialized (React Version)");
    },

    loadMapData: (zones: any, currentGang: string, onZoneClick: (id: string) => void) => {
        if (!map || !zones) return;

        mapLayers.forEach(layer => map.removeLayer(layer));
        mapLayers = [];

        const zonesArray = Array.isArray(zones) ? zones : Object.values(zones);

        zonesArray.forEach((zone: any) => {
            if (zone.polygon_points && zone.polygon_points.length >= 3) {
                const latlngs = zone.polygon_points.map((p: any) => gtaToMap(p.x, p.y));

                // COLOR LOGIC: User priority -> "admin na hora de criar decide a cor"
                // Expecting zone.color from backend. Fallback to gang logic.
                const resolveColor = (c: any) => {
                    if (!c) return null;
                    if (typeof c === 'string') return c;
                    if (c.r !== undefined && c.g !== undefined && c.b !== undefined) {
                        return `rgb(${c.r}, ${c.g}, ${c.b})`;
                    }
                    return null;
                };

                const baseColor = resolveColor(zone.color) || getGangColor(zone.owner_gang || zone.gang_name);

                let strokeColor = baseColor;
                let className = 'animated-zone';

                if (zone.current_status === 'war') {
                    strokeColor = '#e74c3c';
                    className += ' war-pulse';
                } else if (zone.owner_gang === currentGang) {
                    strokeColor = '#ffffff';
                }

                const polygon = L.polygon(latlngs, {
                    color: strokeColor,
                    fillColor: baseColor,
                    fillOpacity: 0.45,
                    weight: (zone.owner_gang === currentGang) ? 3 : 2,
                    className: className
                }).addTo(map);

                // Inline styles for tooltip
                const badgeStyle = `background-color: ${baseColor}; color: white; border: 1px solid rgba(255,255,255,0.2); text-shadow: 0 1px 2px black;`;

                polygon.bindTooltip(`
                    <div class="zone-tooltip text-center p-2">
                        <strong class="text-sm font-bold uppercase block mb-1">${zone.label}</strong>
                        <span class="inline-block px-2 py-0.5 rounded text-[11px] font-bold uppercase" style="${badgeStyle}">
                            ${zone.owner_gang || 'Sem Dono'}
                        </span>
                        ${zone.current_status === 'war' ? '<br><span class="bg-red-500/20 text-red-500 inline-block px-2 py-0.5 rounded text-[10px] mt-1 font-bold">EM GUERRA</span>' : ''}
                    </div>
                `, { sticky: true, className: 'custom-tooltip bg-[#09090b]/95 border border-white/10 rounded-md shadow-xl' });

                polygon.on('click', (e: any) => {
                    L.DomEvent.stopPropagation(e);
                    if (onZoneClick) onZoneClick(zone.zone_id);
                });

                mapLayers.push(polygon);
            }
        });
    },

    invalidateSize: () => {
        if (map) map.invalidateSize();
    },

    destroyMap: () => {
        if (map) {
            map.remove();
            map = null;
            mapLayers = [];
            console.log("MapModule destroyed");
        }
    }
};
