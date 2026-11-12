# 自媒体经营日记

独立创作者的第一个月。写稿、发布、看播放和收入，把房租和贷款付掉。全部离线，平台和品牌都是虚构的，没有账号、广告或联网。

「神人大乱斗」只是同城传闻，留到以后的赛季。这一版的胜负只看你能不能过完这 30 天。

## 引擎

请使用 **Godot 4.7.2 stable**。

- 发布说明：<https://godotengine.org/article/maintenance-release-godot-4-7-2/>
- 下载：<https://godotengine.org/download/archive/4.7.2-stable/>

不要用 4.8 测试版，也不要用 3.x。

## 打开和运行

1. 安装 Godot 4.7.2 stable。
2. 用 Godot 打开本目录的 `project.godot`，等它导入字体和图标。
3. 按 F5，或点编辑器右上角的运行。

命令行：

```bash
godot --path .
```

设计分辨率是 1280×720，窗口不能缩得更小。主画面是一间出租屋，大约四分之三的屏幕留给房间和人物。上方只留时间、钱和账单，下方有一排短按钮，方便触控。点书桌、床、门或书架，和点下面那一排是同一件事。

## 画面

房间、人物、床、窗和杂物是为本项目画的风格化 2D，不是外部素材，也不是厚涂原画。可编辑的矢量稿在 `assets/art/`，绘制代码在 `scripts/ui/room_view.gd`。来源说明见 `assets/art/ART.md`。中文字体仍是思源黑体，授权在 `assets/fonts/OFL.txt`。

## 怎么操作

- 用鼠标或触控点房间里的标签，或点下方的短按钮。没有必须悬停才出现的功能。
- 「状态」和「账本」会展开纸条，不挡住整个房间。写稿时会打开一页稿纸。
- `Esc` 暂停。暂停里可以继续、保存、读取、看帮助、重开或回到标题。
- 新游戏会给出一个种子。种子相同、选择相同，结果就相同。
- 发布前先看预计播放和收入。实发结果只会落在写明的区间里。
- 每天最多 3 次行动。结束今天会结算伙食；到期的房租或贷款也在这时扣除。

存档只有一个槽：

- Linux：`~/.local/share/godot/app_userdata/自媒体经营日记/srdld_slot1.json`
- Windows：`%APPDATA%\Godot\app_userdata\自媒体经营日记\srdld_slot1.json`

损坏、版本不对或被改过的存档会被拒绝，并提示原因。

## 测试

安装同一版本的 Godot 后，在仓库根目录执行：

```bash
godot --headless --path . res://tests/test_runner.tscn
```

也可以运行 `tools/test.sh`（它会先导入再测试；脚本里的 `GODOT` 可以指向你的可执行文件）。

测试覆盖：日期和资源变化、收支边界、同一种子可重复、账单金额、失败、胜利、存读档，以及损坏存档。测试过程中如果出现 JSON 解析报错，那是损坏存档用例故意喂进去的，最后应显示 `FAILURES 0`。

## 导出

先安装与 **4.7.2 stable** 完全对应的导出模板。Godot 会把它放在导出模板目录的 `4.7.2.stable` 里。仓库里的 `export_presets.cfg` 有 Windows x86_64 和 Linux x86_64，没有签名证书。

```bash
mkdir -p builds/windows builds/linux
godot --headless --path . --export-release "Windows Desktop" builds/windows/srdld.exe
godot --headless --path . --export-release "Linux" builds/linux/srdld.x86_64
```

Windows 导出会把数据包打进 `srdld.exe`。Linux 导出会打进 `srdld.x86_64`。把对应文件拷走即可运行，不需要再装 Godot。导出的程序不包含签名。

## 文档

- [DESIGN.md](DESIGN.md)：公式和数值为什么这样定
- [ARCHITECTURE.md](ARCHITECTURE.md)：模拟、界面和存档怎么分开
- [ROADMAP.md](ROADMAP.md)：以后的 Android、TapTap 和「神人大乱斗」还缺什么

## 字体

界面使用 Adobe 与 Google 的思源黑体简体常规字重，文件是 `assets/fonts/SourceHanSansCN-Regular.otf`，按 SIL Open Font License 1.1 随游戏分发。全文在 `assets/fonts/OFL.txt`。字体文件保持原样，没有改名或裁字。

## 已知限制

- 只有第一个月，没有第二个月，也没有正式比赛。
- 存档只有一个槽，而且只认版本 1。
- 这一版不做 Android 包，也不接 TapTap。横屏和按钮尺寸是为以后留的。
- 网页版不是这一版的目标。请用 Godot 源码或上面的桌面导出。
