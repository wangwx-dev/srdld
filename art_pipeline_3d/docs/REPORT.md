# Blender 实时 3D 样板 V2 · 双角色与出租屋聚焦精修

生成：2026-11-13T16:24:49.664569+08:00（Asia/Shanghai / UTC+8）  
工作目录：`/workspace/game-art-overhaul/blender-realtime-sample-v2`  
结论：**本轮要求检查 全部通过**。未修改 `wangwx-dev/srdld`，未执行任何仓库操作；V1 原交付清单的 20 项 SHA-256 全部保持不变。城市建筑不是本轮验收对象。

## 1. 先看这五张图

1. `renders/01_characters_turntable_v2.png`：正面、45°斜俯视、正面原图面部精确 200% 放大、真实拓扑。
2. `renders/02_room_isometric_sit_v2.png`：Cycles 坐桌全景；低墙无黑块、书架无遮挡、日间暖光。
3. `renders/03_room_poses_sheet_v2.png`：躺床闭眼、双手持书、摸猫、门前四姿态近景。
4. `renders/04_godot_room_realtime_v2.png`：Godot 4.5.1 加载最新房间与独立女角色 GLB，播放 Sit_Desk 的真实引擎截图；不是 Cycles 冒充。
5. `renders/05_v1_vs_v2_comparison.png`：V1/V2 角色与房间使用相同正交尺度、相同裁切、相同缩放比较。

`REVIEW_OVERVIEW.jpg` 为上述图片索引。原始单张渲染也留在 renders 中。所有图来自 Blender/Godot 实际网格与纹理，面部为手工编写矢量笔触的 2K 贴图，图板只做排版；未使用 AI 生图。

## 2. 双角色：几何、UV、绑定与动作

| 角色 | 导出 GLB tris | 骨骼 | 未赋权顶点 | 重复索引面 | 头身比 | 五官贴图 |
|---|---:|---:|---:|---:|---:|---|
| 女 | 4,832 | 21 | 0 | 0 | 4.713 | 2048² |
| 男 | 4,784 | 21 | 0 | 0 | 4.713 | 2048² |

- 重做比例映射：约 4.71 头身；斜肩、较充实的腰胯、连通衣袖与裤裆。改用自然垂臂绑定姿态，避免旧 A-pose 转垂臂造成肩头球结/尖刺。
- 连通裤腰/双裤腿后重新光顺与预算重拓扑；裤腿逐渐收口，消除旧硬质胯桥。
- 鞋改为圆头鞋面、圆角橡胶包底、后跟包覆、鞋舌和细鞋带，非方盒拖鞋。
- 柔和下颌；2K 眼白/虹膜高光/眉/鼻/嘴/腮红与圆柱 UV 正面区域对齐；背面 UV 接缝不穿正面五官。
- 胸颈、肩肘、胯膝保留归一化混合权重。全角色 0 重复面、0 退化三角，原女模型的 2 个重复索引面已不存在。
- 五条导出动画恰为 `Idle, Sit_Desk, Sleep_Bed, Read_Book, Pet_Cat`；每条都有非恒定骨骼运动，非仅摆静态姿势。另增加 SleepLids 闭眼 morph，与五个 NLA 同名轨道合并，Godot 中仍是五条动作而不是额外杂乱片段。
- 为预算保留简化掌形与拇指，**没有独立手指骨/电影级手部绑定**；生活动作接触由 21 骨与实际表面坐标修整。

## 3. 五条动作接触复测（女、男均跑）

详见 `evidence/contact_qc_v2.json`。最接近表面间隙以实际蒙皮后顶点对目标 BVH 测量，不用骨骼目标点假冒。

- Idle：鞋底离地约 2.90 mm；门前站立无悬空。
- Sit_Desk：双手至键盘表面约 0.35 / 0.10 mm；鞋底离地约 0.99 mm；椅背包围区域内穿入顶点 **0**。椅背后移并压低，保留背部留空。
- Read_Book：左手原先约 55 mm 的空握已修正；最终左/右表面间隙约 0.78 / 0.19 mm。
- Pet_Cat：最近手掌至猫头约 0.85 mm；另一手扶背；脚最低处约 8.01 mm，属于毯面/猫窝旁蹲姿。
- Sleep_Bed：按角色自身比例空间旋转，避免世界空间比例映射拉长身体；整体向枕面移动 25 cm。鞋跟至被面约 0.49 / 0.47 mm；女/男头枕最近间隙约 0.01 / 1.13 mm；男、女根据发型分别调整颈头高度。
- 动画中段只做轻微呼吸、敲键、翻看和抚摸。上述 BVH 最近距离是接触定位指标，**不是全身所有三角之间的通用碰撞证明**；同时逐图人工检查椅背、床、书与猫接触。

复现放置：Sit/Read 根节点 `(0.55,1.82,0)`、Z 旋转 π；Sleep `(-2.6,0.38,0)`；Pet `(-0.4,0.78,0)`；Idle 门前 `(-1,3.1,0)`。以上为 Blender Z-up 坐标。

## 4. 出租屋修复

- 低墙左端并非简单调亮掩盖：去掉前低墙与西侧墙的 20 cm 几何交叠，重算法线并清除场景极小退化倒角。**只裁房间角接实例**；标准库 2m 模块尺寸、`(0,0,0)` 角原点都没移动，房间模块实例仍在 2m 栅格与 90°旋转上。
- 最终放大检查又发现门框顶梁与立柱、窗横框与竖框的共面交叠黑缝；已从几何上缩短立柱/拆分横框为净跨，不再用调光掩盖。修复前放大证据保留在 `evidence/rejected-previews-v2/door_frame_coplanar_before_fix.png`。
- 书架整体沿西墙向开放前侧移 2.75m，全部书格暴露，不再被床头挡住；中间留白、床、桌与门动线保留。
- Cycles：大面积柔光 1800W、暖补光 750W、Sun 2.0、曝光 +0.35；光源为日间柔暖而非夜间橙灯。保留 Poly Haven 木/墙/织物真实 PBR。
- 金属桌架、显示器底座改为中性石墨喷漆 PBR，移除旧锈黄花纹造成的脏感。
- Godot：独立 `render_room.gd` 中 DirectionalLight3D 0.48、暖 Omni 0.18、WorldEnvironment ambient 0.42；Filmic 高光压缩，亚麻材质运行时 albedo `(0.70,0.76,0.78)` 曝光补偿，保留原贴图/法线/粗糙度。Cycles 与 Godot 并非像素完全一致，但均为清楚暖亮的日间室内。

## 5. Godot 与 GLB 真实检查

- Blender 4.5.3 LTS 重新生成 `.blend` 与所有 GLB，再逐个重新导入 Blender 检查骨骼、权重、UV、贴图、动作、重复索引与有限矩阵。
- Godot **4.5.1.stable.official.f62fdbde1** 重新 import；探针加载全部导出 GLB，检查 Skeleton3D / AnimationPlayer / 贴图并播放动作。
- Godot 测试资产与 exports 的 SHA-256 完全一致；未使用旧角色混充新模型。
- 独立 `godot-probe` 的真实 OpenGL Compatibility 路径运行于 Mesa llvmpipe 软件光栅。是实际 Godot 渲染，不是 AI 图片；**不代表目标硬件帧率/性能已经验收**。
- 方案二圆形 4×4 Bayer Dither 原逻辑保留。再次实际编译并渲染，before/after 有 **52,717** 个变化像素；证据 `godot_occlusion_before.png` / `godot_occlusion_after.png`。
- 场景导出中保留一项诊断：旧 Poly Haven 茶几底部倒角有 16 个极小面积三角（平方叉积阈值 1e-18），不是重复索引面，也不在墙角，不形成可见黑块；人物自身此项为 0。没有把此诊断伪报成全场景零退化面。

## 6. 复现入口

- 原生文件：`blender_realtime_sample.blend`（贴图已打包）
- 游戏用候选：`exports/female_rigged.glb`、`exports/male_rigged.glb`、`exports/room_realtime.glb` 与 6 个标准模块。
- 构建：`source/build_sample.py`；面部绘制：`source/paint_faces_v2.py`。
- 渲染：Blender 后台运行 `source/render_sample.py -- characters` / `-- room` / `-- poses`。
- 审计：`source/verify_glb.py`、`source/source_audit_v2.py`、`source/contact_qc_v2.py`。
- Godot：复制 exports/*.glb 至 godot-probe/assets，重新 import，再运行 `probe.gd`、`render_room.gd`、`render_occlusion.gd`。
- 图板：`python3 source/make_boards_v2.py`；报告：`python3 source/write_report_v2.py`。
- 历史 v1 预览与继承证据不作为本轮通过依据；当前依据为 `*_v2` 日志、更新后的 build_audit / glb_reimport / runtime_verification 与本 verification.json。

## 7. 逐项结果

- [x] `v1_deliverables_sha256_unchanged`
- [x] `characters_2000_to_5000_exported_triangles`
- [x] `characters_4_5_to_5_5_head_units`
- [x] `characters_exactly_21_bones`
- [x] `characters_zero_unweighted_vertices`
- [x] `characters_weight_sum_error_below_1e_minus5`
- [x] `all_exports_zero_duplicate_index_faces`
- [x] `characters_zero_degenerate_triangles`
- [x] `five_motion_clips_each`
- [x] `sleep_eyelid_morph_channels_all_five_clips`
- [x] `face_textures_2048_square`
- [x] `library_pivots_zero_error`
- [x] `placed_modules_on_2m_grid`
- [x] `both_character_contacts_within_documented_tolerances`
- [x] `all_glbs_reimport_transport_pass`
- [x] `godot_tested_files_sha256_match_final_exports`
- [x] `godot_all_exports_loaded`
- [x] `godot_21_bones_and_five_clips`
- [x] `godot_real_room_render_finished_no_errors`
- [x] `dither_shader_real_opengl_render_and_changed_pixels`
- [x] `five_required_images_exist`
- [x] `manual_visual_review_recorded`

人工放大审视与迭代记录：`evidence/VISUAL_REVIEW_V2.md`。本轮技术与可视检查通过不等于替用户宣布审美最终通过；此版供双角色与出租屋定向验收，未推进城市美术，也未进游戏代码仓库。
