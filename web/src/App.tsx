import { useEffect, useState } from 'react';
import { useAppStore } from './store/useAppStore';
import { MapModule } from './utils/mapModule';
import { Map as MapIcon, Swords, Shield, X, Inbox, Flag, Clock, User, Check, Calendar, Trophy, ChevronsUp, Settings } from 'lucide-react';
import { CaptureProgress } from './components/CaptureProgress';
import { WarAlerts } from './components/WarAlerts';
import { RankingPanel } from './components/RankingPanel';

import ZoneNotification from './components/ZoneNotification';

function cn(...classes: (string | undefined | null | false)[]) {
    return classes.filter(Boolean).join(' ');
}

export default function App() {
    const { open, tab, gangName, isAdmin, isBoss, setTab, setOpen, receiveNuiMessage, isVisualEditorOpen } = useAppStore();
    const [showColorModal, setShowColorModal] = useState(false);
    const [showLogoModal, setShowLogoModal] = useState(false);


    useEffect(() => {
        const handleMessage = (event: MessageEvent) => {
            receiveNuiMessage(event.data);
        };
        window.addEventListener('message', handleMessage);
        return () => window.removeEventListener('message', handleMessage);
    }, []);

    useEffect(() => {
        if (open) {
            // Debug only: ensures map resizes correctely when displayed
            setTimeout(() => { window.dispatchEvent(new Event('resize')); }, 100);
        }
    }, [open]);

    const handleClose = () => {
        fetch('https://it-drugs/close', { method: 'POST', body: JSON.stringify({}) });
        setOpen(false);
    }

    return (
        <>
            <CaptureProgress />
            <WarAlerts />
            <ZoneNotification />

            {open && isVisualEditorOpen && <VisualEditor />}

            {open && !isVisualEditorOpen && (
                <div className="flex items-center justify-center w-screen h-screen bg-black/80">
                    <div className="w-[90vw] h-[85vh] bg-[#09090b]/95 border border-white/10 rounded-xl shadow-2xl flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-300">
                        {/* Header */}
                        <header className="h-16 px-6 border-b border-white/10 flex items-center justify-between bg-white/5">
                            <div>
                                <h1 className="text-xl font-bold text-white uppercase tracking-wider flex items-center gap-2">
                                    <Shield className="w-5 h-5 text-purple-500" />
                                    Controle de Território
                                </h1>
                                <div className="flex items-center gap-2 mt-0.5">
                                    <p className="text-xs text-zinc-400 uppercase tracking-widest font-medium">
                                        Facção: <span className="text-purple-400">{gangName}</span>
                                    </p>
                                    {isBoss && (
                                        <>

                                            <button
                                                onClick={() => setShowLogoModal(true)}
                                                className="ml-2 p-1 rounded-full bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-colors"
                                                title="Mudar Logo da Gangue"
                                            >
                                                <Flag className="w-3 h-3" />
                                            </button>
                                        </>
                                    )}
                                </div>

                            </div>
                            <button onClick={handleClose} className="w-8 h-8 rounded-full flex items-center justify-center hover:bg-white/10 transition-colors text-zinc-400 hover:text-white">
                                <X className="w-5 h-5" />
                            </button>
                        </header>

                        {/* Main Content */}
                        <main className="flex-1 flex overflow-hidden">
                            {/* Sidebar */}
                            <aside className="w-64 bg-black/20 border-r border-white/10 p-4 flex flex-col gap-2">
                                <NavButton
                                    active={tab === 'map'}
                                    onClick={() => setTab('map')}
                                    icon={<MapIcon className="w-4 h-4" />}
                                    label="Mapa Tático"
                                />
                                <NavButton
                                    active={tab === 'wars'}
                                    onClick={() => setTab('wars')}
                                    icon={<Swords className="w-4 h-4" />}
                                    label="Zonas de Guerra"
                                />
                                <NavButton
                                    active={tab === 'ranking'}
                                    onClick={() => setTab('ranking')}
                                    icon={<Trophy className="w-4 h-4" />}
                                    label="Ranking"
                                />

                                {isAdmin && (
                                    <div className="mt-auto pt-4 border-t border-white/10">
                                        <NavButton
                                            active={tab === 'admin'}
                                            onClick={() => setTab('admin')}
                                            icon={<Shield className="w-4 h-4" />}
                                            label="Administração"
                                            className="text-yellow-500 hover:bg-yellow-500/10 hover:text-yellow-400"
                                        />
                                    </div>
                                )}
                            </aside>

                            {/* Content Area */}
                            <div className="flex-1 relative bg-zinc-950">
                                <div className={cn("absolute inset-0 z-0", tab === 'map' ? 'visible' : 'invisible')}>
                                    <GameMap />
                                    <ZoneDetails />
                                </div>

                                {tab === 'wars' && <div className="absolute inset-0 z-10 bg-[#09090b]"><WarsPanel /></div>}
                                {tab === 'ranking' && <div className="absolute inset-0 z-10 bg-[#09090b]"><RankingPanel /></div>}

                                {tab === 'admin' && <div className="absolute inset-0 z-10 bg-[#09090b]"><AdminPanel /></div>}
                            </div>
                        </main>
                    </div>
                </div>
            )}

            {showColorModal && (
                <ColorPickerModal
                    onClose={() => setShowColorModal(false)}
                    initialColor={{ r: 255, g: 255, b: 255 }}
                    onSave={(rgb) => {
                        fetch('https://it-drugs/setGangColor', {
                            method: 'POST',
                            body: JSON.stringify(rgb)
                        });
                        setShowColorModal(false);
                    }}
                />
            )}

            {showLogoModal && (
                <ChangeLogoModal
                    onClose={() => setShowLogoModal(false)}
                />
            )}
        </>
    );
}

function ChangeLogoModal({ onClose }: { onClose: () => void }) {
    const [url, setUrl] = useState('');
    const { gangLogo } = useAppStore();

    useEffect(() => {
        if (gangLogo) setUrl(gangLogo);
    }, [gangLogo]);

    const handleSave = () => {
        if (!url.trim()) return;
        fetch('https://it-drugs/setGangLogo', {
            method: 'POST',
            body: JSON.stringify({ url: url.trim() })
        });
        onClose();
    };

    return (
        <div className="fixed inset-0 z-[10000] flex items-center justify-center bg-black/80 backdrop-blur-md p-4 animate-in fade-in duration-300">
            <div className="w-full max-w-md glass-panel rounded-2xl overflow-hidden shadow-2xl animate-in zoom-in-95 duration-300 border border-white/10">
                <div className="glass-header px-6 py-5 flex justify-between items-center bg-[#0a0a0f]/50">
                    <div>
                        <h2 className="text-xl font-bold text-white flex items-center gap-3 uppercase tracking-wider text-glow">
                            <Flag className="w-5 h-5 text-purple-500" />
                            Logo da Gangue
                        </h2>
                        <p className="text-xs text-zinc-400 font-mono tracking-widest mt-1 uppercase">Defina o URL da imagem (PNG)</p>
                    </div>
                    <button onClick={onClose} className="p-2 hover:bg-white/10 rounded-lg transition-colors text-zinc-400 hover:text-white">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <div className="p-6 space-y-4">
                    <div className="space-y-1">
                        <label className="text-xs font-bold text-zinc-500 uppercase tracking-widest">URL da Imagem</label>
                        <input
                            type="text"
                            className="w-full bg-black/40 border border-white/10 rounded-lg px-4 py-3 text-white text-sm focus:outline-none focus:border-purple-500 transition-colors placeholder:text-zinc-700"
                            placeholder="https://i.imgur.com/example.png"
                            value={url}
                            onChange={(e) => setUrl(e.target.value)}
                        />
                    </div>

                    {url && (
                        <div className="flex justify-center p-4 bg-black/20 rounded-lg border border-white/5">
                            <img src={url} alt="Preview" className="max-h-32 object-contain" onError={(e) => (e.currentTarget.style.display = 'none')} />
                        </div>
                    )}

                    <button
                        onClick={handleSave}
                        className="w-full py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg text-xs font-black uppercase tracking-widest transition-all shadow-lg hover:shadow-purple-500/25 active:scale-95 shine-effect"
                    >
                        Salvar Logo
                    </button>
                </div>
            </div>
        </div>
    );
}





function ZoneDetails() {
    const { selectedZoneId, zones, gangName, activeWars, isBoss, gangGrade } = useAppStore();
    const [showShopModal, setShowShopModal] = useState(false);
    const [showRequestModal, setShowRequestModal] = useState(false);

    if (!selectedZoneId) return null;

    const zone = zones[selectedZoneId];
    const isWar = activeWars[selectedZoneId];
    const isMyZone = zone?.owner_gang === gangName;
    const canEdit = isMyZone && !isWar && (isBoss || gangGrade >= 4);

    const handleOpenRequest = () => setShowRequestModal(true);

    const handleEditFlag = () => {
        fetch('https://it-drugs/editGangFlag', {
            method: 'POST',
            body: JSON.stringify({ zoneId: selectedZoneId })
        });
        useAppStore.getState().setOpen(false);
        fetch('https://it-drugs/close', { method: 'POST', body: JSON.stringify({}) });
    };

    return (
        <>
            <div className={cn(
                "absolute top-6 right-6 w-[360px] glass-panel rounded-2xl overflow-hidden animate-in slide-in-from-right duration-500 z-[9999]",
                isWar ? "shadow-[0_0_50px_rgba(220,38,38,0.2)] border-red-500/30" : ""
            )}>
                {/* Header */}
                <div className="glass-header px-5 py-4 flex justify-between items-center bg-[#0a0a0f]/50">
                    <div>
                        <h3 className="text-white font-bold text-lg tracking-wide uppercase text-glow">
                            Zona: {zone.label}
                        </h3>
                        <p className="text-[10px] text-zinc-400 font-mono tracking-widest uppercase mt-0.5">ID: {selectedZoneId}</p>
                    </div>
                    <div className="flex gap-2">
                        {canEdit && (
                            <>
                                <button onClick={() => setShowShopModal(true)} className="p-2 hover:bg-white/10 rounded-lg transition-colors text-purple-400 hover:text-white" title="Loja da Zona">
                                    <ChevronsUp className="w-4 h-4" />
                                </button>
                                <button onClick={handleEditFlag} className="p-2 hover:bg-white/10 rounded-lg transition-colors text-zinc-400 hover:text-white" title="Editar Bandeira">
                                    <Flag className="w-4 h-4" />
                                </button>
                            </>
                        )}
                        <button onClick={() => useAppStore.getState().setSelectedZoneId(null)} className="p-2 hover:bg-white/10 rounded-lg transition-colors text-zinc-400 hover:text-white">
                            <X className="w-4 h-4" />
                        </button>
                    </div>
                </div>

                <div className="p-5 space-y-5">
                    {/* Status Card */}
                    <div className="bg-[#151520]/80 rounded-xl p-4 border border-white/5 space-y-3 shadow-inner">
                        <div className="flex items-center justify-between">
                            <span className="text-[10px] uppercase font-bold text-zinc-500 tracking-widest">Influência</span>
                            <span className="text-xs font-mono text-zinc-400">79% <span className="text-yellow-500 ml-1">TENSO</span></span>
                        </div>
                        <div className="h-1.5 w-full bg-zinc-800 rounded-full overflow-hidden">
                            <div className="h-full bg-gradient-to-r from-yellow-600 to-yellow-400 w-[79%] shadow-[0_0_10px_rgba(234,179,8,0.5)]" />
                        </div>
                    </div>

                    {/* Gang Info */}
                    <div className="space-y-3">
                        <div className="flex items-center justify-between bg-black/40 p-3 rounded-xl border border-white/5">
                            <div className="flex items-center gap-3">
                                <div className={cn("w-2 h-2 rounded-full shadow-[0_0_10px_currentColor]", isMyZone ? "bg-green-500 text-green-500" : "bg-red-500 text-red-500")} />
                                <div>
                                    <p className="text-[10px] uppercase font-bold text-zinc-500 tracking-widest">Controle</p>
                                    <p className="text-sm font-bold text-white uppercase tracking-wider">{zone.owner_gang || "Zona Pública"}</p>
                                </div>
                            </div>
                            {isWar && <Swords className="w-5 h-5 text-red-500 animate-pulse drop-shadow-[0_0_8px_rgba(239,68,68,0.8)]" />}
                        </div>
                    </div>

                    {/* War Actions / Status */}
                    {(!isMyZone && zone.owner_gang && !isWar) || isWar ? (
                        <div className="bg-[#151520]/90 rounded-xl p-4 border border-white/5">
                            {!isMyZone && zone.owner_gang && !isWar && (
                                <button
                                    onClick={handleOpenRequest}
                                    className="w-full py-3 btn-danger rounded-xl text-white font-bold uppercase tracking-widest text-xs shine-effect transform transition active:scale-[0.98]"
                                >
                                    Iniciar Invasão
                                </button>
                            )}
                            {isWar && (
                                <div className="w-full py-3 bg-red-950/30 border border-red-500/30 rounded-xl text-center relative overflow-hidden">
                                    <div className="absolute inset-0 bg-red-500/5 animate-pulse" />
                                    <p className="text-red-500 font-black uppercase text-xs tracking-widest relative z-10">EM GUERRA</p>
                                    <WarTimer endTime={isWar.endTime} className="text-xl font-mono font-bold text-white mt-1 relative z-10 text-glow" />
                                </div>
                            )}
                        </div>
                    ) : null}
                </div>
            </div>

            {showRequestModal && (
                <WarRequestModal
                    zoneId={selectedZoneId}
                    label={zone.label}
                    onClose={() => setShowRequestModal(false)}
                />
            )}

            {showShopModal && (
                <UpgradeShopModal
                    zoneId={selectedZoneId}
                    onClose={() => setShowShopModal(false)}
                />
            )}
        </>
    );
}

function UpgradeShopModal({ zoneId, onClose }: { zoneId: string, onClose: () => void }) {
    const { upgradesConfig, zones } = useAppStore();
    const zone = zones[zoneId];

    // Count existing upgrades
    const getCount = (typeId: string) => {
        if (!zone.upgrades) return 0;
        return (zone.upgrades as any[]).filter((u: any) => u.type_id === typeId).length;
    };

    const handleBuy = (upgradeId: string) => {
        fetch('https://it-drugs/buyUpgrade', {
            method: 'POST',
            body: JSON.stringify({ zoneId, upgradeId })
        });
        // We trigger close to start placement immediately as envisioned in previous tool steps
        useAppStore.getState().setOpen(false);
        fetch('https://it-drugs/close', { method: 'POST', body: JSON.stringify({}) });
    };

    return (
        <div className="fixed inset-0 z-[10000] flex items-center justify-center bg-black/80 backdrop-blur-md p-4 animate-in fade-in duration-300">
            <div className="w-full max-w-2xl glass-panel rounded-2xl overflow-hidden shadow-2xl animate-in zoom-in-95 duration-300 border border-white/10">
                <div className="glass-header px-6 py-5 flex justify-between items-center bg-[#0a0a0f]/50">
                    <div>
                        <h2 className="text-xl font-bold text-white flex items-center gap-3 uppercase tracking-wider text-glow">
                            <Shield className="w-5 h-5 text-purple-500" />
                            Loja da Zona
                        </h2>
                        <p className="text-xs text-zinc-400 font-mono tracking-widest mt-1 uppercase">Melhorias para {zone.label}</p>
                    </div>
                    <button onClick={onClose} className="p-2 hover:bg-white/10 rounded-lg transition-colors text-zinc-400 hover:text-white">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-4 max-h-[60vh] overflow-y-auto">
                    {Object.entries(upgradesConfig || {}).map(([id, data]: [string, any]) => {
                        const count = getCount(id);
                        const isMax = count >= data.max;

                        return (
                            <div key={id} className="glass-panel p-4 rounded-xl flex flex-col gap-3 group hover:border-purple-500/30 transition-all">
                                <div className="flex justify-between items-start">
                                    <div className="p-2 bg-purple-500/10 rounded-lg text-purple-400">
                                        {data.type === 'npc' ? <User className="w-5 h-5" /> : <Inbox className="w-5 h-5" />}
                                    </div>
                                    <span className="px-2 py-1 bg-white/5 rounded text-[10px] font-bold uppercase text-zinc-500 tracking-wider">
                                        {count}/{data.max}
                                    </span>
                                </div>
                                <div>
                                    <h4 className="font-bold text-white uppercase tracking-wide">{data.label}</h4>
                                    <p className="text-xs text-zinc-400 mt-1 line-clamp-2">{data.description}</p>
                                </div>
                                <div className="mt-auto pt-3 border-t border-white/5 flex items-center justify-between">
                                    <span className="font-mono text-green-400 font-bold">${data.price}</span>
                                    <button
                                        onClick={() => handleBuy(id)}
                                        disabled={isMax}
                                        className="px-4 py-2 bg-purple-600 hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg text-xs font-bold uppercase tracking-widest shadow-lg shadow-purple-900/20 transition-all active:scale-95"
                                    >
                                        {isMax ? 'Máximo' : 'Comprar'}
                                    </button>
                                </div>
                            </div>
                        );
                    })}
                </div>
            </div>
        </div>
    );
}

function WarRequestModal({ zoneId, label, onClose }: { zoneId: string, label: string, onClose: () => void }) {
    const [reason, setReason] = useState('');
    const [loading, setLoading] = useState(false);

    const handleSubmit = async () => {
        if (!reason.trim()) return;
        setLoading(true);

        try {
            await fetch('https://it-drugs/requestWar', {
                method: 'POST',
                body: JSON.stringify({ zoneId, reason })
            });
            onClose();
        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="fixed inset-0 z-[10000] flex items-center justify-center bg-black/80 backdrop-blur-md p-4 animate-in fade-in duration-300">
            <div className="w-full max-w-lg glass-panel rounded-2xl overflow-hidden shadow-2xl animate-in zoom-in-95 duration-300 border border-white/10">
                {/* Header */}
                <div className="glass-header px-6 py-5 flex justify-between items-center bg-[#0a0a0f]/50">
                    <div>
                        <h2 className="text-xl font-bold text-white flex items-center gap-3 uppercase tracking-wider text-glow">
                            <Swords className="w-5 h-5 text-red-500 drop-shadow-[0_0_8px_rgba(239,68,68,0.8)]" />
                            Solicitar Invasão
                        </h2>
                        <p className="text-[10px] text-zinc-400 font-mono tracking-widest mt-1 uppercase">Apenas membros online participarão</p>
                    </div>
                    <button onClick={onClose} className="p-2 hover:bg-white/10 rounded-lg transition-colors text-zinc-400 hover:text-white">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <div className="p-8 space-y-6">
                    {/* Zone Target */}
                    <div className="flex gap-4">
                        <div className="w-12 h-12 bg-red-500/10 rounded-xl flex items-center justify-center border border-red-500/20 shadow-[0_0_15px_rgba(239,68,68,0.1)]">
                            <Swords className="w-6 h-6 text-red-500" />
                        </div>
                        <div>
                            <p className="text-xs uppercase text-zinc-500 font-bold tracking-widest">Zona Alvo</p>
                            <h3 className="text-white font-bold text-lg tracking-wide">{label}</h3>
                            <p className="text-xs text-zinc-500 font-mono">{zoneId}</p>
                        </div>
                    </div>

                    {/* Input */}
                    <div className="space-y-2">
                        <label className="text-xs font-bold text-zinc-400 uppercase tracking-widest">Motivo da Guerra</label>
                        <textarea
                            className="w-full bg-black/40 border border-white/10 rounded-xl px-5 py-4 text-white text-sm focus:outline-none focus:border-red-500/50 focus:bg-black/60 transition-all placeholder:text-zinc-700 resize-none h-32"
                            placeholder="Descreva o motivo desta invasão..."
                            value={reason}
                            onChange={(e) => setReason(e.target.value)}
                        />
                        <p className="text-[10px] text-zinc-600 uppercase tracking-wide text-right">Mínimo 10 caracteres</p>
                    </div>

                    {/* Actions */}
                    <div className="flex gap-4 pt-2">
                        <button
                            onClick={onClose}
                            className="flex-1 py-3.5 rounded-xl font-bold text-zinc-400 hover:text-white uppercase tracking-widest text-xs hover:bg-white/5 transition-colors"
                        >
                            Cancelar
                        </button>
                        <button
                            onClick={handleSubmit}
                            disabled={loading || !reason.trim()}
                            className="flex-[2] py-3.5 btn-primary rounded-xl text-white font-bold uppercase tracking-widest text-xs shadow-lg transition-all active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed shine-effect"
                        >
                            {loading ? 'Enviando...' : 'Enviar Solicitação'}
                        </button>
                    </div>
                </div>

                {/* Footer Warning */}
                <div className="bg-red-500/5 border-t border-red-500/10 p-4 text-center">
                    <p className="text-[10px] text-red-400/80 uppercase tracking-widest font-bold flex items-center justify-center gap-2">
                        <Shield className="w-3 h-3" />
                        O uso indevido resultará em punição
                    </p>
                </div>
            </div>
        </div>
    );
}

function NavButton({ active, onClick, icon, label, className }: any) {
    return (
        <button
            onClick={onClick}
            className={cn(
                "w-full flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-all duration-200",
                active
                    ? "bg-purple-500/10 text-purple-400 border border-purple-500/20 shadow-[0_0_15px_rgba(168,85,247,0.1)]"
                    : "text-zinc-400 hover:bg-white/5 hover:text-white hover:pl-5",
                className
            )}
        >
            {icon}
            {label}
        </button>
    )
}

function GameMap() {
    const { zones, gangName, setSelectedZoneId, gangMetadata } = useAppStore();

    useEffect(() => {
        MapModule.initMap();
        return () => {
            MapModule.destroyMap();
        }
    }, []);

    useEffect(() => {
        MapModule.loadMapData(zones, gangName, gangMetadata, (id) => {
            setSelectedZoneId(id);
        });


        // Ensure resize after mount
        const t = setTimeout(() => MapModule.invalidateSize(), 300);
        return () => clearTimeout(t);
    }, [zones, gangName]);

    return <div id="game-map" className="w-full h-full bg-[#1a1a1a]" />;
}

function WarTimer({ endTime, className }: { endTime: number, className?: string }) {
    const [timeLeft, setTimeLeft] = useState('--:--');

    useEffect(() => {
        const update = () => {
            const now = Math.floor(Date.now() / 1000);
            const diff = endTime - now;
            if (diff <= 0) {
                setTimeLeft('00:00');
            } else {
                const m = Math.floor(diff / 60);
                const s = diff % 60;
                setTimeLeft(`${m}:${s < 10 ? '0' : ''}${s}`);
            }
        };
        update();
        const timer = setInterval(update, 1000);
        return () => clearInterval(timer);
    }, [endTime]);

    return <div className={className}>{timeLeft}</div>;
}

function WarsPanel() {
    const { activeWars } = useAppStore();
    const wars = Object.values(activeWars);

    return (
        <div className="p-8 h-full overflow-y-auto w-full">
            <h2 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-zinc-400 mb-8 uppercase tracking-widest drop-shadow-lg">Conflitos Ativos</h2>

            {wars.length === 0 ? (
                <div className="h-[60vh] flex flex-col items-center justify-center text-zinc-600 border border-white/5 rounded-3xl bg-black/20 backdrop-blur-sm">
                    <Swords className="w-20 h-20 mb-6 opacity-20" />
                    <p className="font-light tracking-widest uppercase text-sm">Nenhuma guerra em andamento</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                    {wars.map((war: any) => (
                        <div key={war.zoneId} className="glass-panel rounded-2xl p-6 relative overflow-hidden group hover:border-red-500/30 transition-all duration-500">
                            {/* Background Pulse */}
                            <div className="absolute top-0 right-0 w-32 h-32 bg-red-500/10 rounded-full blur-[50px] -mr-16 -mt-16 pointer-events-none" />

                            <div className="flex justify-between items-center mb-6 relative z-10">
                                <span className="px-3 py-1 bg-red-500/20 text-red-500 text-[10px] font-black uppercase rounded border border-red-500/20 tracking-widest shadow-[0_0_10px_rgba(239,68,68,0.2)]">
                                    Warzone
                                </span>
                                <WarTimer endTime={war.endTime} className="font-mono text-white text-sm font-bold bg-black/40 px-2 py-1 rounded border border-white/5" />
                            </div>

                            <h3 className="text-xl font-bold text-white mb-6 uppercase tracking-wider text-glow truncate">{war.zoneId}</h3>

                            <div className="flex items-center justify-between mb-8 relative z-10">
                                <div className="text-center">
                                    <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest mb-1">Atacante</p>
                                    <p className="font-bold text-red-400 uppercase text-sm">{war.attacker}</p>
                                    <p className="text-3xl font-black text-white mt-1 drop-shadow-[0_0_10px_rgba(239,68,68,0.5)]">{war.score?.attacker || 0}</p>
                                </div>
                                <div className="text-zinc-700 font-black text-2xl italic opacity-50">VS</div>
                                <div className="text-center">
                                    <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest mb-1">Defensor</p>
                                    <p className="font-bold text-blue-400 uppercase text-sm">{war.defender}</p>
                                    <p className="text-3xl font-black text-white mt-1 drop-shadow-[0_0_10px_rgba(59,130,246,0.5)]">{war.score?.defender || 0}</p>
                                </div>
                            </div>

                            <div className="w-full bg-zinc-900/50 h-1.5 rounded-full overflow-hidden border border-white/5">
                                <div className="h-full bg-gradient-to-r from-red-600 to-red-400 w-1/2 animate-pulse shadow-[0_0_10px_rgba(239,68,68,0.5)]" />
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}

function AdminPanel() {
    const [subTab, setSubTab] = useState<'zones' | 'requests'>('zones');

    return (
        <div className="h-full flex flex-col w-full bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-zinc-900/50 via-black to-black">
            <div className="px-10 pt-10 pb-6 flex items-center justify-between border-b border-white/5">
                <div>
                    <h2 className="text-3xl font-black text-white uppercase tracking-tighter flex items-center gap-3 text-glow">
                        <Shield className="w-8 h-8 text-purple-500" />
                        Painel da Alta Cúpula
                    </h2>
                    <p className="text-sm text-zinc-500 font-medium tracking-wide mt-1 pl-11">Gerenciamento administrativo do sistema</p>
                </div>

                <div className="flex bg-black/40 p-1.5 rounded-xl border border-white/10 shadow-inner">
                    <button
                        onClick={() => setSubTab('zones')}
                        className={cn("px-6 py-2 rounded-lg text-xs font-black uppercase tracking-widest transition-all", subTab === 'zones' ? "bg-purple-600 text-white shadow-lg shadow-purple-900/50 scale-105" : "text-zinc-500 hover:text-zinc-300 hover:bg-white/5")}
                    >
                        Mapas & Zonas
                    </button>
                    <button
                        onClick={() => setSubTab('requests')}
                        className={cn("px-6 py-2 rounded-lg text-xs font-black uppercase tracking-widest transition-all", subTab === 'requests' ? "bg-purple-600 text-white shadow-lg shadow-purple-900/50 scale-105" : "text-zinc-500 hover:text-zinc-300 hover:bg-white/5")}
                    >
                        Pedidos de Guerra
                    </button>
                </div>
            </div>

            <div className="flex-1 overflow-hidden p-10">
                <div className="h-full animate-in slide-in-from-bottom-4 duration-500">
                    {subTab === 'zones' ? <ZoneCreatorTab /> : <WarRequestsTab />}
                </div>
            </div>
        </div>
    )
}

function ZoneCreatorTab() {
    const [zoneName, setZoneName] = useState('');
    const [gangId, setGangId] = useState('');
    const [color, setColor] = useState('#2ecc71');
    const [editingZoneId, setEditingZoneId] = useState<string | null>(null);
    const { availableGangs, setOpen } = useAppStore();

    const startCreator = () => {
        if (!zoneName || !gangId) return;
        setOpen(false);
        fetch('https://it-drugs/close', { method: 'POST', body: JSON.stringify({}) });
        fetch('https://it-drugs/startCreator', {
            method: 'POST',
            body: JSON.stringify({ gangId, label: zoneName, color })
        });
    }

    return (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 h-full">
            <div className="glass-panel p-6 rounded-xl space-y-4 h-fit group hover:border-purple-500/20 transition-colors">
                <div className="flex items-center gap-3 mb-2">
                    <div className="p-2 bg-purple-500/20 rounded-lg text-purple-400 box-shadow-[0_0_15px_rgba(168,85,247,0.2)]">
                        <MapIcon className="w-5 h-5" />
                    </div>
                    <div>
                        <h3 className="text-lg font-bold text-white uppercase tracking-wide">Criador de Zonas</h3>
                        <p className="text-xs text-zinc-400">Defina novos territórios visualmente</p>
                    </div>
                </div>

                <div className="space-y-4 pt-4 border-t border-white/5">
                    <div className="space-y-1">
                        <label className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Nome da Zona</label>
                        <input
                            type="text"
                            className="w-full bg-black/40 border border-white/10 rounded-lg px-4 py-3 text-white text-sm focus:outline-none focus:border-purple-500 transition-colors placeholder:text-zinc-700"
                            placeholder="Ex: Grove Street"
                            value={zoneName}
                            onChange={(e) => setZoneName(e.target.value)}
                        />
                    </div>

                    <div className="space-y-1">
                        <label className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Proprietário (Gangue)</label>
                        <select
                            className="w-full bg-black/40 border border-white/10 rounded-lg px-4 py-3 text-white text-sm focus:outline-none focus:border-purple-500 transition-colors appearance-none cursor-pointer"
                            value={gangId}
                            onChange={(e) => {
                                const newGangId = e.target.value;
                                setGangId(newGangId);

                                // Auto-detect color from existing zones
                                const existingZoneWithGang = Object.values(useAppStore.getState().zones).find((z: any) => z.owner_gang === newGangId);
                                if (existingZoneWithGang && existingZoneWithGang.color) {
                                    setColor(existingZoneWithGang.color);
                                }
                            }}
                        >
                            <option value="" disabled>Selecione...</option>
                            {availableGangs.map((g: any) => (
                                <option key={g.id || g.name} value={g.id || g.name}>{g.label || g.name}</option>
                            ))}
                        </select>
                    </div>

                    <div className="space-y-1">
                        <label className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Cor da Gangue no Mapa</label>
                        <div className="flex gap-3 items-center">
                            <input
                                type="color"
                                className="w-12 h-10 bg-black/40 border border-white/10 rounded cursor-pointer"
                                value={color}
                                onChange={(e) => setColor(e.target.value)}
                            />
                            <input
                                type="text"
                                className="flex-1 bg-black/40 border border-white/10 rounded-lg px-4 py-2 text-white text-sm font-mono uppercase focus:outline-none focus:border-purple-500 transition-colors"
                                value={color}
                                onChange={(e) => setColor(e.target.value)}
                            />
                        </div>
                        <p className="text-[10px] text-zinc-500">Se a gangue já tiver uma zona, a cor original será mantida pelo servidor.</p>
                    </div>


                    <button
                        onClick={startCreator}
                        className="w-full py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg text-xs font-black uppercase tracking-widest transition-all shadow-lg hover:shadow-purple-500/25 active:scale-95 shine-effect"
                    >
                        Iniciar Ferramenta
                    </button>
                </div>
            </div>

            <div className="glass-panel p-6 rounded-xl h-fit max-h-full overflow-hidden flex flex-col">
                <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 bg-blue-500/20 rounded-lg text-blue-400">
                        <Shield className="w-5 h-5" />
                    </div>
                    <div>
                        <h3 className="text-lg font-bold text-white uppercase tracking-wide">Gerenciar Zonas</h3>
                        <p className="text-xs text-zinc-400">Editar zonas existentes</p>
                    </div>
                </div>

                <div className="flex-1 overflow-y-auto pr-2 space-y-3">
                    {Object.entries(useAppStore.getState().zones || {}).map(([id, zone]: [string, any]) => (
                        <div key={id} className="bg-black/20 border border-white/5 rounded-lg p-3 flex items-center justify-between group hover:border-white/10 transition-colors hover:bg-white/5">
                            <div>
                                <p className="text-sm font-bold text-white mb-0.5">{zone.label || zone.name || id}</p>
                                <p className="text-[10px] text-zinc-500 uppercase font-mono tracking-wide">{id} • {zone.gang_name || zone.owner_gang || 'N/A'}</p>
                            </div>
                            <div className="flex items-center gap-2">
                                <div
                                    className="w-4 h-4 rounded-full border border-white/10 shadow-sm"
                                    style={{
                                        backgroundColor: (() => {
                                            if (!zone.color) return '#333';
                                            try {
                                                const c = typeof zone.color === 'string' && zone.color.startsWith('{') ? JSON.parse(zone.color) : zone.color;
                                                if (typeof c === 'string') return c;
                                                if (c && c.r !== undefined) return `rgb(${c.r}, ${c.g}, ${c.b})`;
                                                return '#333';
                                            } catch (e) {
                                                if (typeof zone.color === 'string') return zone.color; // Assume raw hex if parse fails
                                                return '#333';
                                            }
                                        })()
                                    }}
                                    title="Cor Atual"
                                />
                                <button
                                    onClick={() => {
                                        setEditingZoneId(id);
                                    }}
                                    className="p-1.5 bg-white/5 hover:bg-white/10 rounded-md text-zinc-400 hover:text-white transition-colors"
                                >
                                    <Settings className="w-3 h-3" />
                                </button>
                                <button
                                    onClick={() => {
                                        // Trigger Visual Editor for existing zone
                                        // We need points to draw the ghost polygon
                                        const z = useAppStore.getState().zones[id];
                                        if (z) {
                                            useAppStore.getState().setVisualEditorOpen(true, 'edit', {
                                                zoneId: id,
                                                polyPoints: z.polygon_points,
                                                visualZone: z.visual_zone, // Server should send this
                                                color: z.color
                                            });
                                        }
                                    }}
                                    className="p-1.5 bg-white/5 hover:bg-white/10 rounded-md text-zinc-400 hover:text-white transition-colors"
                                    title="Editar Visual (Admin)"
                                >
                                    <MapIcon className="w-3 h-3" />
                                </button>
                            </div>
                        </div>
                    ))}
                    {Object.keys(useAppStore.getState().zones || {}).length === 0 && (
                        <p className="text-center text-zinc-600 text-xs py-10">Nenhuma zona carregada.</p>
                    )}
                </div>

                {editingZoneId && (
                    <ColorPickerModal
                        onClose={() => setEditingZoneId(null)}
                        initialColor={(() => {
                            const z = useAppStore.getState().zones[editingZoneId];
                            if (z && z.color) {
                                try {
                                    return typeof z.color === 'string' && z.color.startsWith('{') ? JSON.parse(z.color) : z.color;
                                } catch (e) {
                                    return z.color;
                                }
                            }
                            return null;
                        })()}
                        onSave={(color) => {
                            fetch('https://it-drugs/updateZoneColor', {
                                method: 'POST',
                                body: JSON.stringify({ zoneId: editingZoneId, color: color })
                            });
                            setEditingZoneId(null);
                        }}
                    />
                )}
            </div>
        </div>
    )
}

function WarRequestsTab() {
    const { warRequests } = useAppStore();
    const [resolvingId, setResolvingId] = useState<number | null>(null);
    const [scheduleTime, setScheduleTime] = useState('');
    const [rejectionReason, setRejectionReason] = useState('');

    const handleApprove = (id: number) => {
        if (!scheduleTime) return;
        fetch('https://it-drugs/resolveWarRequest', {
            method: 'POST',
            body: JSON.stringify({ id, action: 'approve', time: scheduleTime })
        });
        setResolvingId(null);
    };

    const handleReject = (id: number) => {
        if (!rejectionReason) return;
        fetch('https://it-drugs/resolveWarRequest', {
            method: 'POST',
            body: JSON.stringify({ id, action: 'reject', reason: rejectionReason })
        });
        setResolvingId(null);
    };

    return (
        <div className="h-full overflow-y-auto pr-2 space-y-4">
            {warRequests.length === 0 ? (
                <div className="py-20 flex flex-col items-center justify-center text-zinc-600 border-2 border-dashed border-white/5 rounded-2xl bg-black/20">
                    <Inbox className="w-12 h-12 mb-4 opacity-30" />
                    <p>Nenhuma solicitação pendente.</p>
                </div>
            ) : (
                warRequests.filter((r: any) => r.status === 'requested').map((req: any) => (
                    <div key={req.id} className="bg-zinc-900/80 border border-white/5 rounded-xl overflow-hidden shadow-lg animate-in slide-in-from-bottom duration-300">
                        <div className="p-6">
                            <div className="flex justify-between items-start mb-4">
                                <div>
                                    <div className="flex items-center gap-2 mb-1">
                                        <span className="text-red-400 font-bold uppercase text-sm tracking-tighter">{req.attacker_gang}</span>
                                        <span className="text-zinc-600 text-xs">VS</span>
                                        <span className="text-blue-400 font-bold uppercase text-sm tracking-tighter">{req.defender_gang}</span>
                                    </div>
                                    <h3 className="text-xl font-bold text-white">{req.zone_id}</h3>
                                </div>
                                <div className="text-right">
                                    <p className="text-xs text-zinc-500 uppercase font-bold">Solicitado por</p>
                                    <p className="text-sm text-zinc-300">ID {req.requested_by}</p>
                                </div>
                            </div>

                            <div className="bg-black/40 p-4 rounded-lg border border-white/5 mb-6">
                                <p className="text-xs uppercase text-zinc-600 font-bold mb-1 italic">Motivo declarado:</p>
                                <p className="text-zinc-300 text-sm leading-relaxed">"{req.reason}"</p>
                            </div>

                            <div className="flex gap-4">
                                <button
                                    onClick={() => setResolvingId(req.id)}
                                    className="px-6 py-2 bg-green-600 hover:bg-green-700 text-white text-xs font-bold uppercase tracking-wider rounded-lg transition-all active:scale-95"
                                >
                                    Aprovar
                                </button>
                                <button
                                    onClick={() => setResolvingId(req.id)}
                                    className="px-6 py-2 bg-red-600/10 hover:bg-red-600/20 text-red-500 text-xs font-bold uppercase tracking-wider rounded-lg transition-all active:scale-95"
                                >
                                    Reprovar
                                </button>
                            </div>
                        </div>

                        {resolvingId === req.id && (
                            <div className="p-6 bg-purple-500/5 border-t border-purple-500/20 space-y-4 animate-in slide-in-from-top">
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                    <div className="space-y-4">
                                        <label className="text-[10px] font-black text-purple-400 uppercase tracking-widest">Agendar Conflito</label>
                                        <CustomDateTimePicker
                                            value={scheduleTime}
                                            onChange={(val) => setScheduleTime(val)}
                                        />
                                        <button
                                            onClick={() => handleApprove(req.id)}
                                            disabled={!scheduleTime}
                                            className="w-full py-3 bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg text-xs font-black uppercase tracking-widest shadow-lg shadow-green-900/20 transition-all active:scale-95"
                                        >
                                            Confirmar Aprovação
                                        </button>
                                    </div>
                                    <div className="space-y-4">
                                        <label className="text-[10px] font-black text-red-400 uppercase tracking-widest">Motivo da Recusa</label>
                                        <textarea
                                            className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-white text-sm focus:outline-none focus:border-red-600 h-[180px] resize-none transition-colors placeholder:text-zinc-700"
                                            placeholder="Descreva o motivo para a recusa desta solicitação..."
                                            onChange={(e) => setRejectionReason(e.target.value)}
                                        />
                                        <button
                                            onClick={() => handleReject(req.id)}
                                            disabled={!rejectionReason.trim()}
                                            className="w-full py-3 bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg text-xs font-black uppercase tracking-widest shadow-lg shadow-red-900/20 transition-all active:scale-95"
                                        >
                                            Confirmar Recusa
                                        </button>
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>
                ))
            )}
        </div>
    );
}

function CustomDateTimePicker({ value, onChange }: { value: string, onChange: (val: string) => void }) {
    const [viewDate, setViewDate] = useState(new Date());
    const [selectedDate, setSelectedDate] = useState<Date | null>(value ? new Date(value.replace(' ', 'T')) : null);
    const [hours, setHours] = useState(selectedDate ? selectedDate.getHours() : 12);
    const [minutes, setMinutes] = useState(selectedDate ? selectedDate.getMinutes() : 0);

    const daysInMonth = (year: number, month: number) => new Date(year, month + 1, 0).getDate();
    const firstDayOfMonth = (year: number, month: number) => new Date(year, month, 1).getDay();

    const monthNames = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
    const weekDays = ["D", "S", "T", "Q", "Q", "S", "S"];

    const handlePrevMonth = () => setViewDate(new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1));
    const handleNextMonth = () => setViewDate(new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1));

    const updateDateTime = (date: Date, h: number, m: number) => {
        const newDate = new Date(date);
        newDate.setHours(h);
        newDate.setMinutes(m);
        newDate.setSeconds(0);

        setSelectedDate(newDate);

        const pad = (n: number) => n.toString().padStart(2, '0');
        const formatted = `${newDate.getFullYear()}-${pad(newDate.getMonth() + 1)}-${pad(newDate.getDate())} ${pad(newDate.getHours())}:${pad(newDate.getMinutes())}:00`;
        onChange(formatted);
    };

    const handleSelectDay = (day: number) => {
        const baseDate = new Date(viewDate.getFullYear(), viewDate.getMonth(), day);
        updateDateTime(baseDate, hours, minutes);
    };

    const handleHourChange = (newHour: number) => {
        setHours(newHour);
        if (selectedDate) updateDateTime(selectedDate, newHour, minutes);
    };

    const handleMinuteChange = (newMinute: number) => {
        setMinutes(newMinute);
        if (selectedDate) updateDateTime(selectedDate, hours, newMinute);
    };

    const days = [];
    const totalDays = daysInMonth(viewDate.getFullYear(), viewDate.getMonth());
    const startDay = firstDayOfMonth(viewDate.getFullYear(), viewDate.getMonth());

    for (let i = 0; i < startDay; i++) days.push(<div key={`empty-${i}`} />);
    for (let d = 1; d <= totalDays; d++) {
        const isSelected = selectedDate?.getDate() === d &&
            selectedDate?.getMonth() === viewDate.getMonth() &&
            selectedDate?.getFullYear() === viewDate.getFullYear();
        const isToday = new Date().getDate() === d &&
            new Date().getMonth() === viewDate.getMonth() &&
            new Date().getFullYear() === viewDate.getFullYear();

        days.push(
            <button
                key={d}
                onClick={() => handleSelectDay(d)}
                className={cn(
                    "w-8 h-8 rounded-lg flex items-center justify-center text-xs font-bold transition-all",
                    isSelected ? "bg-purple-600 text-white shadow-lg shadow-purple-900/40" :
                        isToday ? "border border-purple-500/50 text-purple-400" : "text-zinc-400 hover:bg-white/5 hover:text-white"
                )}
            >
                {d}
            </button>
        );
    }

    return (
        <div className="bg-black/60 border border-white/10 rounded-xl p-4 space-y-4">
            <div className="flex justify-between items-center mb-2">
                <button onClick={handlePrevMonth} className="p-1 hover:bg-white/5 rounded text-zinc-500 hover:text-purple-400"><X className="w-4 h-4 rotate-90" /></button>
                <span className="text-xs font-bold text-white uppercase tracking-wider">{monthNames[viewDate.getMonth()]} {viewDate.getFullYear()}</span>
                <button onClick={handleNextMonth} className="p-1 hover:bg-white/5 rounded text-zinc-500 hover:text-purple-400"><X className="w-4 h-4 -rotate-90" /></button>
            </div>

            <div className="grid grid-cols-7 gap-1 text-center mb-4">
                {weekDays.map(d => <div key={d} className="text-[10px] text-zinc-600 font-black">{d}</div>)}
                {days}
            </div>

            <div className="pt-4 border-t border-white/5 flex items-center justify-center gap-4">
                <div className="flex flex-col items-center">
                    <button onClick={() => handleHourChange((hours + 1) % 24)} className="text-zinc-600 hover:text-purple-400 px-2">▲</button>
                    <div className="bg-zinc-900 border border-white/5 px-3 py-1 rounded text-lg font-mono text-white min-w-[45px] text-center">{hours.toString().padStart(2, '0')}</div>
                    <button onClick={() => handleHourChange((hours - 1 + 24) % 24)} className="text-zinc-600 hover:text-purple-400 px-2">▼</button>
                </div>
                <span className="text-white font-bold text-xl mb-1">:</span>
                <div className="flex flex-col items-center">
                    <button onClick={() => handleMinuteChange((minutes + 1) % 60)} className="text-zinc-600 hover:text-purple-400 px-2">▲</button>
                    <div className="bg-zinc-900 border border-white/5 px-3 py-1 rounded text-lg font-mono text-white min-w-[45px] text-center">{minutes.toString().padStart(2, '0')}</div>
                    <button onClick={() => handleMinuteChange((minutes - 1 + 60) % 60)} className="text-zinc-600 hover:text-purple-400 px-2">▼</button>
                </div>
            </div>
            {selectedDate && (
                <div className="text-center text-[10px] text-purple-400 font-bold uppercase tracking-widest pt-2">
                    {selectedDate.toLocaleDateString('pt-BR')} às {hours.toString().padStart(2, '0')}:{minutes.toString().padStart(2, '0')}
                </div>
            )}
        </div>
    );
}

function ColorPickerModal({ onClose, onSave, initialColor }: { onClose: () => void, onSave: (color: string) => void, initialColor?: string | { r: number, g: number, b: number } | null }) {
    // Helper to convert to hex if needed
    const toHex = (c: any) => {
        if (!c) return '#000000';
        if (typeof c === 'string') return c;
        if (c.r !== undefined) {
            const toHexC = (n: number) => n.toString(16).padStart(2, '0');
            return `#${toHexC(c.r)}${toHexC(c.g)}${toHexC(c.b)}`;
        }
        return '#000000';
    };

    const [color, setColor] = useState(toHex(initialColor));

    const handleSave = () => {
        onSave(color);
        onClose();
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
            <div className="bg-zinc-900 border border-white/10 rounded-xl p-6 w-full max-w-sm shadow-2xl space-y-6 animate-in fade-in zoom-in duration-200">
                <div className="flex justify-between items-center">
                    <h3 className="text-xl font-bold text-white">Editar Cor</h3>
                    <button onClick={onClose} className="p-1 hover:bg-white/10 rounded-lg transition-colors"><X className="w-5 h-5 text-zinc-400" /></button>
                </div>

                <div className="space-y-4">
                    <div className="flex justify-center py-4">
                        <div
                            className="w-24 h-24 rounded-full shadow-inner border-4 border-white/5 transition-all duration-300"
                            style={{ backgroundColor: color, boxShadow: `0 0 20px ${color}40` }}
                        />
                    </div>

                    <div className="space-y-1">
                        <label className="text-xs font-medium text-zinc-400 uppercase">Selecione a Cor</label>
                        <div className="flex gap-3 items-center">
                            <input
                                type="color"
                                className="w-12 h-10 bg-black/40 border border-white/10 rounded cursor-pointer"
                                value={color}
                                onChange={(e) => setColor(e.target.value)}
                            />
                            <input
                                type="text"
                                className="flex-1 bg-black/40 border border-white/10 rounded-lg px-4 py-2 text-white text-sm font-mono uppercase focus:outline-none focus:border-purple-500 transition-colors"
                                value={color}
                                onChange={(e) => setColor(e.target.value)}
                            />
                        </div>
                    </div>
                </div>

                <div className="flex gap-3 pt-2">
                    <button onClick={onClose} className="flex-1 py-2.5 rounded-lg font-bold text-zinc-400 hover:text-white hover:bg-white/5 transition-colors">Cancelar</button>
                    <button onClick={handleSave} className="flex-1 py-2.5 rounded-lg font-bold text-black bg-white hover:bg-zinc-200 transition-colors shadow-lg">Salvar Cor</button>
                </div>
            </div>
        </div>
    );
}


function VisualEditor() {
    const { pendingZoneData, visualEditorMode, editingZoneId, setVisualEditorOpen } = useAppStore();
    const [scale, setScale] = useState(1.0);
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        // Initialize Map in Editor Mode
        MapModule.initMap();

        const initData = pendingZoneData || {};

        // If editing, use existing visual data if available
        const existingVisual = visualEditorMode === 'edit' && initData.visualZone ? initData.visualZone : null;

        // Reset scale
        setScale(1.0);

        setTimeout(() => {
            MapModule.invalidateSize();
            MapModule.enableVisualEditor(initData, existingVisual);
        }, 100);

        return () => {
            // Cleanup done by MapModule.destroy or re-init
        }
    }, [pendingZoneData, visualEditorMode]);

    const handleScaleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const s = parseFloat(e.target.value);
        setScale(s);
        MapModule.updateEditorScale(s);
    };

    const handleSave = async () => {
        setSaving(true);
        const visualData = MapModule.getEditorData(); // { x, y, radius }

        if (visualEditorMode === 'create') {
            // Finalize Creation
            await fetch('https://it-drugs/saveGangZoneFinal', {
                method: 'POST',
                body: JSON.stringify({
                    ...pendingZoneData,
                    visualZone: visualData
                })
            });
            setVisualEditorOpen(false); // Close editor
            fetch('https://it-drugs/close', { method: 'POST', body: JSON.stringify({}) }); // Close NUI

        } else if (visualEditorMode === 'edit' && editingZoneId) {
            // Update Existing
            await fetch('https://it-drugs/saveVisualZone', {
                method: 'POST',
                body: JSON.stringify({
                    zoneId: editingZoneId,
                    visualZone: visualData
                })
            });
            setVisualEditorOpen(false); // Return to normal UI? Or close?
            // Usually we want to go back to Admin Panel, but simple close is safer for now
        }

        setSaving(false);
    };

    const handleCancel = () => {
        setVisualEditorOpen(false);
        if (visualEditorMode === 'create') {
            fetch('https://it-drugs/close', { method: 'POST', body: JSON.stringify({}) });
        }
    };

    return (
        <div className="flex items-center justify-center w-screen h-screen bg-black/80">
            <div className="w-[90vw] h-[85vh] bg-[#09090b]/95 border border-white/10 rounded-xl shadow-2xl flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-300 relative">

                {/* Map Container */}
                <div id="game-map" className="absolute inset-0 z-0 bg-[#1a1a1a]" />

                {/* Controls Overlay */}
                <div className="absolute bottom-10 left-1/2 -translate-x-1/2 bg-black/80 backdrop-blur-md p-6 rounded-2xl border border-white/10 shadow-2xl min-w-[400px] z-10 flex flex-col gap-4">
                    <div className="flex items-center justify-between">
                        <h3 className="text-white font-bold uppercase tracking-wider flex items-center gap-2">
                            <MapIcon className="w-5 h-5 text-purple-500" />
                            Editor Visual
                        </h3>
                        <span className="text-xs text-zinc-400 bg-white/5 px-2 py-1 rounded">
                            {visualEditorMode === 'create' ? 'NOVA ZONA' : 'EDITANDO ZONA'}
                        </span>
                    </div>

                    <p className="text-xs text-zinc-400">Arraste o marcador central para mover. Use o slider para ajustar o tamanho.</p>

                    <div className="space-y-2">
                        <div className="flex justify-between text-xs font-bold text-zinc-500 uppercase">
                            <span>Escala</span>
                            <span>{scale.toFixed(1)}x</span>
                        </div>
                        <input
                            type="range"
                            min="0.5"
                            max="2.0"
                            step="0.1"
                            value={scale}
                            onChange={handleScaleChange}
                            className="w-full accent-purple-500 h-2 bg-white/10 rounded-lg appearance-none cursor-pointer"
                        />
                    </div>

                    <div className="flex gap-3 pt-2">
                        <button
                            onClick={handleCancel}
                            className="flex-1 py-3 rounded-lg font-bold text-zinc-400 hover:text-white uppercase tracking-widest text-xs hover:bg-white/5 transition-colors"
                        >
                            Cancelar
                        </button>
                        <button
                            onClick={handleSave}
                            disabled={saving}
                            className="flex-[2] py-3 btn-primary rounded-lg text-white font-bold uppercase tracking-widest text-xs shadow-lg transition-all active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed shine-effect bg-purple-600 hover:bg-purple-700"
                        >
                            {saving ? 'Salvando...' : 'Confirmar Visual'}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
