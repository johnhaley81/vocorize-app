#!/bin/bash

# GenerateTestAudio.sh
# Script to generate minimal test audio files for fixture testing
# Run this script from the VocorizeTests/Fixtures directory

echo "Generating test audio files for WhisperKit fixtures..."

AUDIO_DIR="Audio"
mkdir -p "$AUDIO_DIR"

# Generate using Python (available on all macOS systems)
/usr/bin/python3 << 'EOF'
import wave
import struct
import math
import os

def generate_wav(filename, duration, frequency=440, amplitude=0.1, sample_rate=16000):
    """Generate a WAV file with specified parameters"""
    frames = int(duration * sample_rate)
    samples = []
    
    for i in range(frames):
        if frequency > 0:
            t = i / sample_rate
            sample = int(amplitude * 32767 * math.sin(2 * math.pi * frequency * t))
        else:
            sample = 0  # silence
        samples.append(struct.pack('<h', sample))
    
    os.makedirs('Audio', exist_ok=True)
    with wave.open(f'Audio/{filename}', 'wb') as wav_file:
        wav_file.setnchannels(1)  # mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(b''.join(samples))

def generate_multi_tone(filename, durations, frequencies, sample_rate=16000):
    """Generate a WAV file with multiple tones in sequence"""
    all_samples = []
    
    for duration, freq in zip(durations, frequencies):
        frames = int(duration * sample_rate)
        for i in range(frames):
            t = i / sample_rate
            sample = int(0.08 * 32767 * math.sin(2 * math.pi * freq * t))
            all_samples.append(struct.pack('<h', sample))
    
    os.makedirs('Audio', exist_ok=True)
    with wave.open(f'Audio/{filename}', 'wb') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(b''.join(all_samples))

def generate_noisy(filename, duration, signal_freq, noise_level=0.02, sample_rate=16000):
    """Generate a WAV file with signal and background noise"""
    import random
    frames = int(duration * sample_rate)
    samples = []
    
    for i in range(frames):
        t = i / sample_rate
        signal = 0.06 * math.sin(2 * math.pi * signal_freq * t)
        noise = noise_level * (random.random() * 2 - 1)
        sample = int((signal + noise) * 32767)
        # Clamp to 16-bit range
        sample = max(-32768, min(32767, sample))
        samples.append(struct.pack('<h', sample))
    
    os.makedirs('Audio', exist_ok=True)
    with wave.open(f'Audio/{filename}', 'wb') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(b''.join(samples))

print("Generating test audio files...")

# 1. Silence (1 second)
generate_wav('silence.wav', 1.0, 0)
print("✓ silence.wav")

# 2. Hello World - speech-like pattern
generate_multi_tone('hello_world.wav', 
                   [0.4, 0.3, 0.5, 0.6, 0.7], 
                   [220, 330, 440, 550, 330])
print("✓ hello_world.wav")

# 3. Quick brown fox - complex sentence
generate_multi_tone('quick_brown_fox.wav', 
                   [0.3, 0.4, 0.3, 0.4, 0.5, 0.4, 0.3, 0.5, 0.5], 
                   [200, 350, 280, 420, 380, 300, 250, 320, 280])
print("✓ quick_brown_fox.wav")

# 4. Numbers 1-2-3
generate_multi_tone('numbers_123.wav', 
                   [0.4, 0.4, 0.5, 0.6, 0.5], 
                   [300, 400, 350, 450, 380])
print("✓ numbers_123.wav")

# 5. Multilingual sample
generate_multi_tone('multilingual_sample.wav', 
                   [0.5, 0.4, 0.6], 
                   [250, 380, 320])
print("✓ multilingual_sample.wav")

# 6. Noisy audio
generate_noisy('noisy_audio.wav', 3.5, 300, 0.04)
print("✓ noisy_audio.wav")

# 7. Long sentence (shorter version for smaller file size)
durations = [0.4, 0.3, 0.2, 0.5, 0.4, 0.3, 0.4, 0.6, 0.5, 0.4, 0.3, 0.6]
frequencies = [220, 330, 280, 440, 380, 320, 360, 420, 300, 350, 280, 460]
generate_multi_tone('long_sentence.wav', durations, frequencies)
print("✓ long_sentence.wav")

# 8. Error scenario files

# Empty audio (zero duration)
generate_wav('empty_audio.wav', 0.0, 0)
print("✓ empty_audio.wav")

# Too long audio (shorter for testing - 30 seconds instead of 301)
generate_wav('too_long_audio.wav', 30.0, 0)
print("✓ too_long_audio.wav")

# Corrupted audio (invalid WAV header)
os.makedirs('Audio', exist_ok=True)
with open('Audio/corrupted_audio.wav', 'wb') as f:
    f.write(b'\xff\xff\xff\xff\x00\x00')
print("✓ corrupted_audio.wav")

# Unsupported format (fake MP3)
os.makedirs('Audio', exist_ok=True)
with open('Audio/unsupported_format.mp3', 'wb') as f:
    f.write(b'Not a real MP3 file')
print("✓ unsupported_format.mp3")

print("\nAll test audio files generated successfully!")
print("Total files:", len([f for f in os.listdir('Audio') if f.endswith(('.wav', '.mp3'))]))

EOF

echo ""
echo "Test audio generation complete!"
echo "Files are located in: $(pwd)/Audio/"
echo ""
echo "Usage in tests:"
echo "  try TestFixtures.ensureTestAudioFilesExist()"
echo "  let audioURL = TestFixtures.getTestAudioURL(filename: \"hello_world.wav\")"