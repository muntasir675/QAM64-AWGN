# QAM64-AWGN

64-QAM over AWGN simulation in MATLAB — constellation analysis, BER curve, and 16QAM comparison.

Three sections in one script:
- **Constellation analysis** — Gray-coded 64QAM with scatter plots at Eb/N0 = 0–20 dB, lowpass and passband PSD
- **BER curve** — Monte Carlo simulation from 0–20 dB with theoretical overlay
- **16QAM comparison** — BER vs 64QAM with power-efficiency delta at target BER

Includes an interactive GUI that shows the constellation sharpen/cloud as you slide Eb/N0.

## Files

| File | Description |
|---|---|
| `QAM64_sim.m` | Full simulation script (run in MATLAB) |
| `QAM64_interactive.m` | Interactive slider GUI for real-time constellation view |
