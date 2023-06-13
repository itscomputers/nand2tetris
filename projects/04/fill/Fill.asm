// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input.
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel;
// the screen should remain fully black as long as the key is pressed.
// When no key is pressed, the program clears the screen, i.e. writes
// "white" in every pixel;
// the screen should remain fully clear as long as no key is pressed.

// Put your code here.
@pixel
M=0

(Loop)
  @24576
  D=M
  @SetPixel
  D;JNE
  @UnsetPixel
  0;JMP

(SetPixel)
  @pixel
  D=M
  @Loop
  D;JNE
  @pixel
  M=-1
  @Draw
  0;JMP

(UnsetPixel)
  @pixel
  D=M
  @Loop
  D;JEQ
  @pixel
  M=0
  @Draw
  0;JMP

(Draw)
  @8192
  D=A
  @remaining
  M=D
  @SCREEN
  D=A
  @loc
  M=D

  (DrawLoop)
    @remaining
    D=M
    @Loop
    D;JLE

    @pixel
    D=M
    @loc
    A=M
    M=D

    @remaining
    M=M-1

    @loc
    M=M+1

    @DrawLoop
    0;JMP

0;JMP
