# Lepton standalone（ROCKNIX SM8550）

本目录与 `/storage/lepton` 保存同一份恢复记录。目标是在没有构建工作区、没有上游
仓库的情况下，仍能恢复当前 Android 11 + Mesa/Turnip 构建配置和
standalone 运行方式。

## 1. Mesa 构建配置

`patches/0001-mesa-freedreno-turnip.patch` 来自原 Apple Container 工作区的真实 diff，
包含：

- `BOARD_MESA3D_VULKAN_DRIVERS := freedreno`
- `BOARD_MESA3D_GALLIUM_DRIVERS := freedreno`
- 把 EGL/GLES、libgallium 和 vulkan.freedreno 加入 `PRODUCT_PACKAGES`
- Rosetta 下 `WITH_DEXPREOPT := false`；boot image 由 GitHub CI 的 `package.yml` 生成

当前 release 已包含这些改动，不需要为了运行重新构建 AOSP。

从零恢复构建环境时，在 Lepton fork 根目录执行：

```bash
git submodule update --init image/android_device_waydroid_waydroid
git -C image/android_device_waydroid_waydroid apply \
  ../../patches/0001-mesa-freedreno-turnip.patch

# copy_vendored_projects.sh 会复制到实际构建目录；手工增量续跑则自行复制：
cp image/android_device_waydroid_waydroid/lepton_arm64_only/BoardConfig.mk \
   image/output/device/waydroid/waydroid/lepton_arm64_only/BoardConfig.mk
cp image/android_device_waydroid_waydroid/lepton_arm64_only/lineage_lepton_arm64_only.mk \
   image/output/device/waydroid/waydroid/lepton_arm64_only/lineage_lepton_arm64_only.mk
```

注意补丁应用在**子模块根目录**，不是 Lepton 根目录。补丁中的路径是
`lepton_arm64_only/...`。原生 x86_64 构建可不做 Rosetta 的 dexpreopt  workaround；
本补丁保留了当前 Apple Container 的可复现配置。

Mac 构建环境可用时，可通过 ssh 访问。当前不要求
重新构建，也不依赖 Mac 中的未提交文件。

## 2. standalone 运行配置

`LEPTON_STANDALONE=1` 会跳过 SteamOS 专用的 Steam/SteamVR 挂载、Fossilize、
mDNS 和 Perfetto，并设置 Lepton 自有日志目录。ADB、Turnip、输入设备、存储和网络
保持启用。standalone 与非 standalone 都保留原 `init.rc`、`atrace.rc` 以及
debugfs/tracing 挂载。曾用独立 overlay 删除 tracefs 挂载和 tracing 权限操作，
实测会导致 SurfaceFlinger、installd 等系统服务未启动并等待超时，因此该实验未保留。
standalone 的实际精简边界是跳过宿主调试服务和 SteamOS 组件，而不是删除 Android
启动脚本中的内核接口。fork 默认兼容上游行为（0）；设备部署默认启用（1）。

设备日常命令统一使用随 compat_tool 安装的 `lepton-rocknix`。它集中设置 rootful、
内核 overlay、standalone、bridge、bind data、freedreno、日志和显示默认值，启动前还会
按当前 DNS 重建网络与 NAT 规则。ROCKNIX 启动时已固定 Sway scale=1，入口只读取输出
`rect` 来自动适配 2560x1440 或 1920x1080 等分辨率（已包含旋转），不读取或修改 scale；
读取失败回退 2560x1440，density 默认 360。原 `lepton` 命令及其上游默认行为保持不变。

```bash
cd /storage/lepton
./lepton-rocknix start          # 等价于 start dev
./lepton-rocknix attach         # 以下命令也默认使用 dev
./lepton-rocknix logcat
./lepton-rocknix stop
```

同名环境变量仍可覆盖默认值。`LEPTON_ROCKNIX_PREPARE_NETWORK=0` 可跳过启动前的网络
准备，`LEPTON_DISPLAY_WIDTH` / `LEPTON_DISPLAY_HEIGHT` 可覆盖自动检测的分辨率。
需要调试 Vulkan 层、Steam 或 mDNS 时，显式设置 `LEPTON_STANDALONE=0`，或继续使用原
`lepton` 命令。

## 3. DNS 与日志

standalone/bridge 下 Android 的 `ipconfig.txt` 固定使用 `10.0.4.1`，宿主把
UDP/TCP 53 请求 DNAT 到当前上游 DNS。其他网络模式仍可用 `LEPTON_UPSTREAM_DNS`
显式指定直连 DNS；自动检测优先级为默认路由接口的第一个 IPv4 DNS、默认网关、
`1.1.1.1` 兜底。

`net-setup.sh` 保留出站 masquerade、ADB DNAT 和 DNS DNAT。rockdash-core 每 10 秒
检查宿主默认出口、DNS 与现有规则，只有变化或缺失时才重建 `nat-lepton` 私有表；
因此切换局域网后无需重启 Lepton。

默认 `LEPTON_LOGCAT_FILTER=disable`，减少 logd 输出。调试时改：

```bash
export LEPTON_LOGCAT_FILTER=enable
```

## 4. 自包含内容

`/storage/lepton` 同时保存本文件和 `patches/`。恢复所需配置不依赖上游
lepton 仓库，也不需要保留 AOSP 源码或 70 GB 增量构建缓存。
AOSP 全量重建仍需要相应的构建环境；日常使用直接采用已验证的 final rootfs。
