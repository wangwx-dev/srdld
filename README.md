# 自媒体经营日记

离线的创作者经营。给自己起名，选一套固定的男或女形象，在出租屋里写文章或视频，出门找灵感和梗，用作品的长尾收入交租、还贷。没有账号、广告、联网或排行榜。

当前可玩的是完整循环，不是三十天原型。旧的 `CareerSim` 仍留在仓库里，主场景已经换成 `scenes/play.tscn`。

## 引擎

请使用 **Godot 4.7.2 stable**。

- 发布说明：<https://godotengine.org/article/maintenance-release-godot-4-7-2/>
- 下载：<https://godotengine.org/download/archive/4.7.2-stable/>

## 运行

用 Godot 打开本目录的 `project.godot`，按 F5。

```bash
godot --path .
```

设计分辨率 1280×720。房间是分层的透明图，可以拖动和滚轮缩放。拖过一小段距离不会触发家具。家具上的「创作 / 休息 / 阅读 / 出门」一直显示。

## 一轮里能做什么

- 电脑：写文章或视频，选题材，决定融不融梗、怎么接、打磨多久。一天一篇。往期作品按天继续进账，前几天多，之后是低额长尾，不会在第三天变成 0。
- 本周观众喜爱：每周换一次，写在存档里。榜上的题材更好接，不是必火。
- 出门：城市地图进公园、电影院、商场、图书馆或健身房。健身房只选套餐，没有排课。商场可以买吃的、把床书桌书架换成更好的，或换租、买房。
- 换租和买房会换成第二套房间布局。升级等级跟着走，不留下旧家具，也不能自由摆放。
- 每 7 天结束交一次租。贷款每 14 天一笔，和房租不是同一条规则。付不起就结束。
- 菜单里有三个手动存档槽，另外有一个每日自动档。失败时自动档停在失败那一下。

需求和本版相对基线的纠正写在 [docs/需求基线.md](docs/需求基线.md)。

## 画面

房间层来自 `tools/art/room_sample_v2.blend`，用 `tools/art/export_room_layers.py` 在同一相机下导出。人物不烘进房间。重导出：

```bash
blender --background --python tools/art/export_room_layers.py
```

城市地点是同一套配色下的简洁场景，画在 `scripts/ui/place_view.gd`。说明见 `assets/art/ART.md`。

## 测试

```bash
godot --headless --path . res://tests/test_runner.tscn
```

最后应看到 `FAILURES 0`。测试里会故意喂损坏存档，中途出现 JSON 报错是预期的。自动化检查不能代替进游戏点一遍。

## 导出

安装与 4.7.2 stable 对应的导出模板后：

```bash
mkdir -p builds/windows builds/linux
godot --headless --path . --export-release "Windows Desktop" builds/windows/srdld.exe
godot --headless --path . --export-release "Linux" builds/linux/srdld.x86_64
```

`export_presets.cfg` 没有签名。Windows 优先。

## 已知限制

- 男性和床、阅读、出门姿态来自同一套坐姿模型的换色和刚体挪动。床上看得出是被放倒的坐姿。出门是坐在门边。源文件里没有猫。
- 家具升级是换材质，不是新模型。
- 56 日里，只休息会在账单上失败；稳定发文能留下现金和读者。堆砌多条梗有的种子收入更高，有的更低，不能当成已经调平。
- 不包含移动端、联网、多人、捏脸、自由装修和课程。
