<div align="center">
  <h1><img alt="Home Assistant" height="48" src="https://cdn.simpleicons.org/homeassistant/41BDF5" /> haos-one</h1>
  <p>Home Assistant Operating System <br /> Single‑Container Docker Image</p>
  <h2>✨ Full HAOS Vibes, Inside Docker ✨</h2>
  <p>Run a fully featured HAOS instance in a single Docker container</p>
  <p>Keep the same experience you’d get on dedicated hardware or a VM.</p>
  <p>
    <h4>
    <a href="https://github.com/hassio-addons">
      <img alt="Add-ons"  src="https://avatars.githubusercontent.com/u/30772201?s=16&v=4" />
      Add-ons supported, no compromises.
    </a>
    </h4>
  </p>
</div>

<p align="center">
  <a href="https://github.com/qweritos/haos-one/releases"><img alt="Release" src="https://img.shields.io/github/v/release/qweritos/haos-one?style=flat-square" /></a>
  <a href="https://github.com/qweritos/haos-one/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/qweritos/haos-one?style=flat-square" /></a>
  <a href="https://github.com/qweritos/haos-one/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/qweritos/haos-one?style=flat-square" /></a>
  <a href="https://github.com/qweritos/haos-one/forks"><img alt="Forks" src="https://img.shields.io/github/forks/qweritos/haos-one?style=flat-square" /></a>
  <a href="https://github.com/qweritos/haos-one/issues"><img alt="Issues" src="https://img.shields.io/github/issues/qweritos/haos-one?style=flat-square" /></a>
  <a href="https://github.com/qweritos/haos-one/commits/main"><img alt="Last Commit" src="https://img.shields.io/github/last-commit/qweritos/haos-one?style=flat-square" /></a>
  <a href="https://artifacthub.io/packages/search?repo=haos-one"><img alt="Artifact Hub" src="https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/haos-one" /></a>
</p>

<br />

- [Run HA OS without sacrificing a whole computer to it.](https://www.home-assistant.io/blog/2025/05/22/deprecating-core-and-supervised-installation-methods-and-32-bit-systems/)
- Avoid VM performance overhead and hypervisor complexity.
- Use host hardware (like USB devices) directly without passthrough.
- Use host networking for service autodiscovery, simpler routing, and lower latency.
- __x86_64__ and __aarch64__ images available.
- Rootless containers support
- Kubernetes? Sure. [Helm chart included](./charts/haos-one).

## How

Simple as one command:

```
docker run -d --name haos --privileged --stop-timeout 120 \
  -p 8123:8123 -v haos-data:/mnt/data qweritos/haos-one
```

Follow progress with `docker logs -f haos`.

> You can pin a specific Home Assistant OS version tag (including prereleases), for example `qweritos/haos-one:17.0.rc2`
For available HAOS versions, see:
https://github.com/home-assistant/operating-system/releases

<p align="">
  <img alt="Intro" src="docs/assets/intro.webp" />
</p>

Replace `-p 8123:8123` with `--network host` if you want host networking (required for autodiscovery features).

`--stop-timeout 120` gives systemd time to stop Home Assistant and its containers cleanly; Docker's default of 10 seconds cuts shutdown short.

Wait for http://localhost:8123 to be available. Now you can create new House or restore from existing backup.

> First startup can take a while as it pulls all required images — please be patient.

## Docker Compose

A ready-to-use [`compose.yaml`](compose.yaml) is included:

```bash
docker compose up -d
docker compose logs -f
```

No `tty` or `stdin_open` is needed.

## Rootless Docker

The same `docker run` / `compose.yaml` works with rootless Docker. The udev shim
(`USE_UDEV_SHIM=auto`) turns on automatically when root is remapped. Host
prerequisites:

- Delegate all cgroup controllers to user sessions, so the nested Docker can manage
  Home Assistant containers:
  ```bash
  sudo mkdir -p /etc/systemd/system/user@.service.d
  printf '[Service]\nDelegate=cpu cpuset io memory pids\n' \
    | sudo tee /etc/systemd/system/user@.service.d/delegate.conf
  sudo systemctl daemon-reload
  ```
  Log out and back in (or restart the rootless Docker daemon) afterwards.
- `--network host` / `network_mode: host` only reaches the rootless network namespace,
  not your LAN, so autodiscovery does not work. Use published ports.
- Publishing host ports below 1024 requires lowering `net.ipv4.ip_unprivileged_port_start`.

## Kubernetes install with Helm 

Install from the OCI registry:

```bash
helm install haos-one oci://registry.andrey.wtf/charts/haos-one
```

Or install from the local chart:

```bash
helm install haos-one ./charts/haos-one
```

Values and configuration options: see [`charts/haos-one/README.md`](charts/haos-one/README.md).

## Migration from deprecated Supervised installation method

### Method 1: Backup restore

- Create a full backup in your existing install (Settings → System → Backups).
- Download the backup to your host.
- Start this container and restore the backup during onboarding.
- Confirm add-ons and integrations come back after restore.

### Method 2: Manual `/usr/share/hassio` copy via host

Making consistent 1:1 clone of your HA instance.

> All commands to be executed from host

Get your `/usr/share/hassio` contents from existing Supervised installation:

```bash
cp -r /usr/share/hassio ./old-config
```

then, push it to new instance:

```bash
docker exec haos sh -c 'mv /mnt/data/supervisor /mnt/data/supervisor.bak && mkdir -p /mnt/data/supervisor'
docker cp ./old-config/. haos:/mnt/data/supervisor/
```

Finally, restart all Home Assistant containers:

```bash
docker exec haos systemctl restart docker
```

## Recipes

- Host networking (best for autodiscovery):
  ```
  docker run -d --name haos --privileged --stop-timeout 120 --network host -v haos-data:/mnt/data qweritos/haos-one
  ```
- Data lives in the volume mounted at `/mnt/data`. To use a host directory instead of a named volume:
  ```
  docker run -d --name haos --privileged --stop-timeout 120 -p 8123:8123 -v ./data:/mnt/data qweritos/haos-one
  ```
- macOS: use a named volume, as in the default command (overlay2 feature gaps with bind mounts).

### Env vars

| Name | Description | Default |
| --- | --- | --- |
| `USE_DUMMY_NETWORKMANAGER` | Disable NetworkManager and enable the dummy responder inside `haos-one-compat` | `1` |
| `USE_UDEV_SHIM` | Inject an idle Supervisor udev monitor when needed (`auto`, `force`, or `off`) | `auto` |
| `SETUP_PORT` | Port Home Assistant serves the onboarding page on. Set empty to keep the Home Assistant default (`80` from 2026.8, `8123` prior — [docs](https://www.home-assistant.io/integrations/http/#server-port)) | `8123` |
| `TZ` | Host time zone written to `/etc/timezone` | `UTC` |
| `DEV` | Used for development purposes - mount live `haos-one-compat` code volume | `0` |

When the udev shim is enabled, upgrading an existing installation automatically
recreates `hassio_supervisor` once if its stored container configuration lacks
the shim. Data in `/mnt/data/supervisor` is preserved.

## Troubleshooting

- Logs (systemd journal, incl. Supervisor, Core and add-ons): `docker logs -f haos`
- HA CLI: `docker exec -it haos ha core info`
- Full journal with explanations: `docker exec -it haos journalctl -xb`
- Container status: `docker exec haos docker ps -a`
- Host shell: `docker exec -it haos sh`

## How it works

See [docs](docs) for details.

## Security Considerations

- Runs with `--privileged`, granting full access between host and container — see [more](https://docs.docker.com/enterprise/security/hardened-desktop/enhanced-container-isolation/#secured-privileged-containers).
- `--network host` exposes services directly on the host network.
- Protect `./data/` because it contains HA configuration and secrets.
- AppArmor may be unavailable depending on your environment.
- A privileged container shares the host kernel, so HAOS services built for bare metal are
  disabled here because they would reconfigure the host: the hardware watchdog
  (an unclean container exit would reboot the host), `systemd-sysctl` (host-global kernel
  settings such as `vm.swappiness` and `kernel.core_pattern`), the swapfile, auditd and
  NTP time setting. Set network sysctls with `docker run --sysctl` / compose `sysctls:` instead.
- AppArmor profiles for add-ons are loaded into the host kernel, as on a regular HAOS host.

## Tested Environments

| OS                             | Arch   | Env                                                         | Status | Notes                |
| ------------------------------ | ------ | ----------------------------------------------------------- | ------ | -------------------- |
| macOS 15.6 (24G84)             | x86_64 | Docker Desktop 4.55.0, Docker Engine 29.1.3 (client/server) | ✅     | AppArmor unavailable; use named volume (see [Recipes](#recipes)). |
| Ubuntu 25.10 (Questing Quokka) | x86_64 | Docker Engine 29.1.3 (client/server) <br />*(rootless & rootfull)*                        | ✅     | —                    |
| Ubuntu 25.10 (Questing Quokka) | x86_64 | Podman 5.4.2                                                | ✅     | —                    |
| Armbian OS 25.02.0 (bullseye) | aarch64 | Docker Engine 28.0.0 (client/server) | ✅ | — |
| Proxmox VE 9.2.2 | x86_64 | Unprivileged LXC running nested Docker Engine 26.1.5+dfsg1 (client/server) <br />*(rootless & rootfull)* | ✅ | - |

## Known Issues

- ~~`--network host` lets HA manage host networking and may cause misconfiguration.~~
`USE_DUMMY_NETWORKMANAGER=1` is enabled by default.
- ~~`"Unsupported system - Network Manager issues"` warning - fix in progress.~~
- ~~`Failed to get outbound IP, retrying in 5s: can't get default interface from Supervisor: {"result":"error","message":"Interface default does not exist"` in journal (with non-host networking) - fix in progress.~~
- ~~Docker Desktop on MacOS becomes inaccessible if run with `--network=host`~~
in-container udev is masked automatically.


## TODOs & Progress:

See [project page](https://github.com/users/qweritos/projects/2) for details.

## License

Apache License 2.0 (see `LICENSE`).

## Disclaimer

Not affiliated with [Home Assistant](https://github.com/home-assistant).
