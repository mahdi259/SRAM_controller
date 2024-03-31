Here is a simple SRAM controller written in VHDL. The target SRAM is IS61WV5128BLL-10TI which features 512KB space.
SRAM pins:

ADDRESS   : 19 bits

DATA      : 8 bits

CE        : 1 bit  --Active low chip enable

OE        : 1 bit  --Active low output enable

WE        : 1 bit  --Active low write enable


This SRAM controller is only checked in simulation environment and should be further checked for physical implementation. The interface for this controller is wishbone. 
