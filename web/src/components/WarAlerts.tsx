
import { useEffect } from 'react';
import { useAppStore } from '../store/useAppStore';
import { AlertTriangle, Info, Octagon } from 'lucide-react';

// If cn is not exported from utils, I will define it locally or import it from App.tsx if possible? No, best to have it or redefine.
// I'll redefine simple cn helper here to be safe and self-contained if needed, or check if I can import.
// In App.tsx it was defined locally. I'll define it locally here too for safety.

function cn(...classes: (string | undefined | null | false)[]) {
    return classes.filter(Boolean).join(' ');
}

export function WarAlerts() {
    const { warAlert } = useAppStore();

    if (!warAlert) return null;

    const isCritical = warAlert.type === 'error'; // Error = Critical Exclusion Warning
    const isWarning = warAlert.type === 'warning'; // Warning = Entry Timer

    return (
        <div className="fixed bottom-24 left-1/2 -translate-x-1/2 z-[10000] animate-in slide-in-from-bottom-10 fade-in duration-300">
            <div className={cn(
                "relative flex items-center gap-4 px-8 py-4 rounded-2xl overflow-hidden shadow-2xl backdrop-blur-xl border transition-all duration-300 min-w-[400px] justify-center",
                isCritical ? "bg-red-950/80 border-red-500/50 shadow-[0_0_50px_rgba(220,38,38,0.4)]" :
                    isWarning ? "bg-orange-950/80 border-orange-500/50 shadow-[0_0_50px_rgba(249,115,22,0.4)]" :
                        "bg-zinc-900/80 border-white/10"
            )}>

                {/* Background Pulse Animation for Critical */}
                {isCritical && (
                    <div className="absolute inset-0 bg-red-500/10 animate-pulse pointer-events-none" />
                )}

                {/* Icon */}
                <div className={cn(
                    "p-3 rounded-xl border z-10",
                    isCritical ? "bg-red-500/20 border-red-500/30 text-red-500 animate-bounce" :
                        isWarning ? "bg-orange-500/20 border-orange-500/30 text-orange-500" :
                            "bg-zinc-800 border-white/10 text-zinc-400"
                )}>
                    {isCritical ? <Octagon className="w-8 h-8" /> :
                        isWarning ? <AlertTriangle className="w-8 h-8" /> :
                            <Info className="w-8 h-8" />}
                </div>

                {/* Text Content */}
                <div className="flex flex-col items-center z-10 text-center">
                    <h3 className={cn(
                        "text-2xl font-black uppercase tracking-widest drop-shadow-lg",
                        isCritical ? "text-red-500" : isWarning ? "text-orange-500" : "text-white"
                    )}>
                        {warAlert.message}
                    </h3>
                    {warAlert.subMessage && (
                        <p className="text-zinc-300 font-bold uppercase tracking-wide text-xs mt-1">
                            {warAlert.subMessage}
                        </p>
                    )}
                </div>

                {/* Progress/Timer Bar if needed (Optional upgrade) */}
                {/* For now simple visual is enough */}
            </div>
        </div>
    );
}
