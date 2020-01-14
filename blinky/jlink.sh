#!/bin/bash
# Segger JLink setup script
# Used for flashing and erasing nRF52832 (SWD) devices
# NOTE: Only tested with a Segger JLink on Linux
# Uses TMPSCRIPT to generate/run batch script

# Expected exported variables
# FIRMWARE  - Path to firmware image to flash (flash)
# ADDRESS   - Starting address to flash firmware from (flash)
# DEVICE    - Name of the chip series

# Modes
# flash_blank - Flashes given firmware blank
# flash_s132 - Flashes given firmware s132
# erase - Erases chip
FIRMWARE_BLANK="pca10040/blank/armgcc/_build/nrf52832_xxaa.hex"
FIRMWARE_S132="pca10040/s132/armgcc/_build/nrf52832_xxaa.hex"
FIRMWARE_S132_MERGED="pca10040/s132/armgcc/_build/nrf52832_xxaa_merged.hex"
SOFTDEVICE="${NRF5_SDK}/components/softdevice/s132/hex/s132_nrf52_7.0.1_softdevice.hex"
ADDRESS="0x0"
DEVICE="NRF52832_XXAA"

TMPSCRIPT="/tmp/JLinkCommandFile.jlink"

# Find actual directory of this script and enter it
ORIG_PATH=$(pwd)
# FIRMWARE=${ORIG_PATH}/${FIRMWARE}
cd "$(dirname $(realpath "$0"))"

# Make sure ADDRESS is in hex
ADDRESS=$(printf "0x%x" $((${ADDRESS})))

# Function flash firmware
flash_firmware() {
	FIRMWARE=$1
	# Generate commander script
	echo "
sleep 10
rx 10
loadfile ${FIRMWARE} ${ADDRESS}
rx 10
q
" >"${TMPSCRIPT}"
	cat ${TMPSCRIPT}
	JLinkExe -Device "${DEVICE}" -If swd -Speed auto -Autoconnect 1 -CommanderScript "${TMPSCRIPT}"
	sleep 0.5 # Wait for Device/USB to initialize before continuing
}

# Check mode
case "$1" in
# Flash_blank Mode
"flash_blank")
	FIRMWARE=${ORIG_PATH}/${FIRMWARE_BLANK}

	flash_firmware ${FIRMWARE}
	RETVAL=$?
	;;

	# Flash_s132 Mode
"flash_s132")
	FIRMWARE=${ORIG_PATH}/${FIRMWARE_S132_MERGED}
	mergehex -m ${ORIG_PATH}/${FIRMWARE_S132} ${SOFTDEVICE} -o ${FIRMWARE}

	flash_firmware ${FIRMWARE}
	RETVAL=$?
	;;

	# Erase Mode
"erase")
	# Generate commander script
	echo "
sleep 10
rx 10
erase
q
" >"${TMPSCRIPT}"
	cat ${TMPSCRIPT}

	# Attempt to erase
	# Udev rules are required to run commands without root priviledges (see 99-jink.rules)
	JLinkExe -Device "${DEVICE}" -If swd -Speed auto -Autoconnect 1 -CommanderScript "${TMPSCRIPT}"

	RETVAL=$?
	;;

	# Reset to bootloader mode
"bootloader")
	# Generate commander script
	echo "Comming soon!"
	RETVAL=$?
	;;

	# Reset Mode
"reset")
	# Generate commander script
	echo "
r
q
" >"${TMPSCRIPT}"
	cat ${TMPSCRIPT}
	# Attempt to reset chip to bootloader
	# Udev rules are required to run commands without root priviledges (see 99-jink.rules)
	JLinkExe -Device "${DEVICE}" -If swd -Speed auto -Autoconnect 1 -CommanderScript "${TMPSCRIPT}"

	RETVAL=$?
	;;

# Invalid Mode
*)
	echo "ERROR: '$1' is an invalid mode"
	RETVAL=1
	;;
esac

echo "NOTE: jlink does not indicate cabling failures, here are some indicators"
echo "USB Cable Problem      -> 'Can not connect to J-Link via USB.'"
echo "Flashing Cable Problem -> 'VTarget = 0.000V'"
echo "                          'WARNING: RESET (pin 15) high, but should be low. Please check target hardware.'"
echo "                          'Downloading file [kiibohd_bootloader.bin]...Writing target memory failed.'"
echo ""

# Error occurred, show debug
if [ "$RETVAL" -ne "0" ]; then
	echo ""
	# Debug info
	echo "FIRMWARE BLANK:       '$FIRMWARE_BLANK'"
	echo "FIRMWARE S132:        '$FIRMWARE_S132'"
	echo "FIRMWARE S132 MERGED: '$FIRMWARE_S132_MERGED'"
	echo "SOFTDEVICE:           '$SOFTDEVICE"
	echo "ADDRESS:              '$ADDRESS'"
	echo "DEVICE:               '$DEVICE'"
	echo "TMPSCRIPT:            '$TMPSCRIPT'"
	echo "CWD:                  '$(pwd)'"
fi

exit $RETVAL
