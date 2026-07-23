# TezDav Liquid Glass

The redesign uses a dark matte workspace with one floating system glass layer for navigation and controls.

## Rules

- Put data, charts, forms, and list rows on `DataSurface` or the compatibility `liquidGlassCard` modifier. Both are opaque.
- Use `liquidGlassControl` only for buttons, segmented controls, filters, and compact navigation controls.
- Use `GlassSegmentedControl` for app-owned mode and period selectors.
- Use `MetricDataCard`, `RecordValueRow`, and `TezDavEmptyState` before creating screen-specific variants.
- Keep emerald and ruby semantic: positive/readiness and fatigue/risk. Do not tint entire screens.
- Use Dynamic Type styles and `monospacedDigit()` for changing numbers.

## Platform Behavior

- iOS 26 uses SwiftUI `glassEffect`, `GlassEffectContainer`, and the native floating tab bar.
- iOS 17-25 uses a material fallback for controls.
- Reduce Transparency replaces material with an opaque raised surface.
- Reduce Motion disables spring and content reveal animations.
- Increased Contrast strengthens control borders.

## Previews

`RedesignPreviews.swift` contains dark previews for all five tabs with Reduce Transparency both disabled and enabled.
