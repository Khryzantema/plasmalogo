#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Collects system information without root privileges and prints a single
# JSON object on stdout. Every field has its own fallback: if a command or
# file is missing the field is empty ("") and the UI leaves the row out.
# It must never exit with a non-zero status.

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n'
}

field() {
    # $1 = field name, $2 = value (may be empty)
    printf '"%s":"%s"' "$1" "$(json_escape "$2")"
}

clean_os_name() {
    # Some distributions (e.g. Fedora Kinoite/atomic) put a huge build number
    # in the PRETTY_NAME version, like "Fedora Linux 44.45353453 (Kinoite)".
    # This shortens it to "44" but leaves normal versions such as "26.04"
    # (Ubuntu) or "13" (Debian) alone.
    printf '%s' "$1" | sed -E ':a; s/([0-9]+)\.[0-9]{3,}/\1/; ta'
}

clean_gpu() {
    # Shortens the raw lspci line (PCI address, "VGA compatible controller:",
    # full vendor name, "(rev xx)") to something like "NVIDIA GTX 1650" or
    # "Radeon RX 6600", using the marketing name in brackets when lspci has one.
    printf '%s' "$1" | awk '
    {
        line = $0
        sub(/^[0-9a-fA-F]+:[0-9a-fA-F]+\.[0-9a-fA-F]+[ \t]+/, "", line)
        sub(/^(VGA compatible controller|3D controller|Display controller): /, "", line)
        sub(/ \(rev [0-9a-fA-F]+\)[ \t]*$/, "", line)

        last = ""
        s = line
        while (match(s, /\[[^][]*\]/)) {
            last = substr(s, RSTART + 1, RLENGTH - 2)
            s = substr(s, RSTART + RLENGTH)
        }

        if (last != "") {
            split(last, parts, "/")
            name = parts[1]
            sub(/^GeForce/, "NVIDIA", name)
            print name
        } else {
            name = line
            gsub(/NVIDIA Corporation/, "NVIDIA", name)
            gsub(/Advanced Micro Devices, Inc\.?/, "AMD", name)
            gsub(/Intel Corporation/, "Intel", name)
            print name
        }
    }'
}

OS_PRETTY_NAME=""
OS_LOGO=""
if [ -r /etc/os-release ]; then
    OS_PRETTY_NAME=$(. /etc/os-release 2>/dev/null; printf '%s' "$PRETTY_NAME")
    OS_PRETTY_NAME=$(clean_os_name "$OS_PRETTY_NAME")
    OS_LOGO=$(. /etc/os-release 2>/dev/null; printf '%s' "$LOGO")
fi
[ -z "$OS_LOGO" ] && OS_LOGO="computer"

KERNEL=$(uname -r 2>/dev/null)

PLASMA_VERSION=""
if command -v plasmashell >/dev/null 2>&1; then
    PLASMA_VERSION=$(plasmashell --version 2>/dev/null | sed -n 's/^plasmashell \([0-9.]*\).*/\1/p')
fi

SYS_VENDOR=""
PRODUCT_NAME=""
[ -r /sys/class/dmi/id/sys_vendor ] && SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
[ -r /sys/class/dmi/id/product_name ] && PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null)

CPU_MODEL=""
if [ -r /proc/cpuinfo ]; then
    CPU_MODEL=$(sed -n 's/^model name[ \t]*: //p' /proc/cpuinfo | head -n1)
fi

CPU_THREADS=""
if command -v nproc >/dev/null 2>&1; then
    CPU_THREADS=$(nproc 2>/dev/null)
elif [ -r /proc/cpuinfo ]; then
    CPU_THREADS=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
fi

CPU_CORES=""
if command -v lscpu >/dev/null 2>&1; then
    CPU_CORES=$(lscpu -b -p=Core,Socket 2>/dev/null | grep -v '^#' | sort -u | wc -l)
fi
[ -z "$CPU_CORES" ] || [ "$CPU_CORES" = "0" ] && CPU_CORES="$CPU_THREADS"

MEM_TOTAL_GB=""
if [ -r /proc/meminfo ]; then
    MEM_KB=$(sed -n 's/^MemTotal:[ \t]*\([0-9]*\).*/\1/p' /proc/meminfo)
    if [ -n "$MEM_KB" ]; then
        MEM_TOTAL_GB=$(awk -v kb="$MEM_KB" 'BEGIN { printf "%.1f", kb / 1024 / 1024 }')
    fi
fi

GPU=""
if command -v lspci >/dev/null 2>&1; then
    GPU_RAW=$(lspci 2>/dev/null | grep -iE 'vga compatible controller|3d controller' | head -n1)
    [ -n "$GPU_RAW" ] && GPU=$(clean_gpu "$GPU_RAW")
fi

DISK_USED=""
DISK_TOTAL=""
if command -v df >/dev/null 2>&1; then
    # Space of the partition holding the user's home folder (may differ from
    # "/" when /home is on its own disk or partition).
    DISK_LINE=$(df -h "${HOME:-/}" 2>/dev/null | tail -n1)
    DISK_TOTAL=$(printf '%s' "$DISK_LINE" | awk '{print $2}')
    DISK_USED=$(printf '%s' "$DISK_LINE" | awk '{print $3}')
fi

HOSTNAME_VAL=""
if command -v hostname >/dev/null 2>&1; then
    HOSTNAME_VAL=$(hostname 2>/dev/null)
elif [ -r /etc/hostname ]; then
    HOSTNAME_VAL=$(cat /etc/hostname 2>/dev/null)
fi

UPTIME_VAL=""
if command -v uptime >/dev/null 2>&1; then
    UPTIME_VAL=$(uptime -p 2>/dev/null)
fi
if [ -z "$UPTIME_VAL" ] && [ -r /proc/uptime ]; then
    SECS=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
    if [ -n "$SECS" ]; then
        UPTIME_VAL=$(awk -v s="$SECS" 'BEGIN {
            d = int(s / 86400); h = int((s % 86400) / 3600); m = int((s % 3600) / 60)
            printf "%dd %dh %dm", d, h, m
        }')
    fi
fi

# Uptime in seconds, so the QML side can build a translated text.
UPTIME_SECS=""
if [ -r /proc/uptime ]; then
    UPTIME_SECS=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
fi

printf '{'
printf '%s,' "$(field os_pretty_name "$OS_PRETTY_NAME")"
printf '%s,' "$(field os_logo "$OS_LOGO")"
printf '%s,' "$(field kernel "$KERNEL")"
printf '%s,' "$(field plasma_version "$PLASMA_VERSION")"
printf '%s,' "$(field sys_vendor "$SYS_VENDOR")"
printf '%s,' "$(field product_name "$PRODUCT_NAME")"
printf '%s,' "$(field cpu_model "$CPU_MODEL")"
printf '%s,' "$(field cpu_cores "$CPU_CORES")"
printf '%s,' "$(field cpu_threads "$CPU_THREADS")"
printf '%s,' "$(field mem_total_gb "$MEM_TOTAL_GB")"
printf '%s,' "$(field gpu "$GPU")"
printf '%s,' "$(field disk_used "$DISK_USED")"
printf '%s,' "$(field disk_total "$DISK_TOTAL")"
printf '%s,' "$(field hostname "$HOSTNAME_VAL")"
printf '%s,' "$(field uptime "$UPTIME_VAL")"
printf '%s' "$(field uptime_seconds "$UPTIME_SECS")"
printf '}\n'
