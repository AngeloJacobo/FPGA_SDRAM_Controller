Created by: Angelo Jacobo   
Date: August 12,2021   

# Inside the src folder are:   
* sdram_controller.v -> Controller for Synchronous Dynamic RAM. Specs are given below.  
* comprehensive_tb.v -> Tests the sdram controller by writing to all 2^24 addresses of SDRAM then reading it all back.  
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp; - key[0] writes deterministic data to all addresses  
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp; - key[1] reads data from all addresses and check if the data follows the predetermined pattern  
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp; - key[2] injects 10240 errors when pressed along with key[0]   
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp; - number of errors read will be displayed on the seven-segment LEDs  
# UML Chart [SDRAM Controller Sequence]:
![SDRAM](https://user-images.githubusercontent.com/87559347/129528537-fcd08e70-c3e5-4879-a331-bf02b3d201fb.jpg)


# UML Chart [Test Sequence]:
![SDRAM_TEST](https://user-images.githubusercontent.com/87559347/129528806-16a8d61e-f88c-4729-81a6-bb7e25a5429a.jpg)


# About:  
This project implemented a controller for the SDRAM mounted on  AX309 FPGA development board (i.e. Winbond W9825G6KH SDRAM)
Specs of the controller are:   

* Memory bandwidth is 316MB/s **(can be checked by looking at the value of index_q register on chipscope)**
* Burst mode is "Full page" **(i.e. burst of 512 words every read and write)**
* Clock input must be 165MHz
* Auto-precharged is disabled **(illegal for 165MHz clk)**
* Clock latency of 3 **(CL=2 is illegal for 165MHz clk)**
* All banks are closed every refresh **(in short no interleaving)**
* Parameters can be configured on sdram_controller.v to suit any kind/brand of sdram device

# Donate   
Support these open-source projects by donating  

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=GBJQGJNCJZVRU)


# Inquiries  
Connect with me at my linkedin: https://www.linkedin.com/in/angelo-jacobo/
