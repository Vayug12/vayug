1. "Golden Ratio (1 : 1.62)" Maintain Rahe — Iska Kya Matlab Hai?
Golden Ratio ($\Phi \approx 1.618$) nature ka wo mathematical proportion hai jo insaan ki aankhon aur brain ko naturally sabse zyada balanced, graceful aur aesthetically pleasing lagta hai (jaise sea shells, flowers, aur human anatomy me milta hai).

UI aur Card Design me iska use:
Ratio: Agar kisi rectangle ki Width 1 unit hai, to uski Height 1.618 units honi chahiye ($\approx 1 : 1.62$).
Problem jo ye solve karta hai:
Agar card square ($1:1$) ho, to mobile screen par bohot wide aur bulky lagta hai.
Agar card bohot lamba ho ($1:2$ ya zyada), to wo stretched aur awkward lagta hai.
$1 : 1.62$ ek aisa "sweet spot" hai jo Apple Credit Card, Apple Wallet Passes, App Store Feature Cards aur Instagram Stories ($9:16 \approx 1:1.77$) me use hota hai.
Code me iska matlab:
dart
final cardWidth = availableWidth.clamp(260.0, 310.0);
final cardHeight = (cardWidth * 1.62).clamp(440.0, 490.0);
Iska matlab hai chahe chota phone ho ya bada tablet, Width change hote hi Height bhi usi proportion ($1.62$) me dynamically scale hogi, jisse card kabhi bhi squished (chaptā) ya stretched nahi dikhega.
2. Apple Design ke Core "Golden Rules" (Human Interface Guidelines - HIG)
Apple ka design world-class isliye lagta hai kyuki wo in 8 Golden Principles ko religiously follow karta hai (jo aapke 

frontend/design.md
 me bhi documented hain):

Rule 1: The 3 Core Pillars (Clarity, Deference, Depth)
Clarity (Spasht-ta): Har font size readable ho, icons precise hon, koi decorative clutter na ho.
Deference (Content First): UI background me rehta hai aur user ka content hero banta hai. UI kabhi content se attention nahi chheen-ta.
Depth (Layered Materials): Flat designs ki jagah Apple translucent materials (glassmorphism/blur), layered surfaces aur soft drop-shadows use karta hai taaki user ko hierarchy samajh aaye ki kaun si sheet kiske upar hai.
Rule 2: The "Squircle" (Continuous Curvature - G2 Curvature)
Normal apps simple geometric circle wala corner radius use karti hain (BorderRadius.circular), jahan straight line aur curve ke milne par ek halka sa sharp point (tangent break) hota hai.
Apple Superellipse / Continuous Curvature (Squircle) use karta hai — jahan corner curve ultra-smooth aur seamless blend hota hai (jaise iPhone ke corners, app icons, aur iOS cards).
Corner Radius Standard:
Action Buttons: 14px
Cards: 18px – 22px
Dialogs / Bottom Sheets: 24px – 28px
Rule 3: Whitespace Over Borders ("Less is More")
Divider lines aur borders clutter create karti hain.
Apple do cheezon ko separate karne ke liye thick lines nahi banata; balki 8-point grid ka whitespace use karta hai:
Allowed Spacings: 4, 8, 12, 16, 20, 24, 32, 48px
Agar separator zaroori bhi ho, to wo hairline aur 6-8% opacity par hota hai (Colors.white.withOpacity(0.06)).
Rule 4: Single Accent Color Discipline
Ek screen par kabhi multiple chamak-dhamak colors mix nahi kiye jaate.
Sirf 1 primary accent color: Jaise Apple Blue (#2563EB / #007AFF).
Baaki pura interface Dark/Slate neutral surfaces (#0F172A, #1E293B) aur 3 tiers of text color par chalta hai:
Primary: #FFFFFF (100% white)
Secondary: #94A3B8 (Subtle muted)
Tertiary: #64748B (Muted captions)
Rule 5: Strict Typography Hierarchy (Max 4 Font Sizes)
Ek screen par kabhi 4 se zyada font sizes nahi hote.
Apple Scale:
Title: 20px (Bold 700 / SemiBold 600)
Body: 14px - 16px (Regular 400 / Medium 500)
Caption / Badge: 11px - 12px (Medium 500)
Letter Spacing: Small uppercase words me wide tracking (e.g. letterSpacing: 2.0 in VAYUG), aur bade headings me tight tracking (letterSpacing: -0.5).
Rule 6: Tactile Feedback & Physics-Based Motion
Touch Target Rule (44x44pt): Koi bhi button ya clickable icon 44x44 pixels se chota nahi hona chahiye taaki thumb se accurate click ho sake.
Haptics: Har key action par halka tactile vibration (HapticFeedback.lightImpact()), jisse app physical device ki tarah mehsoos ho.
Motion: Animation fast (200ms–300ms) aur natural curves (Curves.easeInOut) ke sath hoti hai, kabhi tacky bounce ya flashy rotation nahi hoti.
Rule 7: Copy Rule ("Every Word Must Earn Its Place")
Text is UI — har extra word visual clutter hai:
Button: Action verb first (e.g., "Sign In", not "Click here to sign in").
No obvious statements: Jo cheez user dekh kar samajh sakta hai, use text me dubara mat likho (isi rule ke tehat humne duplicate "CREATOR" badge aur "Full access unlocked" remove kiya).
Rule 8: Iconic App Squircles for Feature Rows
Feature rows me plain floating icons ki jagah ek 36x36 surface squircle ke andar icon ko center kiya jaata hai (jaise iOS Settings app aur Apple Wallet me hota hai). Ye content ko visually anchor karta hai aur eye-scanning effortless bana deta hai.
3:57 AM
