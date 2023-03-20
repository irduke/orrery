CON
  _xinfreq=5_000_000
  _clkmode=xtal1+pll16x         'The system clock is set at 100 MHz (manditory)

  CW = 0
  CCW = 1
  EncA = 2
  EncB = 3
  ProxSensor = 4

  p_gain = 10

  Sout=23                     'P9 sends serial data out to memory chip's Digital In (DI) pin
  clk=22                      'P10 sends synchronous clock pulses to memory chip
  Sin=20                      'P12 receives serial data sent from memory chip's Digital Out (DO) pin
  cs=19                       'P13 controls the Chip Select pin to activate the memory chip

OBJ
  pst : "PST_Driver"

VAR
  long DutyCycle, position, index, MemAddress
  long Stack1[100],Stack2[100],Stack3[100],Stack4[100],Stack5[100]
  byte data[512]

PUB Main | address, i, byte_counter, day, day_input

  pst.start       'Runs on cog 1

  dira[Sout]~~
  dira[clk]~~
  dira[Sin]~
  dira[cs]~~

  dira[16]~~                                 'Set Pin 16 (which controls blue bar graph's right LED) to be an output
  outa[16]~~

  coginit(4,Encoder(EncA,EncB),@Stack4)      'Should update position

  pst.str(string("Homing"))
  pst.newline
  GoHome
  repeat 10
    waitcnt(clkfreq+cnt)
    GoTo()
  pst.str(string("We done"))

  'coginit(5,TargetPositions,@Stack5)
  'GoTo(11500)
  {GoTo(ReadBytes($000008, 2))
  waitcnt(clkfreq*2+cnt)
  GoTo(ReadBytes($00016C, 2))
  waitcnt(clkfreq*2+cnt)}


pub ReadDayValue(day) : motor_pos
  motor_pos:=ReadBytes(day*2,2)

pub WriteLookupTable(address)
  if address & 1:
    pst.str(string("Invalid address"))
  else:
    repeat i from 0 to 365
      WriteEnable
      WriteBytes(address, motordata[i], 2)
      WriteDisable
      address:=address+2

pub TargetPositions
  'CPR 23100
  repeat
    GoTo(11550)
    waitcnt(clkfreq*2+cnt)
    GoTo(0)
    waitcnt(clkfreq*2+cnt)
    GoTo(11550)
    waitcnt(clkfreq*2+cnt)
    GoTo(23100)
    waitcnt(clkfreq*2+cnt)
    GoTo(0)
    waitcnt(clkfreq*2+cnt)
    GoTo(5775)
    waitcnt(clkfreq*2+cnt)

PUB GoHome

  cogstop(2)
  cogstop(3)
  cogstop(4)
  'cogstop(5)
  waitcnt(clkfreq/10+cnt)

  coginit(2,PWM(CW),@Stack2)
  waitcnt(clkfreq*2+cnt)

  repeat until ina[ProxSensor]==0
    DutyCycle:=100

  DutyCycle:=0
  cogstop(2)

  waitcnt(clkfreq*2+cnt)
  coginit(4,Encoder(EncA,EncB),@Stack4)
  'coginit(5,TargetPositions,@Stack5)


pub GoTo(target)

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

PUB ReadAndWriteTest | address, value, i
  EraseChip
  '1 Page is 256 bytes
  address:=$AAAAAA
  value:=$CD

  'Basic write test
  pst.str(string("Writing to address: "))
  pst.hex(address, 6)
  pst.str(string(" value: "))
  pst.hex(value, 2)
  pst.newline

  WriteEnable
  WriteOneByte(address, value)
  WriteDisable

  'Read and verify
  pst.str(string("Reading from address: "))
  pst.hex(address, 6)
  pst.str(string(" value: "))
  pst.hex(ReadOneByte(address), 2)
  pst.newline


  'Writing a whole page/past a page fault
  EraseChip
  address:=$000000
  repeat 300
    WriteEnable
    WriteOneByte(address, address)
    address++
    WriteDisable


  address:=$000000
  repeat 300
    i:=ReadOneByte(address)
    pst.str(string("Address "))
    pst.hex(address, 6)
    pst.str(string(" reads: "))
    pst.hex(i, 2)
    pst.newline
    address++

  pst.str(string("Check last 2 hex digits of value with address"))
  pst.newline
  pst.str(string("Test Complete!"))
  pst.newline

PUB WriteEnable
  SendOneByte($06)

PUB WriteDisable
  SendOneByte($04)

PUB EraseChip
  pst.str(string("Wiping Chip"))
  pst.newline
  WriteEnable                'Allow chip to be changed
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendBytes($C7, 1)
  outa[cs]~~                 'Deactivate serial interface
  WaitUntilNotBusy           'Wait until entire chip is erased (~20 seconds)
  pst.str(string("Chip Erased"))
  pst.newline

PUB EraseSector(address)
  WriteEnable                'Allow chip to be changed
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendBytes($20, 1)
  SendThreeBytes(address)    'Send 24-bit address
  outa[cs]~~                 'Deactivate serial interface
  WaitUntilNotBusy           'Wait until entire chip is erased (~20 seconds)
  pst.str(string("Sector Erased"))
  pst.newline

PUB Erase32kBlock(address)
  WriteEnable                'Allow chip to be changed
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendBytes($52, 1)
  SendThreeBytes(address)    'Send 24-bit address
  outa[cs]~~                 'Deactivate serial interface
  WaitUntilNotBusy           'Wait for block to be erased
  pst.str(string("32KB Block Erased"))
  pst.newline

PUB Erase64kBlock(address)
  WriteEnable                'Allow chip to be changed
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendBytes($D8, 1)
  SendThreeBytes(address)    'Send 24-bit address
  outa[cs]~~                 'Deactivate serial interface
  WaitUntilNotBusy           'Wait for block to be erased
  pst.str(string("32KB Block Erased"))
  pst.newline

PUB WaitUntilNotBusy | busybit
  busybit:=1
  repeat until busybit==0
    outa[cs]~                  'Set the chip select pin Low (activate chip)
    SendBytes($05, 1)
    busybit:=ReceiveByte
    outa[cs]~~                 'Deactivate serial interface
    busybit:=busybit & 1   'lop off all but LSB (the "busy" status bit)

PUB SendOneByte(databyte)
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendBytes(databyte, 1)
  outa[cs]~~                 'Deactivate serial interface
  waitcnt(clkfreq/100+cnt)

PUB WriteOneByte(address,databyte)
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendBytes($02, 1)           'Send $02=PageProgram command
  SendThreeBytes(address)    'Send 24-bit address
  SendBytes(databyte, 1)      'Send byte of data to write at this address
  outa[cs]~~

PUB WriteBytes(address,data_bytes, num_bytes)
  'WARNING: DOES NOT ACCOUNT FOR PAGE FAULTS, MUST DO SO MANUALLY
  'Pages are 256 bytes and writing across a page fault will result in overwriting data
  outa[cs]~
  SendBytes($02, 1)
  SendThreeBytes(address)
  SendBytes(data_bytes, num_bytes)
  outa[cs]~~

PUB StartPageWrite(address)
  WriteEnable
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendBytes($02, 1)          'Send $02=PageProgram command
  address:=address & $FF_FF_00    ' lop off last byte to avoid overflow/overwritting
  SendThreeBytes(address)    'Send 24-bit address

PUB StopPageWrite
  outa[cs]~~

PUB StartPageRead(address)
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendBytes($03, 1)          'Send $03=ReadData command
  SendThreeBytes(address)    'Send 24-bit address

PUB StopPageRead
  outa[cs]~~

PUB CopyPage(StartAddress,ArrayAddress) | i      'Copy page from chip into an 256 byte array of data
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendBytes($03, 1)          'Send $03=ReadData command
  StartAddress:=StartAddress & $FF_FF_00    ' lop off last byte in case given address is not a multiple of 256
  SendThreeBytes(StartAddress)    'Send 24-bit address
  repeat i from 0 to 255
    byte[ArrayAddress][i]:=ReceiveByte
  outa[cs]~~

PUB ReadOneByte(address) : databyte
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendBytes($03, 1)          'Send $03=ReadData command
  SendThreeBytes(address)
  databyte:=ReceiveByte
  outa[cs]~~

PUB ReadBytes(address, num_bytes) : datastream
  'Sends data read command and then reads in specified number of bytes
  outa[cs]~
  SendBytes($03, 1)
  SendThreeBytes(address)
  datastream:=ReceiveBytes(num_bytes)
  outa[cs]~~


PRI SendBytes(data_bytes, num_bytes) | i
  repeat i from (num_bytes*8-1) to 0
    outa[Sout]:=data_bytes>>i
    outa[clk]~~              'Input data sampled on rising edge
    outa[clk]~

PRI SendThreeBytes(databytes) | i
  repeat i from 23 to 0
    outa[Sout]:=databytes>>i
    outa[clk]~~              'Input data sampled on rising edge
    outa[clk]~

PRI ReceiveByte : databyte
  databyte~
  repeat 8
    databyte:=databyte<<1+ina[Sin]
    outa[clk]~~              'Input data sampled on rising edge
    outa[clk]~

PRI ReceiveBytes(num_bytes) : datastream
  datastream~
  repeat 8*num_bytes
    datastream:=datastream<<1+ina[Sin]
    outa[clk]~~
    outa[clk]~

DAT
motordata word 0,126,252,378,505,631,757,884,1010,1136,1263,1389,1515,1641,1768,1894,2020,2147,2273,2399,2526,2652,2778,2904,3031,3157,3283,3410,3536,3662,3789,3915,4041,4167,4294,4420,4546,4673,4799,4925,5052,5178,5304,5430,5557,5683,5809,5936,6062,6188,6315,6441,6567,6693,6820,6946,7072,7199,7325,7451,7578,7704,7830,7956,8083,8209,8335,8462,8588,8714,8841,8967,9093,9219,9346,9472,9598,9725,9851,9977,10104,10230,10356,10483,10609,10735,10861,10988,11114,11240,11367,11493,11619,11746,11872,11998,12124,12251,12377,12503,12630,12756,12882,13009,13135,13261,13387,13514,13640,13766,13893,14019,14145,14272,14398,14524,14650,14777,14903,15029,15156,15282,15408,15535,15661,15787,15913,16040,16166,16292,16419,16545,16671,16798,16924,17050,17176,17303,17429,17555,17682,17808,17934,18061,18187,18313,18439,18566,18692,18818,18945,19071,19197,19324,19450,19576,19703,19829,19955,20081,20208,20334,20460,20587,20713,20839,20966,21092,21218,21344,21471,21597,21723,21850,21976,22102,22229,22355,22481,22607,22734,22860,22986,23113,23239,23365,23492,23618,23744,23870,23997,24123,24249,24376,24502,24628,24755,24881,25007,25133,25260,25386,25512,25639,25765,25891,26018,26144,26270,26396,26523,26649,26775,26902,27028,27154,27281,27407,27533,27659,27786,27912,28038,28165,28291,28417,28544,28670,28796,28923,29049,29175,29301,29428,29554,29680,29807,29933,30059,30186,30312,30438,30564,30691,30817,30943,31070,31196,31322,31449,31575,31701,31827,31954,32080,32206,32333,32459,32585,32712,32838,32964,33090,33217,33343,33469,33596,33722,33848,33975,34101,34227,34353,34480,34606,34732,34859,34985,35111,35238,35364,35490,35616,35743,35869,35995,36122,36248,36374,36501,36627,36753,36879,37006,37132,37258,37385,37511,37637,37764,37890,38016,38143,38269,38395,38521,38648,38774,38900,39027,39153,39279,39406,39532,39658,39784,39911,40037,40163,40290,40416,40542,40669,40795,40921,41047,41174,41300,41426,41553,41679,41805,41932,42058,42184,42310,42437,42563,42689,42816,42942,43068,43195,43321,43447,43573,43700,43826,43952,44079,44205,44331,44458,44584,44710,44836,44963,45089,45215,45342,45468,45594,45721,45847,45973,46099