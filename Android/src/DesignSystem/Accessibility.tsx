import React, { createContext, useContext, useEffect, useState } from 'react';
import { AccessibilityInfo } from 'react-native';

interface AccessibilityPreferences {
  reduceMotion: boolean;
  reduceTransparency: boolean;
}

const AccessibilityContext = createContext<AccessibilityPreferences>({
  reduceMotion: false,
  reduceTransparency: false,
});

export function AccessibilityProvider({ children }: { children: React.ReactNode }) {
  const [preferences, setPreferences] = useState<AccessibilityPreferences>({
    reduceMotion: false,
    reduceTransparency: false,
  });

  useEffect(() => {
    let mounted = true;
    void Promise.all([
      AccessibilityInfo.isReduceMotionEnabled(),
      AccessibilityInfo.isReduceTransparencyEnabled(),
    ]).then(([reduceMotion, reduceTransparency]) => {
      if (mounted) setPreferences({ reduceMotion, reduceTransparency });
    });

    const motionSubscription = AccessibilityInfo.addEventListener('reduceMotionChanged', (reduceMotion) => {
      setPreferences((current) => ({ ...current, reduceMotion }));
    });
    const transparencySubscription = AccessibilityInfo.addEventListener(
      'reduceTransparencyChanged',
      (reduceTransparency) => setPreferences((current) => ({ ...current, reduceTransparency })),
    );
    return () => {
      mounted = false;
      motionSubscription.remove();
      transparencySubscription.remove();
    };
  }, []);

  return <AccessibilityContext.Provider value={preferences}>{children}</AccessibilityContext.Provider>;
}

export const useAccessibilityPreferences = () => useContext(AccessibilityContext);
