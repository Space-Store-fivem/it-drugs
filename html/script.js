document.addEventListener('DOMContentLoaded', function () {
    console.log('Gang Panel UI Loaded (Modular Version)');

    let lastZonesData = null;
    let selectedZoneId = null;
    let currentGangName = 'Desconhecido';

    // Initial state
    window.addEventListener('message', function (event) {
        const item = event.data;

        if (item.action === 'open') {
            currentGangName = item.gangName || 'Desconhecido';
            document.getElementById('gang-name').textContent = currentGangName;

            const app = document.getElementById('app');
            app.style.display = 'flex';
            app.style.opacity = '1';

            // Check Admin
            if (item.isAdmin) {
                document.getElementById('admin-menu-item').style.display = 'flex';
                populateGangSelect(item.availableGangs);
            } else {
                document.getElementById('admin-menu-item').style.display = 'none';
            }

            // Store zones
            lastZonesData = item.zones;

            // Initialize map if not already done
            setTimeout(() => {
                if (window.MapModule) {
                    MapModule.initMap();
                    refreshMap();
                    MapModule.invalidateSize();
                } else {
                    console.error('MapModule is not loaded!');
                }
            }, 100);

        } else if (item.action === 'close') {
            document.getElementById('app').style.display = 'none';
        }
    });

    document.getElementById('close-btn').addEventListener('click', closePanel);
    document.addEventListener('keyup', function (e) { if (e.key === "Escape") closePanel(); });

    function closePanel() {
        fetch('https://it-drugs/close', { method: 'POST', body: JSON.stringify({}) });
        document.getElementById('app').style.display = 'none';
    }

    // Tabs Logic
    document.querySelectorAll('.menu-item').forEach(item => {
        item.addEventListener('click', function () {
            document.querySelectorAll('.menu-item').forEach(i => i.classList.remove('active'));
            this.classList.add('active');
            const tabId = this.getAttribute('data-tab');
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));

            const target = document.getElementById(tabId + '-tab');
            if (target) target.classList.add('active');

            // Resize map if switching to map tab
            if (tabId === 'map' && window.MapModule) {
                setTimeout(() => { MapModule.invalidateSize(); }, 200);
            }
        });
    });

    function populateGangSelect(availableGangs) {
        const gangSelect = document.getElementById('creator-gang-id');
        gangSelect.innerHTML = '<option value="" disabled selected>Selecione a Gangue</option>';

        if (availableGangs && availableGangs.length > 0) {
            availableGangs.forEach(g => {
                const opt = document.createElement('option');
                opt.value = g.id || g.name; // Adapt based on what server sends
                opt.textContent = g.label || g.name || g.id;
                gangSelect.appendChild(opt);
            });
        } else {
            // Fallback
            gangSelect.innerHTML += '<option value="ballas">Ballas</option><option value="vagos">Vagos</option><option value="famillies">Families</option>';
        }
    }

    function refreshMap() {
        if (!window.MapModule) return;

        MapModule.loadMapData(lastZonesData, currentGangName, (zoneId) => {
            selectedZoneId = zoneId;
            updateZoneSelectionUI();
        });

        // Also update the target select dropdown for wars
        updateTargetZoneSelect();
    }

    function updateZoneSelectionUI() {
        // Here we could add visual logic to highlight selected zone in list
        // and pre-select it in the dropdown
        if (selectedZoneId) {
            const select = document.getElementById('target-zone-select');
            select.value = selectedZoneId;
            // Trigger change event to enable button
            const event = new Event('change');
            select.dispatchEvent(event);
        }
    }

    function updateTargetZoneSelect() {
        const select = document.getElementById('target-zone-select');
        select.innerHTML = '<option value="" disabled selected>Selecione um Território</option>';

        if (!lastZonesData) return;

        const zonesArray = Array.isArray(lastZonesData) ? lastZonesData : Object.values(lastZonesData);

        zonesArray.forEach(zone => {
            if (zone.owner_gang !== currentGangName) {
                const option = document.createElement('option');
                option.value = zone.zone_id;
                option.textContent = zone.label;
                select.appendChild(option);
            }
        });

        if (selectedZoneId) {
            select.value = selectedZoneId;
        }
    }

    // ADMIN CREATOR LOGIC
    document.getElementById('btn-start-creator').addEventListener('click', function () {
        const gangId = document.getElementById('creator-gang-id').value;
        const label = document.getElementById('creator-zone-label').value;

        if (!gangId || !label) {
            // maybe show a toast
            return;
        }

        closePanel();

        fetch('https://it-drugs/startCreator', {
            method: 'POST',
            body: JSON.stringify({ gangId: gangId, label: label })
        });
    });

    // War Declare Logic
    document.getElementById('target-zone-select').addEventListener('change', function () {
        document.getElementById('declare-war-btn').disabled = !this.value;
    });

    document.getElementById('declare-war-btn').addEventListener('click', function () {
        const zoneId = document.getElementById('target-zone-select').value;
        if (zoneId) {
            fetch('https://it-drugs/declareWar', {
                method: 'POST',
                body: JSON.stringify({ zoneId: zoneId })
            });
        }
    });
});
