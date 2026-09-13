# Design System

## Philosophy

This app follows a premium, minimal design language inspired by:

- ChatGPT
- Apple Human Interface Guidelines
- Linear
- Notion

The interface should feel calm, modern, intelligent, and effortless.

Never use flashy gradients, heavy shadows, oversized icons, or excessive colors.

The UI should prioritize whitespace, typography, hierarchy, and subtle animations over decoration.

---

# Core Principles

1. Less is more.
2. Every element must have a purpose.
3. Every word must earn its place.
4. Prefer whitespace over borders.
5. Avoid visual clutter.
6. Use smooth motion, never distracting animations.
7. Everything should feel premium.

---

# Color System

This is a dark theme, matching the Vayug app's navy/blue palette (see `lib/core/design/colors.dart`).

## Background

Primary Background
#0F172A

Secondary Background
#1E293B

Surface
#1E293B

Card
#1E293B

Divider
#334155

---

## Text

Primary
#FFFFFF

Secondary
#94A3B8

Muted
#64748B

Disabled
#64748B (60% opacity)

Inverse (on light surfaces)
#0F172A

---

## Accent

Primary Accent
#2563EB

Light
#3B82F6

Dark / Pressed
#1D4ED8

Success
#10B981

Warning
#F59E0B

Danger
#EF4444

Never use multiple accent colors in one screen.

---

# Corner Radius

Buttons
14px

Cards
18px

Dialogs
20px

Bottom Sheets
28px

Input Fields
14px

Images
16px

---

# Shadows

Avoid heavy shadows.

Use extremely soft elevation.

Example

0 2 12 rgba(0,0,0,0.05)

or

0 4 20 rgba(0,0,0,0.04)

---

# Typography

Use Inter.

Weights

Regular 400

Medium 500

SemiBold 600

Bold 700

Never use more than four font sizes on one screen.

Display
32

Title
24

Heading
20

Body
16

Caption
14

Small
12

Line height should always feel spacious.

---

# Copy

Fewer words, more meaning.

Text is UI. Every extra line is clutter, exactly like an extra border.

Write the shortest version that still works, then cut one more word.

## Limits

Heading

5 words. No full stop.

Body

1 line. A second line only if the user loses something without it.

Button

Verb first. 2 words. "Sign in", never "Sign in to continue".

Helper text

Only for rules the user cannot guess: limits, formats, cost, consequences.

Error

What broke, what to do. 1 line.

## Delete any text that

repeats what the control already says

states the obvious

describes what the user can already see

apologises or over-explains

## Rules

Never stack a heading, a subtitle and a button that all say the same thing.

Never explain a heading with a subtitle. Rewrite the heading instead.

One idea per screen. One line per idea.

An icon and one button is a finished screen, not an unfinished one.

Reference: `lib/shared/widgets/auth_sign_in_prompt.dart` — the button carries the meaning, the copy above it is optional.

---

# Spacing

Use an 8-point grid.

Allowed spacing

4

8

12

16

20

24

32

40

48

64

Never invent random spacing values.

---

# Buttons

Primary

Filled

Blue accent

White text

Height

52px

Radius

14px

Secondary

Surface background

Subtle border

Light text

Text Button

No border

Accent text

Never use gradients.

---

# Inputs

Height

52px

Rounded corners

14px

Soft gray background

No hard borders.

Focus should use the accent color.

---

# Cards

Cards should:

have lots of padding

soft corners

minimal shadow

no unnecessary outlines

avoid multiple nested cards

---

# Icons

Use Lucide icons.

Size

20 or 24

Stroke width

2

Never mix icon styles.

---

# Lists

Generous vertical spacing.

Each item should breathe.

Avoid dense layouts.

---

# Navigation

Bottom navigation should be simple.

No floating colorful effects.

Active item uses accent color.

Inactive items use muted gray.

---

# Animations

Duration

200–300ms

Use easeInOut.

Use fade, scale, or slide.

Never bounce.

Never over animate.

---

# Images

Rounded corners.

Consistent aspect ratios.

No decorative frames.

---

# Empty States

Every empty state should include:

simple icon

primary action

Add a title only when the action alone is ambiguous.

Never add a sentence explaining the title.

---

# Loading

Prefer skeleton loading.

Avoid full-screen spinners.

Never label a spinner with "Loading...". The spinner already says it.

---

# Error States

One line: what broke.

One action: how to fix it.

No apologies, no technical detail, no second paragraph.

---

# Accessibility

Minimum touch target

44x44

Contrast should remain high.

Support dynamic text.

---

# Screen Layout

Every screen follows:

Top App Bar

↓

Page Title

↓

Primary Content

↓

Secondary Content

↓

Primary CTA

Use generous whitespace between sections.

A description is not a step in this layout. Add one only when the title cannot carry the meaning, and keep it to one line.

---

# DO

✓ Minimal

✓ Premium

✓ Calm

✓ Spacious

✓ Consistent

✓ Few words

✓ Apple quality

✓ ChatGPT style

✓ Linear style

✓ Professional

---

# DON'T

✗ Glassmorphism

✗ Neon colors

✗ Heavy gradients

✗ Large drop shadows

✗ Rounded blobs everywhere

✗ Material 3 colorful defaults

✗ Inconsistent spacing

✗ Different button styles

✗ Random font sizes

✗ Crowded layouts

✗ Helper text that repeats the button

✗ A subtitle under every heading

✗ Paragraphs where a label works

✗ Marketing copy inside the product

---
# Responsiveness & Scroll Safety

Every screen, modal dialog, and bottom sheet must be 100% responsive and scroll-safe across all screen dimensions, landscape orientations, and system display zoom / font size settings.

## Rules:

1. **Never use naked Columns with fixed height or Spacer() without scroll protection:**
   - Always wrap screen bodies with `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight: constraints.maxHeight)` + `IntrinsicHeight` when elements need to stretch or pin actions to the bottom.
   - This ensures content expands naturally on large screens while smoothly scrolling on smaller phones (5–5.5 inches), split-screen, or landscape mode without `RenderFlex overflowed` errors.

2. **Modal Bottom Sheets must be Constrained & Scrollable:**
   - Always pass `isScrollControlled: true` to `showModalBottomSheet`.
   - Constrain maximum height via `ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88))`.
   - Wrap dynamic/scrollable items in `Flexible(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), ...))`.
   - Keep primary action buttons pinned at the bottom with a subtle divider so they remain immediately accessible.

3. **Dialogs & Confirmation Prompts:**
   - Dynamic or variable text in dialogs must be scroll-safe.
   - Maintain `insetPadding` (e.g. horizontal 24px) so dialogs never clip against viewport edges.

4. **Accessibility Font Scaling:**
   - Support system font scaling (>1.2x). Buttons, badges, and titles should use appropriate line wrapping or `TextOverflow.ellipsis` where single-line constraint is essential.
   - Never hardcode fixed viewport assumptions (e.g., assuming height is always >= 800px).

---

# DO

✓ Minimal

✓ Premium

✓ Calm

✓ Spacious

✓ Consistent

✓ Apple quality

✓ ChatGPT style

✓ Linear style

✓ Professional

✓ 100% Scroll-safe & responsive on all screen sizes

---

# DON'T

✗ Glassmorphism

✗ Neon colors

✗ Heavy gradients

✗ Large drop shadows

✗ Rounded blobs everywhere

✗ Material 3 colorful defaults

✗ Inconsistent spacing

✗ Different button styles

✗ Random font sizes

✗ Crowded layouts

✗ Naked Columns with Spacer() without scroll protection

✗ Fixed height assumptions causing RenderFlex overflows

✗ Helper text under inputs

✗ Multiple icons saying same thing

✗ Redundant text descriptions

✗ More than 2-3 lines of text per screen

---

# AI Instructions

Whenever creating a new screen:

- Reuse existing components whenever possible.
- Maintain identical spacing patterns.
- Do not invent new colors.
- Follow the typography scale.
- Keep interfaces minimal.
- Optimize for readability first.
- Every screen should look like it belongs in the same product.
- Always make screens and bottom sheets 100% responsive and scroll-safe (using LayoutBuilder + SingleChildScrollView + ConstrainedBox / Flexible) to guarantee zero RenderFlex overflow bugs on small devices, landscape, or high font-scaling modes.
- If unsure, choose the simpler option.
- No helper text under any input or label.
- Use minimum text. Say more with less.
- One icon per element. No fancy multiple icons.
- Primary CTA is always pure black (#000000) with white text. Secondary CTAs and accents use OpenAI green (#10A37F) and blue (#0066FF).
- The result should resemble a premium Apple-quality productivity app with the calm, high-contrast visual language of ChatGPT.