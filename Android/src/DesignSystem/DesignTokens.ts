export const Spacing = {
  xxs: 4,
  xs: 8,
  sm: 12,
  md: 16,
  lg: 20,
  xl: 24,
  xxl: 32,
  screen: 20,
} as const;

export const Radii = {
  small: 12,
  control: 16,
  card: 24,
  large: 28,
  pill: 999,
} as const;

export const Sizes = {
  minimumTap: 48,
  tabBarExpanded: 72,
  tabBarCompact: 56,
  screenBottomInset: 126,
} as const;

export const Motion = {
  spring: { damping: 18, stiffness: 220, mass: 0.8 },
  quick: 180,
} as const;
