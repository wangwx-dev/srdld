# 3D 美术生产管线

这套目录只给后续整合和版本管理用，不接入当前可玩主工程。游戏仍从仓库根目录的 `project.godot` 启动（Godot 4.7.2）。本目录有 `.gdignore`，主工程导入时会跳过这里的脚本、着色器和嵌套工程，不会改 `scenes/` 或 `tests/`。

`.glb`、`.blend`、Poly Haven 贴图、HDRI 和渲染图不要提交。脚本把它们写到本目录的 `textures/`、`exports/`、`renders/`、`evidence/`，这些路径已在 `.gitignore` 里。仓库里只保留脚本、着色器和 `docs/` 的文字记录。

`docs/REPORT.md` 与 `docs/verification.json` 是 2026-11-13 那次 V2 验收的原文。文中的 `source/`、`godot-probe/` 就是现在的 `blender_scripts/`、`godot_dither_probe/`。

## 目录

| 路径 | 内容 |
|---|---|
| `blender_scripts/` | Blender 4.5.3 建模、绑定、2K 面部、接触检测和 GLB 导出 |
| `godot_dither_probe/` | 独立的 Godot 4.5.1 探针，含圆形 4×4 Bayer Dither 着色器 |
| `docs/` | `REPORT.md`、`verification.json`、`VISUAL_REVIEW_V2.md`、`contact_qc_v2.json` |

脚本用 `Path(__file__).resolve().parents[1]` 当作美术工程根，也就是 `art_pipeline_3d/`。在仓库任意位置调用都可以。

## Blender 脚本

需要本机 Blender 4.5.3。纯 Python 的下载和贴图脚本另外需要 `requests` 和 `Pillow`。

按这个顺序做出可检查的样板：

```bash
python3 art_pipeline_3d/blender_scripts/download_assets.py
python3 art_pipeline_3d/blender_scripts/make_textures.py
python3 art_pipeline_3d/blender_scripts/paint_faces_v2.py
blender -b --python art_pipeline_3d/blender_scripts/build_sample.py
blender -b --python art_pipeline_3d/blender_scripts/render_sample.py -- characters
blender -b --python art_pipeline_3d/blender_scripts/verify_glb.py
blender -b --python art_pipeline_3d/blender_scripts/contact_qc_v2.py
```

`render_sample.py` 在 `--` 后面接受 `characters`、`room`、`poses`、`dither`、`city`、`landmarks`。

| 脚本 | 作用 |
|---|---|
| `download_assets.py` | 从 Poly Haven API 拉取 CC0 贴图并核对 MD5，见下一节 |
| `make_textures.py` | 手绘显示器画面、书页，以及一版 1024 面部底图 |
| `paint_faces_v2.py` | 用矢量笔触重画男女 2048² 面部，覆盖上一版脸贴图 |
| `build_sample.py` | 2 米栅格模块、出租屋、双角色（约 4.7 头身、21 骨）、五条动作和 GLB 导出 |
| `pose_utils.py` | 坐桌、睡觉、读书、摸猫、待机的骨骼目标，供渲染和接触检测共用 |
| `render_sample.py` | 打开打包后的 `.blend`，按模式出 Cycles 静帧 |
| `make_boards.py` / `make_boards_v2.py` | 把静帧排成审阅图板 |
| `verify_glb.py` | 重导入 `exports/*.glb`，检查三角面、权重、动作和贴图 |
| `contact_qc_v2.py` | 用蒙皮后的顶点对键盘、书、猫、被子做 BVH 表面间隙 |
| `source_audit_v2.py` | 核对模块栅格、原点和头身比 |
| `audit_scene.py` | 列出场景网格引用的贴图 |
| `check_weights.py` / `check_import_helpers.py` / `inspect_debug.py` / `inspect_v2.py` | 针对已有 `.blend` 或 GLB 的局部检查 |
| `fix_gltf_tints.py` | 把旧 MixRGB 乘色改成 glTF 能保留的 Mix，并重导出 |
| `write_report.py` / `write_report_v2.py` | 在本地构建和证据齐全后重写报告；不是日常入口 |
| `one_off_revision_history/` | 已经写进 `build_sample.py` 的一次性修改。不要再跑，它们会改自己旁边的脚本副本 |

`build_sample.py` 写出 `art_pipeline_3d/blender_realtime_sample.blend`（贴图已打包）和 `art_pipeline_3d/exports/` 下的角色、房间、模块 GLB。五条导出动作是 `Idle`、`Sit_Desk`、`Sleep_Bed`、`Read_Book`、`Pet_Cat`。

## Poly Haven 贴图

`download_assets.py` 走官方 API，不爬网页。许可是 [CC0](https://polyhaven.com/license)。请求带明确 User-Agent，每个文件用 API 给出的 MD5 核对后才写入 `asset_manifest.json`。

```bash
python3 art_pipeline_3d/blender_scripts/download_assets.py
```

它会下载这些资产：

- 2K 的 Diffuse、Roughness、`nor_gl`：`wood_floor`、`painted_plaster_wall`、`denim_fabric`、`dark_wood`、`metal_plate`、`floor_tiles_08`、`asphalt_03`、`grass_ground`、`cotton_jersey`、`rough_linen`、`brown_leather`
- `modern_coffee_table_01` 的 2K glTF，以及清单里的全部依赖
- `studio_small_09` 的 1K HDRI

文件落在 `art_pipeline_3d/textures/<资产名>/`。API 原文记在 `art_pipeline_3d/evidence/<资产名>_files.json`。这两处都不要提交。

## Dither 着色器与 Godot 探针

`godot_dither_probe/` 是单独的 Godot 工程，渲染器为 GL Compatibility。用它自己的 `project.godot` 打开，不要把这些文件拷进游戏的 `scenes/` 或 `scripts/`。

| 文件 | 作用 |
|---|---|
| `circle_dither.gdshader` | 空间着色器。只丢掉比角色焦点更靠近相机、且落在屏幕圆内的遮挡片元。圆内用 4×4 Bayer 矩阵做丢弃，默认去掉约 75% 覆盖，最后 8 像素做边缘过渡。圆外以及角色身后的表面保持原样，并继续采样反照率、粗糙度和法线 |
| `occlusion_driver.gd` | `CircleOcclusionDriver`。每帧把角色焦点的屏幕 UV、视空间深度和像素半径写进指定的 `ShaderMaterial`。只挂墙或树，不挂角色和地面 |
| `probe.gd` | 加载 `res://assets/*.glb`，统计网格、三角面、贴图、骨骼和动画，并确认着色器能加载 |
| `render_room.gd` | 加载房间和女角色 GLB，播放 `Sit_Desk`，写出 `../renders/04_godot_room_realtime_v2.png` |
| `render_occlusion.gd` | 在角色前放一块墙，分别渲染 Dither 关闭和打开，写出 `godot_occlusion_before.png` / `godot_occlusion_after.png` |
| `runtime_verification.json` | 已记录的一次探针结果，不含网格或贴图 |
| `project.godot` | 探针工程配置。主工程不会导入它 |

探针要在本地导出完成之后再跑。GLB 和墙体贴图留在本机：

```bash
cp art_pipeline_3d/exports/*.glb art_pipeline_3d/godot_dither_probe/assets/
godot --headless --path art_pipeline_3d/godot_dither_probe -s probe.gd
godot --headless --path art_pipeline_3d/godot_dither_probe -s render_room.gd
godot --headless --path art_pipeline_3d/godot_dither_probe -s render_occlusion.gd
```

`render_occlusion.gd` 还要在探针目录放 `wall_diff.jpg`、`wall_rough.jpg`、`wall_normal.jpg`（来自 `painted_plaster_wall` 的 2K 贴图）。这些图同样不要提交。

这次探针是在 Godot 4.5.1、OpenGL Compatibility、Mesa llvmpipe 上跑通的。它证明着色器会改变像素，不代表目标机器的帧率。
