---
name: Field & Counter Engine
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#45464d'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#76777d'
  outline-variant: '#c6c6cd'
  surface-tint: '#565e74'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#131b2e'
  on-primary-container: '#7c839b'
  inverse-primary: '#bec6e0'
  secondary: '#0051d5'
  on-secondary: '#ffffff'
  secondary-container: '#316bf3'
  on-secondary-container: '#fefcff'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#002113'
  on-tertiary-container: '#009668'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae2fd'
  primary-fixed-dim: '#bec6e0'
  on-primary-fixed: '#131b2e'
  on-primary-fixed-variant: '#3f465c'
  secondary-fixed: '#dbe1ff'
  secondary-fixed-dim: '#b4c5ff'
  on-secondary-fixed: '#00174b'
  on-secondary-fixed-variant: '#003ea8'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-currency:
    fontFamily: Plus Jakarta Sans
    fontSize: 2.5rem
    fontWeight: '700'
    lineHeight: 3rem
    letterSpacing: -0.03em
  display-currency-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 2rem
    fontWeight: '700'
    lineHeight: 2.5rem
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.75rem
    fontWeight: '700'
    lineHeight: 2.25rem
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.375rem
    fontWeight: '700'
    lineHeight: 1.75rem
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.25rem
    fontWeight: '600'
    lineHeight: 1.75rem
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.125rem
    fontWeight: '600'
    lineHeight: 1.5rem
  body-lg:
    fontFamily: Inter
    fontSize: 1rem
    fontWeight: '400'
    lineHeight: 1.5rem
  body-md:
    fontFamily: Inter
    fontSize: 0.875rem
    fontWeight: '400'
    lineHeight: 1.25rem
  body-sm:
    fontFamily: Inter
    fontSize: 0.75rem
    fontWeight: '400'
    lineHeight: 1rem
  label-numeric:
    fontFamily: Inter
    fontSize: 0.875rem
    fontWeight: '600'
    lineHeight: 1.25rem
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 0.875rem
    fontWeight: '500'
    lineHeight: 1.25rem
  label-sm:
    fontFamily: Inter
    fontSize: 0.6875rem
    fontWeight: '600'
    lineHeight: 0.875rem
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  gutter-desktop: 2rem
  margin: 1rem
  margin-tablet: 1.5rem
  margin-desktop: 2.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
  space-2xl: 2rem
---

## Brand & Style

This design system targets modern field operators, retail shop owners, and trade contractors who manage quotes, dispatch jobs, and collect payments on mobile touchpoints. The emotional tone balances utilitarian confidence with operational speed: crisp, immediate, and trustworthy under bright sunlight or rushed in-store checkout conditions.

The visual style blends **Corporate / Modern** precision with **Tactile Functionalism**. Interfaces favor high-density data legibility over decorative excess. Key affordances rely on generous tap targets (minimum 48px), stark contrast ratios (exceeding WCAG AAA for transactional totals), tactile feedback states, and structured surface layering that separates dynamic transactional tallies from background operational tasks.

## Colors

The palette organizes operational urgency and transaction states through rigorous role assignments:

- **Primary (`#0F172A` - Slate Navy):** Anchors core structure, high-emphasis text, top app bars, and high-impact terminal actions. Provides deep grounding and eliminates the eye strain of harsh pitch black.
- **Secondary (`#2563EB` - Tech Cobalt):** Drives primary interactive paths, tap targets, focused input outlines, active navigation tabs, and system linkages.
- **Tertiary (`#10B981` - Emerald Green):** Reserved exclusively for positive cash flow, settled balances, successful card capture, and approved estimate states.
- **Accent Warning (`#F59E0B` - Warm Amber):** Flags pending invoices, drafts, quotes awaiting field signature, and partial payment states.
- **Neutral Surface Palette:**
  - `canvas`: `#F8FAFC` (cool background preventing glare)
  - `surface`: `#FFFFFF` (card bases and bottom sheets)
  - `surface-subtle`: `#F1F5F9` (line-item separators, numeric keypad trays)
  - `border-subtle`: `#E2E8F0` (structural dividers)
  - `border-strong`: `#CBD5E1` (interactive boundaries)
- **Text Tiers:**
  - `text-primary`: `#0F172A`
  - `text-secondary`: `#475569`
  - `text-muted`: `#64748B`
  - `text-inverse`: `#FFFFFF`

## Typography

The type hierarchy pairs **Plus Jakarta Sans** for prominent headers, modal anchors, and monetary totals with **Inter** for transactional data grids, form inputs, and line-item descriptions.

- All figures, quantities, and monetary counters enforce tabular lining (`font-feature-settings: "tnum" 1, "cv05" 1`) to ensure vertical decimal alignment across multi-line order estimates.
- `display-currency` dominates checkout summary states, ensuring immediate verification by customer and field technician at arm’s length.
- `label-sm` utilizes uppercase styling with positive letter-spacing (`0.04em`) specifically for contextual status tags (`PAID`, `PENDING`, `DISPATCHED`).

## Layout & Spacing

The layout structure relies on a fluid grid designed for one-handed thumb interaction on mobile devices and responsive multi-pane views on tablet and POS docks.

- **Mobile (< 640px):** Single-column stacked fluid layout with 16px (`margin`) outer edge gutters. Critical controls (charge trigger, finalize quote, keypad submit) are anchored into a pinned bottom dock.
- **Tablet / Counter POS (640px - 1024px):** Split-view 12-column grid. Left 7 columns host the itemized catalog or project scope; right 5 columns lock the live order ticket, customer signature, and payment terminal status.
- **Desktop / Back Office (> 1024px):** Fixed-fluid hybrid with a collapsable 240px navigation drawer and a 12-column responsive workspace.
- **Rhythm Rules:** Vertical spacing between form elements defaults to `space-lg` (16px). Dense data tables, inventory lists, and receipt rows collapse to `space-sm` (8px) padding to maximize information density.

## Elevation & Depth

Visual depth establishes clear operational separation between static forms, actionable receipt cards, and floating payment prompts:

- **Level 0 (Flat Surface):** Background canvas (`#F8FAFC`). Data tables and inactive rows sit directly on this plane with `1px solid #E2E8F0` borders.
- **Level 1 (Card Baseline):** Job cards, inventory items, and line-item blocks use pure `#FFFFFF` resting on Level 0, bounded by `1px solid #E2E8F0` paired with an ambient shadow: `0 1px 3px 0 rgba(15, 23, 42, 0.04), 0 1px 2px -1px rgba(15, 23, 42, 0.04)`.
- **Level 2 (Active/Hover Cards):** Tapped order cards or selected dispatch tiles elevate with `0 4px 6px -1px rgba(15, 23, 42, 0.07), 0 2px 4px -2px rgba(15, 23, 42, 0.05)` and transition the border color to `#CBD5E1`.
- **Level 3 (Sticky Controls & Drawers):** Bottom action bars and sticky totalizers employ `0 -4px 12px 0 rgba(15, 23, 42, 0.06)` with a top border of `1px solid #E2E8F0`.
- **Level 4 (Action Sheets & Overlays):** Modal sheets, card-swipe capture inputs, and keypad bottom drawers cast deep ambient depth: `0 20px 25px -5px rgba(15, 23, 42, 0.12), 0 8px 10px -6px rgba(15, 23, 42, 0.08)`. Backdrops use `#0F172A` at 45% opacity with a subtle 4px backdrop blur.

## Shapes

The design system maintains geometric discipline using Level 2 (Rounded) corner geometry. This provides a clean balance between technical reliability and modern mobile responsiveness.

- **Standard Cards, Panels, & Inputs:** 8px (`0.5rem`) corner radius.
- **Modals, Floating Action Sheets, & Containers:** 16px (`1rem` / `rounded-lg`) corner radius on top corners to denote a sliding drawer metaphor.
- **Status Badges, Steppers, & Quick-Filter Chips:** Fully pill-shaped (`9999px`) to immediately distinguish small categorical tags from actionable square cards.
- **Keypad Buttons:** 8px (`0.5rem`) radius with distinct physical separation (`space-sm` gap) to eliminate missed touches during high-velocity checkout.

## Components

### Buttons
- **Primary Action (Checkout/Save Job):** Solid `#0F172A` background, white text, 48px minimum height. Active press shifts to `#1E293B` with a subtle inset scale down (`scale-98`).
- **Payment Trigger (Process Payment):** High-prominence `#10B981` background, white text, bold font-weight. Dedicated specifically to currency transactions.
- **Secondary / Action Outlines:** White background, 1.5px border in `#CBD5E1`, text in `#0F172A`. Hover/press fills with `#F1F5F9`.
- **Destructive (Void / Cancel Job):** Subtle `#FEF2F2` fill, `#DC2626` text, transitioning to solid `#DC2626` on confirmation states.

### Status Chips & Numeric Badges
- **Paid / Approved:** Background `#ECFDF5`, text `#065F46`, pill border `1px solid #A7F3D0`.
- **Pending / Quote Sent:** Background `#FFFBEB`, text `#92400E`, pill border `1px solid #FDE68A`.
- **Draft / In Review:** Background `#F1F5F9`, text `#475569`, pill border `1px solid #CBD5E1`.
- **Counter Badges:** Circular or pill badges on cart items use high-contrast `#2563EB` background with `#FFFFFF` tabular numbers.

### Input Fields & Keypads
- **Form Inputs:** 44px height, `#FFFFFF` background, 1px border in `#CBD5E1`. Focus transitions to 2px ring in `#2563EB` with zero layout shift.
- **Point of Sale Keypad:** Monospaced tabular layout. Large numbers (24px, medium weight) centered on `#FFFFFF` surfaces with tap-highlight feedback.

### Lists & Line Items
- Clean table rows separated by `1px solid #F1F5F9`. 
- Left-aligned item description and quantity stepper; right-aligned unit price and running total.
- Swipe-left gesture reveals quick-action triggers (Discount: `#2563EB`, Delete: `#EF4444`).

### Cards & Ticket Panels
- White surface with structured division: top metadata strip (Job #, Timestamp, Status Chip), middle expandable scope/item list, bottom bold totalizer row.

### Mobile Bottom Navigation & Action Sheets
- **Bottom Navigation Bar:** 64px height, locked to viewport bottom. Active icons highlighted in `#2563EB` with a 4px dot indicator; inactive icons in `#64748B`.
- **Action Sheets:** Slide up from bottom with a centered grab handle (`36px x 4px`, `#CBD5E1`). Anchors immediate thumb-reach actions like "Collect Signature," "Split Bill," or "Add Surcharge."