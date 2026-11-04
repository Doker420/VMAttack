#!/usr/bin/env python3
"""Deterministic original BLOCKSIEGE music and SFX. No samples or external recordings."""
from __future__ import annotations

import hashlib
import json
import math
import random
import struct
import wave
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SR = 22050
TAU = math.tau
RNG = random.Random(64006)


def midi(note: float) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def stereo_buffer(seconds: float) -> tuple[array, array]:
    count = int(seconds * SR)
    return array("f", [0.0]) * count, array("f", [0.0]) * count


def add_tone(left, right, start, duration, frequency, amplitude, kind="pluck", pan=0.0):
    first = max(0, int(start * SR))
    last = min(len(left), first + int(duration * SR))
    attack = max(1, int(min(0.08, duration * 0.15) * SR))
    release = max(1, int(min(0.35, duration * 0.35) * SR))
    phase = RNG.random() * TAU if kind == "pad" else 0.0
    left_gain = math.sqrt((1 - pan) * 0.5)
    right_gain = math.sqrt((1 + pan) * 0.5)
    for index in range(first, last):
        local = index - first
        remaining = last - index
        envelope = min(1.0, local / attack, remaining / release)
        if kind == "pluck":
            envelope *= math.exp(-3.2 * local / max(1, last - first))
            wave_value = math.sin(phase + TAU * frequency * local / SR) + 0.28 * math.sin(phase + TAU * frequency * 2 * local / SR)
        elif kind == "bass":
            wave_value = math.sin(TAU * frequency * local / SR) + 0.32 * math.sin(TAU * frequency * 0.5 * local / SR)
        else:
            wave_value = (
                math.sin(phase + TAU * frequency * local / SR)
                + 0.24 * math.sin(phase + TAU * frequency * 2 * local / SR)
                + 0.1 * math.sin(phase + TAU * frequency * 3 * local / SR)
            )
        value = amplitude * envelope * wave_value
        left[index] += value * left_gain
        right[index] += value * right_gain


def add_drums(left, right, start, beat, intensity, battle=False):
    for step in range(16):
        moment = start + step * beat / 4
        if moment >= len(left) / SR:
            continue
        if step % 4 == 0:
            add_kick(left, right, moment, intensity * (1.0 if step in (0, 8) else 0.72))
        if battle and step % 8 == 4:
            add_snare(left, right, moment, intensity * 0.65)
        if step % 2 == 0:
            add_hat(left, right, moment, intensity * (0.2 if battle else 0.12))


def add_kick(left, right, start, amplitude):
    duration = 0.2
    first = int(start * SR)
    for offset in range(int(duration * SR)):
        index = first + offset
        if index >= len(left):
            return
        t = offset / SR
        value = amplitude * math.exp(-20 * t) * math.sin(TAU * (72 * t - 42 * t * t))
        left[index] += value
        right[index] += value


def add_snare(left, right, start, amplitude):
    first = int(start * SR)
    for offset in range(int(0.16 * SR)):
        index = first + offset
        if index >= len(left):
            return
        t = offset / SR
        value = amplitude * math.exp(-24 * t) * (RNG.uniform(-1, 1) * 0.7 + math.sin(TAU * 185 * t) * 0.3)
        left[index] += value
        right[index] += value


def add_hat(left, right, start, amplitude):
    first = int(start * SR)
    for offset in range(int(0.045 * SR)):
        index = first + offset
        if index >= len(left):
            return
        t = offset / SR
        value = amplitude * math.exp(-75 * t) * RNG.uniform(-1, 1)
        left[index] += value * 0.8
        right[index] += value


def finish_music(left, right, name, bpm):
    delay = int(0.22 * SR)
    for index in range(delay, len(left)):
        left[index] += right[index - delay] * 0.1
        right[index] += left[index - delay] * 0.1
    fade = int(0.055 * SR)
    for index in range(fade):
        factor = index / fade
        left[index] *= factor
        right[index] *= factor
        left[-1 - index] *= factor
        right[-1 - index] *= factor
    peak = max(0.001, max(max(abs(v) for v in left), max(abs(v) for v in right)))
    gain = 0.82 / peak
    path = ROOT / name
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SR)
        frames = bytearray()
        for l, r in zip(left, right):
            frames += struct.pack("<hh", int(max(-1, min(1, l * gain)) * 32767), int(max(-1, min(1, r * gain)) * 32767))
        output.writeframes(frames)
    return {"file": name, "kind": "music", "seconds": round(len(left) / SR, 3), "loop": True, "bpm": bpm}


def make_music(name, seconds, bpm, mode):
    left, right = stereo_buffer(seconds)
    beat = 60 / bpm
    bars = round(seconds / (beat * 4))
    progressions = {
        "lobby": [48, 53, 55, 50],
        "build": [45, 48, 52, 50],
        "battle": [40, 43, 45, 38],
    }
    roots = progressions[mode]
    melodies = {
        "lobby": [12, 16, 19, 16, 14, 12, 9, 11],
        "build": [12, 12, 15, 19, 17, 15, 12, 10],
        "battle": [12, 15, 19, 22, 19, 17, 15, 10],
    }
    for bar in range(bars):
        start = bar * beat * 4
        root = roots[bar % len(roots)]
        chord = (0, 4, 7) if mode != "battle" else (0, 3, 7)
        for note_index, interval in enumerate(chord):
            add_tone(left, right, start, beat * 3.85, midi(root + interval + 12), 0.09, "pad", (note_index - 1) * 0.45)
        for beat_index in range(4):
            add_tone(left, right, start + beat_index * beat, beat * 0.82, midi(root - 12), 0.16 if mode == "battle" else 0.12, "bass")
        for step, interval in enumerate(melodies[mode]):
            swing = 0.04 if mode == "build" and step % 2 else 0
            add_tone(left, right, start + step * beat / 2 + swing, beat * 0.45, midi(root + interval + 12), 0.1 if mode != "battle" else 0.12, "pluck", (-1) ** step * 0.25)
        add_drums(left, right, start, beat, 0.2 if mode == "lobby" else (0.28 if mode == "build" else 0.38), mode == "battle")
    return finish_music(left, right, name, bpm)


def write_sfx(name, seconds, synthesizer):
    count = int(seconds * SR)
    samples = [0.0] * count
    for index in range(count):
        samples[index] = synthesizer(index / SR, index)
    fade = min(int(0.012 * SR), count // 3)
    for index in range(fade):
        samples[index] *= index / fade
        samples[-1 - index] *= index / fade
    peak = max(0.001, max(abs(value) for value in samples))
    with wave.open(str(ROOT / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SR)
        output.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, value / peak * 0.86)) * 32767)) for value in samples))
    return {"file": name, "kind": "sfx", "seconds": seconds, "loop": False}


def noise():
    return RNG.uniform(-1, 1)


def make_sfx():
    entries = []
    entries.append(write_sfx("Shot.wav", 0.18, lambda t, _: (noise() * 0.65 + math.sin(TAU * (310 * t - 260 * t * t)) * 0.5) * math.exp(-24 * t)))
    entries.append(write_sfx("HeavyShot.wav", 0.48, lambda t, _: (noise() * 0.35 + math.sin(TAU * (145 * t - 85 * t * t)) * 0.9) * math.exp(-9 * t)))
    entries.append(write_sfx("Hit.wav", 0.13, lambda t, _: (math.sin(TAU * 840 * t) + 0.45 * math.sin(TAU * 1260 * t)) * math.exp(-34 * t)))
    entries.append(write_sfx("Build.wav", 0.28, lambda t, _: (math.sin(TAU * 190 * t) * 0.65 + noise() * 0.25) * math.exp(-16 * t) + (math.sin(TAU * 260 * (t - 0.13)) * math.exp(-28 * (t - 0.13)) if t > 0.13 else 0)))
    entries.append(write_sfx("Destroy.wav", 0.62, lambda t, _: (noise() * 0.75 + math.sin(TAU * 58 * t) * 0.5) * math.exp(-6.5 * t)))
    entries.append(write_sfx("CoreDestroyed.wav", 1.5, lambda t, _: (noise() * 0.36 + math.sin(TAU * (70 * t - 12 * t * t)) + 0.3 * math.sin(TAU * 420 * t)) * math.exp(-2.7 * t)))
    entries.append(write_sfx("UIClick.wav", 0.08, lambda t, _: math.sin(TAU * 720 * t) * math.exp(-55 * t)))
    for name, notes, seconds in [
        ("CaseOpened.wav", [72, 76, 79, 84], 0.95),
        ("Victory.wav", [60, 64, 67, 72, 76], 1.35),
        ("Defeat.wav", [57, 54, 50, 45], 1.15),
    ]:
        def chime(t, _, notes=notes):
            value = 0.0
            for index, note in enumerate(notes):
                start = index * (0.13 if name != "Defeat.wav" else 0.18)
                if t >= start:
                    local = t - start
                    value += math.sin(TAU * midi(note) * local) * math.exp(-4.2 * local) * 0.42
            return value
        entries.append(write_sfx(name, seconds, chime))
    return entries


def main():
    entries = [
        make_music("BlockSiege_Lobby.wav", 32, 120, "lobby"),
        make_music("BlockSiege_Build.wav", 32, 120, "build"),
        make_music("BlockSiege_Battle.wav", 48, 120, "battle"),
    ]
    entries.extend(make_sfx())
    for entry in entries:
        entry["sha256"] = hashlib.sha256((ROOT / entry["file"]).read_bytes()).hexdigest()
    manifest = {"sampleRate": SR, "format": "16-bit PCM WAV", "original": True, "assets": entries}
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(entries)} original audio assets")


if __name__ == "__main__":
    main()
