import { Swords, Shield, Skull } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import { useEffect, useState } from 'react';

function cn(...classes: (string | undefined | null | false)[]) {
    return classes.filter(Boolean).join(' ');
}

export function CaptureProgress() {
    const { captureState } = useAppStore();

    if (!captureState || !captureState.active) return null;

    const percent = Math.abs(captureState.progress);
    const isContested = captureState.status === 'CONTESTED';

    const isAttackerWinning = captureState.progress > 0;
    const barColor = isAttackerWinning ? 'bg-purple-500' : 'bg-blue-500';

    return (
        <div className="fixed top-12 left-1/2 -translate-x-1/2 z-[50] animate-in slide-in-from-top duration-500">
            <div className={cn(
                "glass-panel rounded-xl overflow-hidden w-[420px] transition-all duration-300 relative",
                isContested ? "border-red-500/50 shadow-[0_0_30px_rgba(220,38,38,0.2)]" : "hover:border-white/20"
            )}>
                {/* Decorative Top Line */}
                <div className={cn("h-1 w-full", isContested ? "bg-red-500" : "bg-gradient-to-r from-blue-500 via-transparent to-purple-500")} />

                {/* Header / Status */}
                <div className="px-6 py-4 flex justify-between items-center bg-black/20">
                    <div className="flex items-center gap-4">
                        <div className={cn(
                            "p-2.5 rounded-lg border",
                            isContested ? "bg-red-500/10 border-red-500/20 text-red-500 animate-pulse" : "bg-white/5 border-white/5 text-zinc-400"
                        )}>
                            {isContested ? <Swords className="w-5 h-5" /> : <Shield className="w-5 h-5" />}
                        </div>
                        <div>
                            <p className="text-[10px] text-zinc-500 font-black uppercase tracking-widest leading-none mb-1.5">Status do Conflito</p>
                            <h3 className={cn("text-lg font-black uppercase tracking-tight leading-none drop-shadow-md", isContested ? "text-red-500" : "text-white")}>
                                {isContested ? "Em Disputa" : captureState.status === 'CAPTURING' ? "Dominação em Progresso" : "Recuperação de Território"}
                            </h3>
                        </div>
                    </div>
                </div>

                {/* Progress Bar Container */}
                <div className="px-6 pb-2">
                    <div className="h-4 bg-zinc-900/50 rounded-full overflow-hidden relative border border-white/5 shadow-inner">
                        {/* Background Center Marker */}
                        <div className="absolute left-1/2 top-0 bottom-0 w-0.5 bg-white/20 z-10" />

                        {/* The Bar */}
                        <div
                            className={cn("h-full transition-all duration-1000 ease-out relative", barColor, "shadow-[0_0_15px_currentColor]")}
                            style={{ width: `${percent}%` }}
                        >
                            <div className="absolute inset-0 bg-white/20 animate-pulse" />
                        </div>
                    </div>
                    <div className="flex justify-between mt-1.5 px-1">
                        <span className="text-[10px] font-mono text-zinc-500">DEFENSOR</span>
                        <span className="text-[10px] font-mono text-white font-bold">{Math.floor(percent)}%</span>
                        <span className="text-[10px] font-mono text-zinc-500">ATACANTE</span>
                    </div>
                </div>

                {/* Info Footer */}
                <div className="px-6 py-4 bg-black/40 flex justify-between items-center text-xs border-t border-white/5">
                    <div className="flex items-center gap-3">
                        <span className="w-2.5 h-2.5 rounded-sm bg-purple-500 shadow-[0_0_10px_rgba(168,85,247,0.5)] rotate-45"></span>
                        <div className="flex flex-col">
                            <span className="text-zinc-300 font-bold uppercase tracking-wide">{captureState.attacker}</span>
                            <span className="text-[10px] text-zinc-500 font-mono flex items-center gap-1.5 opacity-80">
                                <span className="text-green-400 font-bold bg-green-400/10 px-1 rounded">{captureState.attackerCount || 0}</span> Operadores
                            </span>
                        </div>
                    </div>

                    <span className="text-zinc-700 font-black italic text-lg opacity-30">VS</span>

                    <div className="flex items-center gap-3 text-right">
                        <div className="flex flex-col items-end">
                            <span className="text-zinc-300 font-bold uppercase tracking-wide">{captureState.defender}</span>
                            <span className="text-[10px] text-zinc-500 font-mono flex items-center gap-1.5 justify-end opacity-80">
                                <span className="text-green-400 font-bold bg-green-400/10 px-1 rounded">{captureState.defenderCount || 0}</span> Operadores
                            </span>
                        </div>
                        <span className="w-2.5 h-2.5 rounded-sm bg-blue-500 shadow-[0_0_10px_rgba(59,130,246,0.5)] rotate-45"></span>
                    </div>
                </div>
            </div>
        </div>
    );
}
