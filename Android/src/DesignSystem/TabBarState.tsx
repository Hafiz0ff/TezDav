import React, { createContext, useCallback, useContext, useRef, useState } from 'react';
import type { NativeSyntheticEvent, NativeScrollEvent } from 'react-native';

interface TabBarStateValue {
  minimized: boolean;
  onScroll: (event: NativeSyntheticEvent<NativeScrollEvent>) => void;
  expand: () => void;
}

const TabBarStateContext = createContext<TabBarStateValue>({
  minimized: false,
  onScroll: () => undefined,
  expand: () => undefined,
});

export function TabBarStateProvider({ children }: { children: React.ReactNode }) {
  const [minimized, setMinimized] = useState(false);
  const lastOffset = useRef(0);

  const onScroll = useCallback((event: NativeSyntheticEvent<NativeScrollEvent>) => {
    const offset = Math.max(0, event.nativeEvent.contentOffset.y);
    const delta = offset - lastOffset.current;
    if (offset < 28) setMinimized(false);
    else if (delta > 10) setMinimized(true);
    else if (delta < -10) setMinimized(false);
    lastOffset.current = offset;
  }, []);

  const expand = useCallback(() => setMinimized(false), []);
  return (
    <TabBarStateContext.Provider value={{ minimized, onScroll, expand }}>
      {children}
    </TabBarStateContext.Provider>
  );
}

export const useTabBarState = () => useContext(TabBarStateContext);
