CON
  _xinfreq=5_000_000
  _clkmode=xtal1+pll16x         'The system clock is set at 100 MHz (manditory)

  CW = 0
  CCW = 1
  EncA = 2
  EncB = 3
  ProxSensor = 4

  p_gain = 10

OBJ
  pst : "PST_Driver"

VAR
  long DutyCycle, position, target
  long Stack1[100],Stack2[100],Stack3[100],Stack4[100],Stack5[100]

PUB Main

  'pst.start       'Runs on cog 1

  coginit(4,Encoder(EncA,EncB),@Stack4)

  GoHome

  coginit(5,TargetPositions,@Stack5)

  {repeat
    pst.dec(position)
    pst.NewLine
    pst.dec(DutyCycle)
    pst.NewLine
    pst.dec(target)
    pst.NewLine
    waitcnt(clkfreq/10+cnt)     }

pub TargetPositions

  repeat
    {sd.FATEngineStart(0,1,2,3,-1,-1,-1,-1,-1) 'Start SPI assembly code interface for SD communication
    sd.mountPartition(0)                      'Mount the initial, 0th partition
    sd.openFile(string("RAWDATA.TXT"),"R")'Make the "RAWDATA" file the active file & set to W=Write mode
    sd.readLong
    sd.unmountPartition                 'Unmount the initial, 0th partition       }

    target:=-11550                           'CPR 23100
    Go
    waitcnt(clkfreq*2+cnt)
    target:=0
    Go
    waitcnt(clkfreq*2+cnt)
    target:=11550
    Go
    waitcnt(clkfreq*2+cnt)
    target:=23100
    Go
    waitcnt(clkfreq*2+cnt)
    target:=0
    Go
    waitcnt(clkfreq*2+cnt)
    target:=-5775
    Go
    waitcnt(clkfreq*2+cnt)

PUB GoHome

  cogstop(2)
  cogstop(3)
  cogstop(4)
  cogstop(5)
  waitcnt(clkfreq/10+cnt)

  coginit(2,PWM(CW),@Stack2)
  waitcnt(clkfreq*2+cnt)

  repeat until ina[ProxSensor]==0
    DutyCycle:=100

  DutyCycle:=0
  cogstop(2)

  waitcnt(clkfreq*2+cnt)
  coginit(4,Encoder(EncA,EncB),@Stack4)
  coginit(5,TargetPositions,@Stack5)


pub Go

  repeat 3
    if position==target
      return
    elseif position<target
      cogstop(3)'
      DutyCycle:=100
      coginit(2,PWM(CW),@Stack2)
      repeat until position=>target
        DutyCycle:=(10#> ||(position-target)*p_gain <#100)
    elseif position>target
      cogstop(2)
      DutyCycle:=100
      coginit(3,PWM(CCW),@Stack3)
      repeat until position=<target
        DutyCycle:=(10#> ||(position-target)*p_gain <#100)
    DutyCycle~                          'Stop the motor
    waitcnt(clkfreq/200+cnt)            'Allow 5ms for motor to stop spinning

  DutyCycle~
  cogstop(3)
  cogstop(2)


PUB Encoder(A,B)   'Read 2-bit Gray code values from quadrature encoder to keep track of position

  position~   'Reset position variable (could add a routine to move to a limit switch before zeroing)
  repeat
    case ina[B..A]
      %00 : repeat until ina[B..A]<>%00
            if ina[B..A]==%01
               position--
            if ina[B..A]==%10
               position++
      %01 : repeat until ina[B..A]<>%01
            if ina[B..A]==%11
               position--
            if ina[B..A]==%00
               position++
      %11 : repeat until ina[B..A]<>%11
            if ina[B..A]==%10
               position--
            if ina[B..A]==%01
               position++
      %10 : repeat until ina[B..A]<>%10
            if ina[B..A]==%00
               position--
            if ina[B..A]==%11
               position++

PUB PWM(pin) | endcnt           'This method creates a 10kHz PWM signal (duty cycle is set by the global variable named "DutyCycle") clock must be 100MHz

  dira[pin]~~                   'Set the direction of "pin to be an output for this cog
  ctra[5..0]:=pin               'Set the "A pin" of this cog's "A Counter" to be "pin"
  ctra[30..26]:=%00100          'Set this cog's "A counter" to run in single-ended NCO/PWM mode (where frqa always accumulates to phsa and the Apin output state is bit 31 of the phsa value)

  frqa:=1                       'Set counter's frqa value to 1 (1 is added to phsa at each clock)
  endcnt:=cnt                   'Store the current system counter's value as "endcnt"
  repeat
    phsa:=-(100*DutyCycle)      'Send a high pulse for specified number of microseconds
    endcnt:=endcnt+10_000       'Calculate the system counter's value after 100 microseconds
    waitcnt(endcnt)             'Wait until 100 microseconds have elapsed
