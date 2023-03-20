''by Gavin T. Garner + Isaac Duke

CON
  _xinfreq=5_000_000
  _clkmode=xtal1+pll16x

  Sout=9                     'P8 sends serial data out to memory chip's Digital In (DI) pin
  clk=10                      'P10 sends synchronous clock pulses to memory chip
  Sin=12                      'P14 receives serial data sent from memory chip's Digital Out (DO) pin
  cs=13                       'P15 controls the Chip Select pin to activate the memory chip

VAR
  long index, MemAddress
  byte data[512]

OBJ
  pst : "PST_Driver"

PUB Main | i, address, value
  'sd.FATEngineStart(0,1,2,3,-1,-1,-1,-1,-1)  'Start SD card driver on Cog 2  sd.FATEngineStart(DOPin, CLKPin, DIPin, CSPin, WPPin, CDPin, RTCReserved1, RTCReserved2, RTCReserved3)
  pst.start

  dira[Sout]~~
  dira[clk]~~
  dira[Sin]~
  dira[cs]~~

  dira[16]~~                                 'Set Pin 16 (which controls blue bar graph's right LED) to be an output
  outa[16]~~                                 'Turn on Pin 16's LED to indicate loading data

  ReadAndWriteTest


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
  repeat ' infinite repeat (keeps chip on



PUB WriteEnable
  SendOneByte($06)

PUB WriteDisable
  SendOneByte($04)

PUB EraseChip
  pst.str(string("Wiping Chip"))
  pst.newline
  WriteEnable                'Allow chip to be changed
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendByte($C7)
  outa[cs]~~                 'Deactivate serial interface
  WaitUntilNotBusy           'Wait until entire chip is erased (~20 seconds)
  pst.str(string("Chip Erased"))
  pst.newline

PUB EraseSector(address)
  WriteEnable                'Allow chip to be changed
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendByte($20)
  SendThreeBytes(address)    'Send 24-bit address
  outa[cs]~~                 'Deactivate serial interface
  WaitUntilNotBusy           'Wait until entire chip is erased (~20 seconds)
  pst.str(string("Sector Erased"))
  pst.newline

PUB Erase32kBlock(address)
  WriteEnable                'Allow chip to be changed
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendByte($52)
  SendThreeBytes(address)    'Send 24-bit address
  outa[cs]~~                 'Deactivate serial interface
  WaitUntilNotBusy           'Wait for block to be erased
  pst.str(string("32KB Block Erased"))
  pst.newline

PUB Erase64kBlock(address)
  WriteEnable                'Allow chip to be changed
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendByte($D8)
  SendThreeBytes(address)    'Send 24-bit address
  outa[cs]~~                 'Deactivate serial interface
  WaitUntilNotBusy           'Wait for block to be erased
  pst.str(string("32KB Block Erased"))
  pst.newline

PUB WaitUntilNotBusy | busybit
  busybit:=1
  repeat until busybit==0
    outa[cs]~                  'Set the chip select pin Low (activate chip)
    SendByte($05)
    busybit:=ReceiveByte
    outa[cs]~~                 'Deactivate serial interface
    busybit:=busybit & 1   'lop off all but LSB (the "busy" status bit)

PUB SendOneByte(databyte)
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendByte(databyte)
  outa[cs]~~                 'Deactivate serial interface
  waitcnt(clkfreq/100+cnt)

PUB WriteOneByte(address,databyte)
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendByte($02)              'Send $02=PageProgram command
  SendThreeBytes(address)    'Send 24-bit address
  SendByte(databyte)         'Send byte of data to write at this address
  outa[cs]~~

PUB StartPageWrite(address)
  WriteEnable
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendByte($02)           'Send $02=PageProgram command
  address:=address & $FF_FF_00    ' lop off last byte to avoid overflow/overwritting
  SendThreeBytes(address)    'Send 24-bit address

PUB StopPageWrite
  outa[cs]~~

PUB StartPageRead(address)
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendByte($03)              'Send $03=ReadData command
  SendThreeBytes(address)    'Send 24-bit address

PUB StopPageRead
  outa[cs]~~

PUB CopyPage(StartAddress,ArrayAddress) | i      'Copy page from chip into an 256 byte array of data
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendByte($03)              'Send $03=ReadData command
  StartAddress:=StartAddress & $FF_FF_00    ' lop off last byte in case given address is not a multiple of 256
  SendThreeBytes(StartAddress)    'Send 24-bit address
  repeat i from 0 to 255
    byte[ArrayAddress][i]:=ReceiveByte
  outa[cs]~~

PUB ReadOneByte(address) : databyte
  outa[cs]~                  'Set the chip select pin Low (activate chip)
  SendByte($03)              'Send $03=ReadData command
  SendThreeBytes(address)
  databyte:=ReceiveByte
  outa[cs]~~

PRI SendByte(databyte) | i
  repeat i from 7 to 0
    outa[Sout]:=databyte>>i
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