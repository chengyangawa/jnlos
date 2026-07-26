#!/bin/bash
cd "/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS"
ISO="./out/jnl-os-2026.07.02-x86_64.iso"
rm -rf /tmp/isocheck
mkdir -p /tmp/isocheck

echo "=== Extracting loader/ ==="
xorriso -osirrox on -indev "$ISO" -extract /loader /tmp/isocheck/loader 2>&1 | tail -3

echo ""
echo "=== Extracting boot/ ==="
xorriso -osirrox on -indev "$ISO" -extract /boot /tmp/isocheck/boot 2>&1 | tail -3

echo ""
echo "=== All files found ==="
find /tmp/isocheck -type f

echo ""
echo "=== All .conf file contents ==="
for f in $(find /tmp/isocheck -name "*.conf"); do
  echo "--- $f ---"
  cat "$f"
  echo ""
done

echo ""
echo "=== ISO label ==="
xorriso -indev "$ISO" -pvd 2>&1 | grep -iE "volume|label"
