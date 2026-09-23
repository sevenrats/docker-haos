#!/bin/sh
set -eu

# Runs once per outer-container start, before systemd. Everything that depends
# on the container environment is resolved here; systemd units are static and
# read the result from $runtime_env (systemd does not pass container env vars
# to services).

runtime_env=/etc/haos/runtime.env

is_true() {
  case "$1" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

fail() {
  echo "docker-haos: $*" >&2
  exit 1
}

use_dummy_networkmanager=0
if is_true "${USE_DUMMY_NETWORKMANAGER:-1}"; then
  use_dummy_networkmanager=1
fi

use_udev_shim="${USE_UDEV_SHIM:-auto}"
case "$use_udev_shim" in
  auto|force|off) ;;
  *) fail "unsupported USE_UDEV_SHIM=$use_udev_shim (use auto, force, or off)" ;;
esac

setup_port="${SETUP_PORT:-}"
case "$setup_port" in
  '') ;;
  *[!0-9]*) fail "unsupported SETUP_PORT=$setup_port (use a port number)" ;;
  *) [ "$setup_port" -ge 1 ] && [ "$setup_port" -le 65535 ] || fail "SETUP_PORT=$setup_port is out of range" ;;
esac

compat_docker_args=""
if is_true "${DEV:-0}"; then
  # Mount the live haos-compat code into the compat container.
  compat_docker_args="-v /opt/haos-compat:/opt/haos-compat"
fi

mkdir -p "$(dirname "$runtime_env")"
cat > "$runtime_env" <<EOF
USE_DUMMY_NETWORKMANAGER=$use_dummy_networkmanager
USE_UDEV_SHIM=$use_udev_shim
SETUP_PORT=$setup_port
COMPAT_DOCKER_ARGS=$compat_docker_args
EOF

printf '%s\n' "${TZ:-UTC}" > /etc/timezone

if [ "$use_dummy_networkmanager" -eq 1 ]; then
  ln -sf /dev/null /etc/systemd/system/NetworkManager.service
else
  rm -f /etc/systemd/system/NetworkManager.service
fi

mount --make-rshared /mnt/data

# systemd points PID 1's stdout at /dev/null, so Docker's log pipe is lost once
# it starts. Keep a relay that owns the pipe; haos-log-forward.service
# writes the journal into it. /dev is not remounted by systemd, unlike /run.
# Opening the FIFO read-write means the relay never sees EOF.
log_fifo=/dev/haos-log
rm -f "$log_fifo"
mkfifo -m 0600 "$log_fifo"
cat 0<>"$log_fifo" &

# Force Supervisor to treat each outer-container start as a fresh host boot.
# `/proc/stat` is mirrored from the real host kernel here, so its `btime`
# stays stable across outer-container restarts. Supervisor compares that host
# btime with the persisted /mnt/data/supervisor/config.json last_boot and may
# classify a container restart as "Detected Supervisor restart", skipping
# Home Assistant/add-on boot.
if [ -f /mnt/data/supervisor/config.json ]; then
  if config_json="$(jq '.last_boot = "1970-01-01T00:00:01+00:00"' /mnt/data/supervisor/config.json)"; then
    printf '%s\n' "$config_json" > /mnt/data/supervisor/config.json
  fi
fi

# make rauc to start
if [ -x /usr/bin/grub-editenv ]; then
  mkdir -p /mnt/boot/EFI/BOOT
  if [ ! -f /mnt/boot/EFI/BOOT/grubenv ]; then
    grub-editenv /mnt/boot/EFI/BOOT/grubenv create
  fi
  grub-editenv /mnt/boot/EFI/BOOT/grubenv set A_OK=1
  grub-editenv /mnt/boot/EFI/BOOT/grubenv set A_TRY=0
  grub-editenv /mnt/boot/EFI/BOOT/grubenv set ORDER="A B"
  grub-editenv /mnt/boot/EFI/BOOT/grubenv set B_OK=1
  grub-editenv /mnt/boot/EFI/BOOT/grubenv set B_TRY=0
fi

exec "$@"
