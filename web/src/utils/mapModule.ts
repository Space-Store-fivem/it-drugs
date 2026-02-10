// SACRED VALUES - DO NOT TOUCH
const WORLD_SIZE = 16384.0;
const HALF_WORLD = WORLD_SIZE / 2;
const MAP_SIZE = 9550;
const OFFSET_X = -1950;
const OFFSET_Y = -1550;

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
    const mapX = (((x + OFFSET_X) + HALF_WORLD) / WORLD_SIZE) * MAP_SIZE;
    const mapY = ((HALF_WORLD - (y + OFFSET_Y)) / WORLD_SIZE) * MAP_SIZE;

    return [mapY, mapX];
}

let map: any = null;
let mapLayers: any[] = [];
let editorLayers: any[] = [];
let editorCircle: any = null; // Used for the Polygon layer
let editorData: any = {};


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

    loadMapData: (zones: any, currentGang: string, metadata: any, onZoneClick: (id: string) => void) => {

        if (!map || !zones) return;

        mapLayers.forEach(layer => map.removeLayer(layer));
        mapLayers = [];

        const zonesArray = Array.isArray(zones) ? zones : Object.values(zones);

        zonesArray.forEach((zone: any) => {
            let latlngs: any[] = [];

            // Prefer Visual Zone (Map Coords) if available, otherwise convert PolyZone (GTA Coords)
            if (zone.visual_zone && zone.visual_zone.points && zone.visual_zone.points.length >= 3) {
                latlngs = zone.visual_zone.points.map((p: any) => [p.x, p.y]);
            } else if (zone.polygon_points && zone.polygon_points.length >= 3) {
                latlngs = zone.polygon_points.map((p: any) => gtaToMap(p.x, p.y));
            }

            if (latlngs.length >= 3) {
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
                mapLayers.push(polygon);

                // Add Logo if available
                const owner = zone.owner_gang;
                if (owner && metadata && metadata[owner] && metadata[owner].logo) {
                    // Calculate Centroid
                    let sumLat = 0, sumLng = 0;
                    latlngs.forEach(p => { sumLat += p[0]; sumLng += p[1]; });
                    const center = L.latLng(sumLat / latlngs.length, sumLng / latlngs.length);

                    const logoIcon = L.icon({
                        iconUrl: metadata[owner].logo,
                        iconSize: [48, 48], // Size of the logo
                        iconAnchor: [24, 24],
                        className: 'gang-logo-marker filter drop-shadow-md'
                    });

                    const marker = L.marker(center, {
                        icon: logoIcon,
                        interactive: false // Click through to zone
                    }).addTo(map);

                    mapLayers.push(marker);
                }
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
            editorLayers = [];
            editorCircle = null;
            console.log("MapModule destroyed");
        }
    },

    // VISUAL EDITOR METHODS
    enableVisualEditor: (data: any, existingVisual?: any) => {
        if (!map) return;

        // Clear normal layers to focus on editing
        mapLayers.forEach(layer => map.removeLayer(layer));
        editorLayers.forEach(layer => map.removeLayer(layer));
        editorLayers = [];
        editorCircle = null;

        // 1. Draw "Ghost" PolyZone (Gameplay Area) - Static, dashed
        if (data.polyPoints && data.polyPoints.length >= 3) {
            const latlngs = data.polyPoints.map((p: any) => gtaToMap(p.x, p.y));
            const poly = L.polygon(latlngs, {
                color: '#ffffff',
                weight: 1,
                dashArray: '5, 10',
                fill: false,
                opacity: 0.3
            }).addTo(map);
            editorLayers.push(poly);
        }

        // 2. Determine Initial Points for Visual Polygon
        let pointsToDraw: L.LatLngExpression[] = [];
        let centroid: L.LatLng;

        if (existingVisual && existingVisual.type === 'polygon' && existingVisual.points) {
            // Load existing visual polygon (Saved as Map Coordinates {x: lat, y: lng})
            pointsToDraw = existingVisual.points.map((p: any) => [p.x, p.y]);

        } else if (data.polyPoints) {
            // Default to Poly coordinates (converted to Map)
            pointsToDraw = data.polyPoints.map((p: any) => gtaToMap(p.x, p.y));
        }

        // Calculate Centroid
        if (pointsToDraw.length > 0) {
            let sumLat = 0;
            let sumLng = 0;
            pointsToDraw.forEach((p: any) => {
                sumLat += p[0];
                sumLng += p[1];
            });
            centroid = L.latLng(sumLat / pointsToDraw.length, sumLng / pointsToDraw.length);
        } else {
            return;
        }

        // Center map
        map.setView(centroid, 5);

        // Store original relative positions for scaling
        editorData = {
            centroid: centroid,
            originalPoints: pointsToDraw.map((p: any) => {
                const pt = L.latLng(p[0], p[1]);
                return {
                    latDiff: pt.lat - centroid.lat,
                    lngDiff: pt.lng - centroid.lng
                };
            }),
            scale: 1.0,
            color: data.color || '#2ecc71'
        };

        // 3. Draggable Center Marker
        const markerIcon = L.divIcon({
            className: 'custom-editor-marker',
            html: `<div style="width: 14px; height: 14px; background: white; border: 3px solid ${data.color || '#2ecc71'}; border-radius: 50%; box-shadow: 0 0 10px rgba(0,0,0,0.5); cursor: move;"></div>`,
            iconSize: [14, 14],
            iconAnchor: [7, 7]
        });

        const editorMarker = L.marker(centroid, {
            draggable: true,
            icon: markerIcon
        }).addTo(map);

        editorMarker.on('drag', (e: any) => {
            const newCentroid = e.target.getLatLng();
            editorData.centroid = newCentroid;
            MapModule.redrawVisualPolygon();
        });

        editorLayers.push(editorMarker);

        // Initial Draw
        MapModule.redrawVisualPolygon();
    },

    redrawVisualPolygon: () => {
        // Remove old polygon if exists
        if (editorCircle) {
            map.removeLayer(editorCircle);
        }

        const { centroid, originalPoints, scale, color } = editorData;

        // Calculate new points based on Centroid + (Relative * Scale)
        const newPoints = originalPoints.map((offset: any) => [
            centroid.lat + (offset.latDiff * scale),
            centroid.lng + (offset.lngDiff * scale)
        ]);

        editorCircle = L.polygon(newPoints, {
            color: color,
            fillColor: color,
            fillOpacity: 0.4,
            weight: 3
        }).addTo(map);

        editorLayers.push(editorCircle);
    },

    updateEditorScale: (scale: number) => {
        if (!editorData.originalPoints) return;
        editorData.scale = scale;
        MapModule.redrawVisualPolygon();
    },

    getEditorData: () => {
        if (!editorCircle) return null;

        // Get final points from the drawn polygon
        const latlngs = (editorCircle as L.Polygon).getLatLngs()[0] as L.LatLng[];

        // Save as Map Coords { x: lat, y: lng }
        // This makes loading easy (just pass back to Leaflet)
        return {
            type: 'polygon',
            points: latlngs.map(p => ({ x: p.lat, y: p.lng }))
        };
    }
};
