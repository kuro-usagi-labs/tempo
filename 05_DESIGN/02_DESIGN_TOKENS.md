# Design Tokens

These tokens are implementation starting points and must pass contrast testing.

## Color

```text
background.primary   #090A0D
background.secondary #101218
surface.1            #151821
surface.2            #1B1F2A
surface.3            #242938
text.primary         #F5F7FB
text.secondary       #AEB5C4
text.tertiary        #747D8F
accent.primary       #786CFF
accent.cool          #53C7E8
success              #4ED39A
warning              #F3B34C
danger               #FF405D
danger.deep          #8F1830
border.subtle        rgba(255,255,255,0.08)
```

## Spacing

```text
2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64
```

## Radius

```text
small 12
medium 18
large 24
hero 32
pill 999
```

## Motion duration

```text
micro 120 ms
fast 180 ms
standard 280 ms
slow 480 ms
ambient 1200–4000 ms
```

## Springs

```text
button: response 0.24, damping 0.78
card: response 0.34, damping 0.82
modal: response 0.42, damping 0.88
warning: response 0.20, damping 0.68
```

## Haptic semantics

- selection: dial movement
- light impact: card confirmation
- medium impact: pause threshold
- rigid/sharp custom pattern: “stop now”
- success notification: completed cycle
- warning notification: safety block
