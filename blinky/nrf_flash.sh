#!bin/bash
JLinkExe \
-device NRF52832_XXAA \
-if swd \
-speed auto \
-autoconnect 1 \
-CommanderScript JLinkCommandFile.jlink