# Rams Recorder Icon

2026-10-05. Generated and edited with the built-in image-generation tool.
This is the current app-icon artwork for both native platforms. The earlier
graphite recorder and Liquid Glass sources remain as design history.

- `mumla-rams-ios-source.png`: opaque, full-square artwork. iOS applies its mask.
- `mumla-rams-mac-source.png`: rounded tile with genuinely transparent margins.
- Palette: off-white instrument face, charcoal waveform slots, orange record key.
- No wordmark, labels, screen bezel, tiny decorative controls or glass effects.

The five-bar waveform preserves recognition while the lighter material and
orange mechanical key match Mumla's newer light-mode recorder and keyboard.
Both versions have the same functional motif and front-on composition.

Export using `bash scripts/export_app_icons.sh`. The script only resizes the
generated platform masters to the existing asset-catalog slots using `sips`.
Do not pre-round the iOS source or flatten macOS transparency.

## Verification

Both final asset catalogs compiled with Apple's `actool` without warnings.
All eight unique PNG exports match their catalog dimensions. The iOS master
and export have no alpha channel; every Mac export has zero-alpha corners and
a visible face. Pixel checks find the orange key and contrasting waveform at
every size, including 16 pixels. The final 32- and 128-pixel Mac exports were
visually inspected. Local evidence is under `.build/AppIconQA/`.
No signed release or TestFlight upload is part of this icon change.

## iOS Prompt

Use case: style-transfer / logo-brand. Asset type: production iOS app icon for Mumla, a private dictation app. Redesign the attached old icon with the original functional simplicity and tactile precision of Dieter Rams and restrained Braun-era audio instruments. Preserve only the recognizable five-bar speech waveform and recording control concept, not the gritty old styling. Deliver ONE square app-icon artwork, straight-on orthographic, NOT a device mockup or presentation sheet. The entire square edge-to-edge is a smooth, very pale neutral off-white molded instrument face, approximately #F4F5F0, with no outside margin and NO pre-rounded outer corners; iOS will apply its own mask. Two beautifully proportioned features, centered on one vertical axis: in the upper half a bold compact waveform of exactly five evenly spaced charcoal vertical capsule slots, with heights short / medium / tall / medium / short, subtle recessed depth, no display and no enclosing bezel; in the lower half one substantial circular orange recording key, approximately #F56626, in a very slim neutral-gray socket, with a soft beveled edge and a faint natural contact shadow. Generous clean space, careful functional geometry, impeccable industrial-design finish. The waveform is a strong simple silhouette visible at 32 pixels; the orange key is a strong round shape, not a tiny LED. Materials feel satin, smooth, finely molded, with understated physical relief, light from upper-left, crisp contours. Pale white and light gray body, charcoal waveform, orange key only. Do not add a microphone glyph, text, labels, numbers, brand wordmark, logos, screws, tick marks, screen/LCD, grille dots, extra buttons, perspective, gritty/noisy texture, leather, brushed-metal stripes, chrome, glass, glow, heavy gradients, harsh shadows, background objects, watermark or border around the square. The result should feel contemporary, calm and tactile, less but better, an original design rather than a reproduction of any specific product.

## macOS Prompt

Use case: precise-object-edit / background-extraction. Create the macOS app-icon variant of this exact Mumla icon. Keep the supplied icon artwork: the same pale off-white satin face, exact five charcoal waveform capsule slots, exact orange circular recording key in its thin gray socket, the same straight-on orthographic view, proportions, alignment, colors, and tactile lighting. Do not redesign or add anything. Change ONLY its outer silhouette and surrounding canvas for a macOS Dock icon: uniformly scale the entire existing artwork to fit within a centered rounded-square instrument tile occupying 88% of the full square canvas, with equal empty margins. The tile has smooth generous continuous squircle-like outer corners, a tiny softly beveled white edge, and an understated natural contact shadow below. Clip the original white face to that silhouette. Outside the tile and its faint shadow is genuine alpha TRANSPARENCY, not white, gray, a checkerboard drawing, or black. Keep all five waveform slots and the circular orange key completely within the tile and unchanged. Deliver ONE isolated square PNG icon with transparent margins, no surrounding scene, no text, no watermark, no perspective, no drop-shadow box, no new texture or features. The tile is a thin app-icon face, not a thick cube.

### Edge Cleanup

This additional generated variant was rejected because its nominally clear
canvas retained a faint alpha residue. The selected Mac master is the preceding
transparent variant; its exported corners are checked for zero alpha.

Precise production cleanup of the attached macOS app icon. Preserve the icon's composition, five dark waveform slots, orange record key, off-white face, colors and proportions exactly. Fix ONLY the outer boundary and transparent canvas: the silhouette must be a mathematically smooth, symmetrical rounded square with pristine continuous edges, not the current fuzzy jagged extraction. Remove all stray detached white pixels, white specks, fringe and halo outside the tile. All of the instrument face and features inside the tile must be fully solid and opaque, not patchily translucent. Use smooth fine anti-aliasing only on the silhouette edge. Outside the rounded-square silhouette is genuine fully clear alpha transparency with equal 7-percent margins. No external shadow is necessary; eliminate the scattered rough shadow if it cannot be perfectly clean. The tile may have a single extremely subtle light-gray bevel just INSIDE the clean silhouette. Do not add features, words, symbols, marks, backgrounds, mockups or perspective. Output one clean transparent square macOS icon asset, with complete artwork unchanged.
