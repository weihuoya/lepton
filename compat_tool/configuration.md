# Environment variables

* ```LEPTON_KEEP_CONTEXT=true``` to keep a context after the container has exited, debug option.
* ```LEPTON_STRACE=true``` to strace the application launched by the container.
* ```LEPTON_DEBUG_LAUNCH=true``` to wait e.g. for gdb before continuing execution after forking, but before launching the app.
* ```LEPTON_GDB_PORT``` to configure the port used by gdb/lldb.
* ```WAYLAND_DISPLAY``` wayland display socket, used only in 2D app mode.
* ```XDG_RUNTIME_DIR``` used to determine the pulseaudio socket.
* ```ENABLE_VULKAN_VALIDATION_LAYER```, ```ENABLE_VULKAN_FDM_INJECTION_LAYER```, ```ENABLE_VULKAN_GFXRECONSTRUCT_LAYER```, ```ENABLE_VULKAN_RPO_LAYER```, ```ENABLE_VULKAN_RENDERDOC_CAPTURE``` can be used to enable the corresponding vulkan layers.  ```ENABLE_VULKAN_VALIDATION_LAYER_LATE``` will perform validation on the application and any other enabled layers, as opposed to only the output from the application itself.
* ```LEPTON_GFXRECON_*``` envvars are translated to their corresponding ```debug.gfxrecon.*``` Android system properties when the gfxreconstruct layer is enabled. Unprefixed ```GFXRECON_*``` envvars are not considered.
* ```VK_INSTANCE_LAYERS``` can be a colon separated list containing vulkan layer names which should be enabled.
* ```LEPTON_FORCE_SOFTWARE``` mostly for gitlab since gpu rendering is not available there.
* ```LEPTON_NO_CONTEXT``` avoid clearing "baked" app data even if it would otherwise be required or recommended. Use with caution and only during development.
* ```LEPTON_LOCK_TIMEOUT``` maximum time to wait for the lepton.lock. This is mostly a debugging/test option.
* ```LEPTON_APP_LAUNCH_TIMEOUT``` maximum time to wait until an app is considered as failed to start.
* ```LEPTON_APP_INSTALL_TIMEOUT``` maximum time in seconds to wait for app installation. Defaults to 600.
* ```LEPTON_DISPLAY_WIDTH``` / ```LEPTON_DISPLAY_HEIGHT``` override the Waydroid physical output size. The original `lepton` defaults are 1280x720; `lepton-rocknix` detects the active Sway output `rect` (rotation included) and falls back to 2560x1440. ROCKNIX fixes Sway scale=1 at system startup, so Lepton does not read or change scale.
* ```LEPTON_DISPLAY_DENSITY``` overrides Android's ```ro.sf.lcd_density``` independently of Sway scale (default: 360 on SM8550).
* ```LEPTON_MESA_DRIVER``` overrides the Mesa gallium driver. The current rootfs uses ```freedreno``` by default.
* ```LEPTON_DATA_LIVE``` overrides the writable /data bind source for rootful containers.
* ```LEPTON_HWUI_VULKAN=1``` opts into HWUI Vulkan for diagnostics; it is not required for Turnip smoke testing.
* ```LEPTON_NO_PORT_FORWARDING``` disable automatic port forwarding. This is mostly a debugging/test option.

* Various other environment variables like ```SteamAppId```, ```STEAM_COMPAT_DATA_PATH```, etc. are used to configure the launch of a game via steam.
* Even more environment variables like, ```EnableFrameEndMarkers```, ```DisableTimelineSemaphoreWait```, ```HTTP_PROXY``` etc. are passed through to the container/app.

# Marker files:
* ```lepton-show-flatscreen``` inside the application depot can be used to configure an application for 2D launch mode.

Enviroment variables of the form:
```LEPTON_ENV_VARNAME=vale``` are passed through to the app as ```VARNAME=value```.

## Standalone（ROCKNIX）

- `LEPTON_STANDALONE=1` skips Steam/SteamVR mounts, Fossilize, mDNS and Perfetto.
  ADB, graphics, input, storage and networking stay enabled. Both modes keep the
  original init files and debugfs/tracing; removing those init operations prevented
  Android system services from starting. The default is `0` for upstream compatibility;
  the device deployment uses `1`.
- In standalone/bridge mode Android uses the fixed bridge DNS `10.0.4.1`. The host
  forwards it to the current upstream DNS and refreshes the DNAT rules when the host
  network changes. Other modes keep the original direct-upstream DNS behavior.
- `LEPTON_LOGCAT_FILTER` defaults to `disable`; set it to `enable` for full Android logs.
- `LEPTON_LOG_DIR` defaults to `~/.local/state/lepton/logs` in standalone mode.
- Mesa/Turnip build configuration and recovery instructions are recorded in
  `../STANDALONE.md` and `../patches/0001-mesa-freedreno-turnip.patch`.

### ROCKNIX 专用入口

`lepton-rocknix` 集中提供 SM8550 的设备默认值，不修改原 `lepton` 的上游行为。它默认
启用 rootful 内核 overlay、standalone、bridge/lnet、bind data、freedreno 和日志精简，
启动前执行 `net-setup.sh`。ROCKNIX 系统已固定 Sway scale=1，入口只读取输出 `rect`
自动适配分辨率（包含旋转），不读取或修改 scale；读取失败回退 2560x1440。

```bash
./lepton-rocknix start       # start dev
./lepton-rocknix attach      # attach dev
./lepton-rocknix stop        # stop dev
```

所有默认值均可由同名环境变量覆盖。`LEPTON_ROCKNIX_PREPARE_NETWORK=0` 跳过网络准备；
`LEPTON_DISPLAY_WIDTH`、`LEPTON_DISPLAY_HEIGHT` 和 `LEPTON_DISPLAY_DENSITY` 可单独指定。
