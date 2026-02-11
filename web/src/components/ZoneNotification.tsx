import React, { useEffect, useState } from 'react';
import { Shield } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';

const ZoneNotification: React.FC = () => {
    const { zoneNotification } = useAppStore();
    const [visible, setVisible] = useState(false);
    const [progress, setProgress] = useState(100);

    // Determine colors based on status and type
    const getColors = () => {
        if (zoneNotification.type === 'exit') {
            return {
                border: 'border-red-500',
                bgIcon: 'bg-red-500/20',
                textIcon: 'text-red-500',
                ring: 'ring-red-500/50',
                bar: 'bg-red-500',
                shadow: 'shadow-[0_0_10px_rgba(239,68,68,0.8)]'
            };
        }

        if (zoneNotification.status === 'hostile') {
            return {
                border: 'border-red-600',
                bgIcon: 'bg-red-600/20',
                textIcon: 'text-red-600',
                ring: 'ring-red-600/50',
                bar: 'bg-red-600',
                shadow: 'shadow-[0_0_10px_rgba(220,38,38,0.8)]'
            };
        }

        // Friendly or Neutral (Green)
        return {
            border: 'border-green-500',
            bgIcon: 'bg-green-500/20',
            textIcon: 'text-green-500',
            ring: 'ring-green-500/50',
            bar: 'bg-green-500',
            shadow: 'shadow-[0_0_10px_rgba(34,197,94,0.8)]'
        };
    };

    const colors = getColors();

    useEffect(() => {
        if (zoneNotification.show) {
            setVisible(true);
            setProgress(100);

            // Timer: 15s for Entry, 5s for Exit
            const duration = zoneNotification.type === 'exit' ? 5000 : 15000;
            const steps = duration / 100; // 100ms interval

            const hideTimer = setTimeout(() => {
                setVisible(false);
            }, duration);

            const interval = setInterval(() => {
                setProgress((prev) => Math.max(0, prev - (100 / steps)));
            }, 100);

            return () => {
                clearTimeout(hideTimer);
                clearInterval(interval);
            };
        } else {
            setVisible(false);
        }
    }, [zoneNotification]);

    return (
        <div className={`fixed top-10 left-1/2 transform -translate-x-1/2 z-50 pointer-events-none transition-all duration-500 ease-out ${visible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-10'}`}>
            <div className={`bg-black/90 border-l-4 ${colors.border} rounded-r shadow-2xl backdrop-blur-md p-4 min-w-[320px] relative overflow-hidden transition-colors duration-300`}>
                <div className="flex items-center gap-4 relative z-10">
                    <div className={`${colors.bgIcon} p-2 rounded-full ring-1 ${colors.ring} transition-colors duration-300`}>
                        <Shield className={`w-8 h-8 ${colors.textIcon} transition-colors duration-300`} />
                    </div>
                    <div>
                        <h2 className="text-white text-lg font-bold tracking-wider uppercase drop-shadow-md">
                            {zoneNotification.type === 'exit' ? 'Você saiu de' : 'Você entrou em'}
                        </h2>
                        <h3 className="text-white text-xl font-black tracking-widest uppercase leading-none">
                            {zoneNotification.zoneName || 'Zona Desconhecida'}
                        </h3>
                        {zoneNotification.type === 'enter' && (
                            <div className="flex items-center gap-2 mt-1">
                                <span className="text-gray-400 text-xs uppercase font-medium tracking-wide">Domínio:</span>
                                <span className={`text-sm font-bold uppercase ${zoneNotification.gangOwner === 'Ninguém' ? 'text-gray-500' : (zoneNotification.status === 'hostile' ? 'text-red-500' : 'text-green-500')}`}>
                                    {zoneNotification.gangOwner || 'Ninguém'}
                                </span>
                            </div>
                        )}
                    </div>
                </div>

                {/* Progress Bar */}
                <div className="absolute bottom-0 left-0 h-1 w-full bg-transparent">
                    <div
                        className={`h-full ${colors.bar} ${colors.shadow} transition-all duration-100 ease-linear`}
                        style={{ width: `${progress}%` }}
                    />
                </div>
            </div>
        </div>
    );
};

export default ZoneNotification;
