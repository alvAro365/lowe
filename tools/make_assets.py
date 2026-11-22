#!/usr/bin/env python3
"""Lager lydene og app-ikonet til Loves vedskog.

Kjør fra repo-roten:  python3 tools/make_assets.py
Krever numpy og Pillow. Alt lages fra bunnen av, ingen eksterne filer.
"""
import json
import math
import os
import wave

import numpy as np
from PIL import Image, ImageDraw

RATE = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "Lowe")
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def save(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = int(RATE * 0.004)
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(ROOT, "Sounds", name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def chop():
    t = t_axis(0.22)
    noise = lowpass(rng.standard_normal(t.size), 0.35) * np.exp(-t / 0.018)
    body = np.sin(2 * math.pi * 190 * t) * np.exp(-t / 0.05)
    knock = np.sin(2 * math.pi * 420 * t) * np.exp(-t / 0.025)
    return 0.9 * noise + 0.8 * body + 0.5 * knock


def split():
    t = t_axis(0.42)
    crack = rng.standard_normal(t.size) * np.exp(-t / 0.012)
    crack2 = np.roll(rng.standard_normal(t.size) * np.exp(-t / 0.03), int(RATE * 0.025))
    thump = np.sin(2 * math.pi * 110 * t) * np.exp(-t / 0.09)
    wood = np.sin(2 * math.pi * 330 * t) * np.exp(-t / 0.06)
    return 0.8 * crack + 0.5 * lowpass(crack2, 0.4) + 0.9 * thump + 0.4 * wood


def stack():
    t = t_axis(0.14)
    a = np.sin(2 * math.pi * 720 * t) * np.exp(-t / 0.025)
    b = np.sin(2 * math.pi * 1080 * t) * np.exp(-t / 0.015)
    n = lowpass(rng.standard_normal(t.size), 0.5) * np.exp(-t / 0.008)
    return a + 0.6 * b + 0.4 * n


def land():
    t = t_axis(0.2)
    thud = np.sin(2 * math.pi * 120 * t) * np.exp(-t / 0.05)
    n = lowpass(rng.standard_normal(t.size), 0.2) * np.exp(-t / 0.02)
    return thud + 0.6 * n


def whoosh():
    t = t_axis(0.22)
    env = np.sin(math.pi * t / t[-1]) ** 2
    return lowpass(rng.standard_normal(t.size), 0.08) * env


def cheer():
    total = t_axis(1.1)
    out = np.zeros(total.size)
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    for i, f in enumerate(notes):
        start = int(RATE * 0.11 * i)
        t = t_axis(0.6)
        tone = (np.sin(2 * math.pi * f * t) + 0.25 * np.sin(2 * math.pi * 4 * f * t) * np.exp(-t / 0.02))
        tone *= np.exp(-t / 0.18)
        end = min(out.size, start + t.size)
        out[start:end] += tone[: end - start]
    return out


def icon():
    size = 1024
    img = Image.new("RGB", (size, size), (0xCD, 0xEB, 0xEF))
    d = ImageDraw.Draw(img)
    ink, turq = (0x1D, 0x1F, 0x24), (0x1F, 0xC2, 0xC2)
    d.rectangle([0, 760, size, size], fill=(0xF6, 0xF8, 0xF9))
    cx, cy = 380, 600
    d.ellipse([cx - 300, cy - 300, cx + 300, cy + 300], fill=ink)
    d.ellipse([cx - 280, cy - 280, cx + 280, cy + 280], fill=(0x7A, 0x4A, 0x2B))
    d.ellipse([cx - 228, cy - 228, cx + 228, cy + 228], fill=(0xF0, 0xCE, 0x94))
    for r in (160, 96, 36):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(0xC9, 0x9A, 0x62), width=14)
    # Øks med turkis skaft
    a, b = (580, 930), (740, 260)
    for w, col in ((80, ink), (48, turq)):
        d.line([a, b], fill=col, width=w)
        for (x, y) in (a, b):
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=col)
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    nx, ny = -uy, ux
    if nx < 0:
        nx, ny = -nx, -ny
    def pt(along, out):
        return (b[0] - ux * along + nx * out, b[1] - uy * along + ny * out)
    head = [pt(-30, -20), pt(150, -20), pt(190, 200), pt(-70, 200)]
    d.polygon(head, fill=(0xBF, 0xC8, 0xCF))
    d.line(head + [head[0]], fill=ink, width=18, joint="curve")
    d.line([pt(170, 175), pt(-50, 175)], fill=(255, 255, 255), width=10)
    path = os.path.join(ROOT, "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(path, exist_ok=True)
    img.save(os.path.join(path, "AppIcon.png"))
    with open(os.path.join(path, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)
    with open(os.path.join(ROOT, "Assets.xcassets", "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)


if __name__ == "__main__":
    save("chop.wav", chop())
    save("split.wav", split())
    save("stack.wav", stack(), gain=0.6)
    save("land.wav", land(), gain=0.7)
    save("whoosh.wav", whoosh(), gain=0.45)
    save("cheer.wav", cheer(), gain=0.7)
    icon()
    print("ok")
