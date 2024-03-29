# Raspberry pi: serial_comm_binary.py
# Arduino: sketch_serial_comm.ino
# single byte (unsigned character) binary communication from Raspberry pi and Arduino
#!/usr/bin/python2

import serial
import time
import struct

ser = serial.Serial('/dev/ttyACM0',9600,timeout=1)

while 1:
  if(ser.inWaiting()):
     readBytes = ser.read(1) # read data from serial port

     # receive data from Arduino
     # data type  =>  b:signed char, B:unsigned char
     # receive data in Python Tuple
     decodedData = struct.unpack_from('B',readBytes) # python tuple
     print('decoded byte from Arduino : %d' %(decodedData[0]))  
     ser.write(b'A') # send 'A' to Arduino
   time.sleep(0.25)
