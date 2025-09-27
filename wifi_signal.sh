#!/bin/bash
# Get RSSI and Noise values using wdutil.
rssi=$(sudo /usr/bin/wdutil -i info | grep RSSI | awk '{print $3}')
noise=$(sudo /usr/bin/wdutil -i info | grep Noise | awk '{print $3}')

if [[ -z "$rssi" || -z "$noise" ]]; then
  echo "Could not retrieve RSSI or Noise value."
  exit 1
fi

# Calculate SNR: RSSI - Noise (note: subtracting a negative adds).
snr=$(( rssi - noise ))

echo " "
echo "-- wifi signal quality --"
#echo "RSSI: ${rssi} dBm"
#echo "Noise: ${noise} dBm"
#echo "SNR: ${snr} dB"

# Determine SNR quality.
#if (( snr >= 40 )); then
#    echo "SNR Quality: Excellent signal"
#elif (( snr >= 30 )); then
#    echo "SNR Quality: Very good signal"
#elif (( snr >= 20 )); then
#    echo "SNR Quality: Acceptable signal"
#else
#    echo "SNR Quality: Weak signal"
#fi

# Get the MCS index using wdutil.
mcs=$(sudo /usr/bin/wdutil -i info | grep -i MCS | awk '{print $4}')

if [[ -z "$mcs" ]]; then
  echo "MCS index information not available."
else
  echo "MCS Index: ${mcs}"
  # Assuming a device with Wi-Fi 6 support (MCS 0-11)
  if (( mcs >= 10 )); then
      echo "MCS Quality: Excellent"
  elif (( mcs >= 7 )); then
      echo "MCS Quality: Good"
  else
      echo "MCS Quality: Weak"
  fi
fi
echo " "

