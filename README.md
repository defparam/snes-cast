# SNES-Cast 0.1 Alpha
An FPGA-based SNES graphics rendering solution

SNES-Cast is an FPGA based digital graphic render system for the SNES. SNES-Cast uses the SNES-Tap Rev A board to tap
into the SNES graphics unit through the expansion port on the bottom of the console. The data and address bus go
through level translation and are processed through an FPGA. For 0.1 Alpha we use a Terasic DE0-Nano board. Then the
FPGA interfaces to an FTDI FT245 USB 2.0 transciever chip in 8-bit FIFO mode to send graphics data to a modified
version of Snes9x. Snes9x is used in this prototype for its emulated PPU and its canvas drawing support. Our modified
Snes9x emulator reads actual graphics data from the SNES console and uses the emulated PPU/Canvas to render the video.

The goal of this project is to eventually tap all of audio/video data from an SNES console and render it directly to
HDMI without using emulator software. The emulation test was used as a proof of concept to prove the functionality/theory of
SNES-Tap/SNES-Cast.

@defparam
