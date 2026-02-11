import { useEffect, useState } from 'react';
import { Trophy, Shield } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';

// Simple helper to join classes if needed, or use the one from utils if available
function cn(...classes: (string | undefined | null | false)[]) {
    return classes.filter(Boolean).join(' ');
}

interface RankingItem {
    name: string;
    label: string;
    count: number;
    logo?: string;
}

export function RankingPanel() {
    const [ranking, setRanking] = useState<RankingItem[]>([]);
    const { receiveNuiMessage } = useAppStore();

    useEffect(() => {
        // Request ranking data when component mounts
        // Using standard fetch format for NUI callback defined in cl_ranking.lua
        fetch('https://it-drugs/requestRanking', {
            method: 'POST',
            body: JSON.stringify({})
        });

        // Event listener for receiving data
        const handleMessage = (event: MessageEvent) => {
            if (event.data.action === 'updateRanking') {
                setRanking(event.data.ranking || []);
            }
        };

        window.addEventListener('message', handleMessage);
        return () => window.removeEventListener('message', handleMessage);
    }, []);

    return (
        <div className="p-8 h-full overflow-y-auto w-full bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-zinc-900/50 via-black to-black">
            <h2 className="text-3xl font-black bg-clip-text text-transparent bg-gradient-to-r from-yellow-400 to-yellow-600 mb-2 uppercase tracking-tighter drop-shadow-lg flex items-center gap-3">
                <Trophy className="w-8 h-8 text-yellow-500" />
                Ranking de Dominação
            </h2>
            <p className="text-sm text-zinc-500 font-medium tracking-wide mb-8">As gangues mais poderosas da cidade</p>

            <div className="grid gap-4 max-w-4xl">
                {ranking.length === 0 ? (
                    <div className="h-40 flex flex-col items-center justify-center text-zinc-600 border border-white/5 rounded-2xl bg-black/20 backdrop-blur-sm">
                        <Trophy className="w-10 h-10 mb-4 opacity-20" />
                        <p className="font-light tracking-widest uppercase text-xs">Sem dados de ranking</p>
                    </div>
                ) : (
                    ranking.map((gang, index) => (
                        <div
                            key={gang.name}
                            className={cn(
                                "flex items-center gap-6 p-6 rounded-2xl border transition-all duration-300 group",
                                index === 0 ? "bg-gradient-to-r from-yellow-500/10 to-transparent border-yellow-500/30 shadow-[0_0_30px_rgba(234,179,8,0.1)]" :
                                    index === 1 ? "bg-gradient-to-r from-zinc-400/10 to-transparent border-zinc-400/30" :
                                        index === 2 ? "bg-gradient-to-r from-orange-700/10 to-transparent border-orange-700/30" :
                                            "bg-black/40 border-white/5 hover:border-white/10"
                            )}
                        >
                            <div className={cn(
                                "text-4xl font-black italic tracking-tighter w-16 text-center",
                                index === 0 ? "text-yellow-500 drop-shadow-[0_0_10px_rgba(234,179,8,0.5)]" :
                                    index === 1 ? "text-zinc-400" :
                                        index === 2 ? "text-orange-700" :
                                            "text-zinc-700"
                            )}>
                                #{index + 1}
                            </div>

                            <div className="w-16 h-16 rounded-xl bg-black/50 border border-white/10 overflow-hidden flex items-center justify-center relative">
                                {gang.logo ? (
                                    <img src={gang.logo} alt={gang.label} className="w-full h-full object-cover" />
                                ) : (
                                    <Shield className="w-8 h-8 text-zinc-700" />
                                )}
                                {index === 0 && <div className="absolute inset-0 bg-yellow-500/20 animate-pulse" />}
                            </div>

                            <div className="flex-1">
                                <h3 className={cn(
                                    "text-xl font-black uppercase tracking-wider",
                                    index === 0 ? "text-yellow-100" : "text-white"
                                )}>
                                    {gang.label || gang.name}
                                </h3>
                                <p className="text-xs text-zinc-500 font-mono mt-1">
                                    {gang.name}
                                </p>
                            </div>

                            <div className="text-right">
                                <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest mb-1">Territórios</p>
                                <p className={cn(
                                    "text-3xl font-black",
                                    index === 0 ? "text-yellow-500" : "text-white"
                                )}>
                                    {gang.count}
                                </p>
                            </div>
                        </div>
                    ))
                )}
            </div>
        </div>
    );
}
