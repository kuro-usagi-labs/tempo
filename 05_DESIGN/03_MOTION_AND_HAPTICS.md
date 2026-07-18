# Motion and Haptics Specification

Motion must make the app satisfying without becoming stimulating or distracting.

## Motion principles

1. Motion communicates state.
2. Haptics reinforce actions that do not require looking at the screen.
3. Red animation is reserved for stopping or safety.
4. No rapid flashing.
5. Respect Reduce Motion.

## Breathing orb

- Expands over 4 seconds.
- Brief 1-second hold.
- Contracts over 6 seconds.
- Soft radial glow follows the orb.
- Optional subtle haptic at inhale start and exhale start.

## Arousal dial

- Circular or vertical thumb-friendly control.
- Gradient shifts from cool indigo to amber.
- At threshold, the surrounding ring separates into a slow red ripple.
- Monospaced level number morphs smoothly.

## Red warning animation

When the user reaches the adaptive stop threshold:

1. Background edge tint transitions to dark red in 180 ms.
2. Two concentric red waves expand from the control center.
3. Primary text scales from 0.92 to 1.0 using a firm spring.
4. A custom haptic pattern plays: strong–short, pause, strong–long.
5. The active control collapses into a single **Pause** state.
6. Breathing orb appears after 350 ms.

The effect must feel urgent but not frightening.

## Cycle completion

- Progress ring closes with a clean magnetic snap.
- Small particles travel along the ring; do not use confetti.
- Success haptic plays once.
- Next-state card slides upward by 12 pt.

## Card interactions

- Press scale: 0.975.
- Surface highlight shifts toward touch point.
- Release uses a soft spring.

## Ambient home animation

Use a very slow, low-contrast gradient drift behind the primary plan card. Freeze while Low Power Mode or Reduce Motion is enabled.

## Accessibility fallback

With Reduce Motion:

- replace scale/translation with opacity;
- remove particles and ripples;
- retain clear color, text, and haptic signals;
- allow haptics to be disabled independently.
