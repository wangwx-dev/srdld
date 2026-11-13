from pathlib import Path
import json,hashlib,datetime
from PIL import Image
P=Path(__file__).resolve().parents[1]
load=lambda n:json.loads((P/n).read_text())
a=load('evidence/build_audit.json');g=load('evidence/glb_reimport.json');manifest=load('asset_manifest.json');scene=load('evidence/scene_assets.json');godot=load('godot_dither_probe/runtime_verification.json')
for f in manifest['files']:
 f['md5_actual']=hashlib.md5((P/f['path']).read_bytes()).hexdigest();f['md5_match']=f['md5_actual']==f['md5_expected']
images={}
for f in sorted((P/'renders').glob('*.png')):
 if f.name.startswith('test_'):continue
 im=Image.open(f);images[f.name]={'size':list(im.size),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size}
for f in (P/'exports').glob('*.glb'):g[f.name]['sha256']=hashlib.sha256(f.read_bytes()).hexdigest()
checks={'source_md5_all_match':all(f['md5_match'] for f in manifest['files']),'source_file_count':len(manifest['files']),'module_origins_exact_grid_zero_error':all(all(v==0 for v in x['origin_grid_error_m']) for x in a['modules']),'character_triangle_budget':all(2000<=g[f'{s}_rigged.glb']['glb_triangles']<=5000 for s in ['male','female']),'all_glbs_transport_checks':all(x['passed_transport_checks'] for x in g.values()),'both_characters_21_bones':all(list(g[f'{s}_rigged.glb']['reimported_bones'].values())==[21] for s in ['male','female']),'character_render_skin_unweighted_vertices_zero':all(g[f'{s}_rigged.glb']['unweighted_vertices']==0 for s in ['male','female']),'five_real_motion_actions_each':all(len(g[f'{s}_rigged.glb']['animation_motion'])==5 and all(x['genuine_motion_not_just_hold'] for x in g[f'{s}_rigged.glb']['animation_motion'].values()) for s in ['male','female']),'godot_tested_binaries_match_final_exports':all(hashlib.sha256(f.read_bytes()).digest()==hashlib.sha256((P/'godot_dither_probe/assets'/f.name).read_bytes()).digest() for f in (P/'exports').glob('*.glb')),'all_glbs_load_in_godot':all(x['loaded'] for n,x in godot.items() if n.endswith('.glb')),'shader_resource_and_real_gl_render':godot['shader']['resource_loaded'] and 'REAL_GODOT_DITHER_RENDER_FINISHED' in (P/'evidence/godot_visual.log').read_text(),'six_required_review_boards_1920x1080':all(images[n]['size']==[1920,1080] for n in ['01_characters_turntable.png','02_room_isometric_sit.png','03_room_poses_sheet.png','04_dither_occlusion_preview.png','05_city_overview_isometric.png','06_before_after_comparison.png'])}
quality={'technical_pass':all(v for v in checks.values() if isinstance(v,bool)),'visual_gate':'NOT_APPROVED_FOR_GAME_INTEGRATION','integration_allowed':False,'reason':'Technical pipeline is implemented and verified. Faces/hair, close-up hands, cat anatomy, cloth tailoring and city architectural identity remain prototype-level; do not represent this as a production-quality art replacement. Contact poses are FK proofs, not final contact-constrained animation.','repository_modified':False,'ai_generated_images_used':False,'review':'All six main boards and unretouched 200% crops were read visually; several modelling/export issues were corrected and rerendered.'}
v={'time_asia_shanghai':datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')+' UTC+08:00','blender_version':a['blender'],'godot_version':'4.5.1.stable.official.f62fdbde1','renderer':'Cycles CPU for Blender; Mesa llvmpipe OpenGL compatibility for Godot diagnostics','camera':{'projection':'orthographic','azimuth_degrees':45,'elevation_degrees':45,'note':'45-degree-down pseudo-isometric per brief, not mathematical isometric 35.264 degrees'},'checks':checks,'quality_gate':quality,'character_source_stats':a['characters'],'module_audit':a['modules'],'glb_reimport':g,'godot_runtime':godot,'poly_haven_manifest':manifest,'scene_mesh_assets':scene,'renders':images}
(P/'verification.json').write_text(json.dumps(v,ensure_ascii=False,indent=2))
module_rows='\n'.join('| '+m['name']+' | '+str([round(x,6) for x in m['bbox_size']])+' | (0,0,0) | 0 |' for m in a['modules'])
check_rows='\n'.join(f'- `{k}`: **{val}**' for k,val in checks.items())
report=f'''# Blender → GLB → Godot 实时 3D 首轮技术样板

更新时间：{v['time_asia_shanghai']}（北京时间 / Asia/Shanghai）。

## 先看结论：技术链路落地，但**不批准进入游戏仓库**

这不是“美术终验全部通过”的报告。真实 PBR、模块原点、4.5k 三角面双角色、绑定、五条有实际运动的动作、GLB 重导以及 Godot 实际渲染已经完成；但放大检查后，**人物发型/服装/手部与猫的造型仍偏原型，尚不足以承诺“高质量最终美术”**。城市建筑也仍是可识别的模块骨架，而非精修街区。故 `integration_allowed=false`，未修改 `wangwx-dev/srdld` 或其他游戏仓库。

没有使用 AI 生图，没有上传人物到 Mixamo，没有付费购买。建模、骨骼、权重、动作与主预览全部本地 Blender 制作。现成 Poly Haven 咖啡桌作为已校验 CC0 道具使用，其余主要几何为本轮自建。

## 快速审阅

- `REVIEW_OVERVIEW.jpg`：六张主图总览。
- `renders/01_characters_turntable.png`：男女正面、45°、真实网格/骨骼叠加与面部像素放大。
- `renders/02_room_isometric_sit.png`：房间、坐电脑桌、正面可见的大显示器。
- `renders/03_room_poses_sheet.png`：躺床、持书、逗猫、门前；四张原始 1080p 分图同目录保留。
- `renders/04_dither_occlusion_preview.png`：上排 Blender 真实网点透明材质，下排 **Godot 真实渲染** 的 4×4 Bayer discard，不是后期贴圆圈。
- `renders/05_city_overview_isometric.png`：道路、河桥、家/影院/图书馆/健身房/商场/公园入口六地标。
- `renders/06_before_after_comparison.png`：左为真实旧 Godot 截图，右为本次 Blender 样板。**仅归一到相近屏幕占幅，不是同房间尺寸/同光照/同物理尺度的基准测试**。
- `renders/07_godot_room_realtime.png`：独立 Godot 工程内，加载场景 GLB + 独立女角色并播放 `Sit_Desk` 的实机诊断。光照没有冒充 Cycles 同等效果。
- `renders/city_*.png`：六个地点分别出图；不是一张拥挤地图代替全部地点。
- `qc/*_200pct.png`：没有重绘、没有补细节的真实渲染裁切放大。

主审阅图均为 1920×1080。相机方位 45°、俯视 45°、正交；这是用户选定的 Pseudo-3D，不是数学等距的 35.264° 俯角。Blender 4.5.3 Cycles 32 samples + denoise，统一 HDRI 和暖阳；地点细图为 8 samples。

## Poly Haven：真实源文件、完整下载和 MD5

- API User-Agent：`{manifest['user_agent']}`。
- 原始文件共 **{len(manifest['files'])} 个**，约 **{sum(x['bytes'] for x in manifest['files'])/1e6:.2f} MB**，每个 API 声明 MD5 与本地 MD5 完全一致；详见 `asset_manifest.json`，无“只存网址没下载”。
- 2K 真实贴图：`wood_floor`、`painted_plaster_wall`、`denim_fabric`、`dark_wood`、`metal_plate`、`floor_tiles_08`、`asphalt_03`、`grass_ground`、`cotton_jersey`、`rough_linen`、`brown_leather`。每套均备好 Diffuse / Rough / OpenGL Normal；denim 与皮革保留为备选，主衣服使用无接缝的大幅棉布/亚麻。
- 实际房间模块与家具采用明确的 UV，BaseColor/Roughness/Normal 接入 Principled。Normal 与 Roughness 均 Non-Color。屏幕内容、面部与纸页为手绘图形纹理；皮肤、头发、植物叶、猫毛等有机材质仍为简化材质，是待精修项，不能称全场景写实。
- `modern_coffee_table_01` 下载 GLTF、BIN 与全部依赖纹理，逐件核对 MD5；`studio_small_09` 为 1K HDRI 光照（不冒充 2K 材质）。
- 授权：[Poly Haven CC0](https://polyhaven.com/license)。使用 API 而非爬图库，API 明确 UA 已设置。`evidence/*_files.json` 保留各资产原始文件元数据。

## 模块尺寸与原点

单位 1 Blender unit = 1 m。六个库模块原点均 **精确 (0,0,0)**，按网格角策略；房间铺装以 2m 递增放置。地面原点在 z=0 铺装表面的网格角，厚度向下延伸 0.12m，便于引擎统一地平面。

| 模块 | 完整包围盒尺寸 m（含窗台/踢脚/门把手） | 库原点 | 栅格原点偏差 m |
|---|---|---|---|
{module_rows}

宽度 2m、后墙高度 3m、矮墙高度 0.5m 与内角 2×2×3m 均满足名义网格；窗台与踢脚有真实凸出，不把它们谎报成没有厚度的平面。浮点数中 0.12m 可能记作 0.1199999973，**不等于原点漂移**。源网格与所有物体的逐件面数/UV/原点详见 `verification.json > scene_mesh_assets`。

## 双角色：不是胶囊网格，也不是下载高模直接减面顶数

| 角色 | 最终 GLB 三角面 | Blender 四边面 | 顶点 | 骨骼 |
|---|---:|---:|---:|---:|
| 女 | 4504 | 1452 | 2337 | 21 |
| 男 | 4668 | 1507 | 2423 | 21 |

- 头部环线、内嵌小鼻形、圆柱展开面部纹理；不是球鼻子。头颈、躯干、裤腿、脚、手掌、四指轮廓与拇指分别建拓扑。发型为整体壳与宽片层次，未使用香肠发束。
- 初版尖肩/套筒袖在 Read 检查后被否决，肩部与躯干现融合成连续衣壳，并重新减面保持预算。此拓扑仍需人物美术继续手工精修，不能冒充专业重拓扑成品。
- 本地建立 21 骨标准人型，含 `Hips/Spine/Chest/Neck/Head/LeftShoulder/LeftArm/LeftForeArm/LeftHand/LeftUpLeg/LeftLeg/LeftFoot/LeftToeBase` 及右侧；Blender automatic heat weights 已运行，再按肩/肘/髋/膝/颈的渐变带修整并归一化权重。没有指骨、面部表情骨；当前是生活动作所需的基础全身骨架，不是影视全控绑定。
- 五条导出动作：Idle、Sit_Desk、Sleep_Bed、Read_Book、Pet_Cat。1/25/49 帧有关键帧，循环有呼吸、轻微手部打字、头部阅读扫视或抚摸运动；GLB 二进制检查确认每条都有非恒定动画通道，不是只命名的静帧。女模型 GLB 的 4504 个索引三角中有 2 个重复索引面，Blender 重导会去重，得到 4502；二进制逐面检查已证实不是 2 个零面积三角。该清理项保留为后续拓扑修订，不把它藏在统计里。
- GLB 重新导入 Blender 后检查骨架层级、加载贴图、权重、动作帧矩阵有限值；两套实际渲染皮肤未赋权顶点均为 0。Blender glTF 导入器另造的 42 顶点 Icosphere 是 pose-bone custom-shape 控件，不是 GLB 角色网格，检查时按真实 custom_shape 引用排除并在 JSON 单列，不能误计为 42 个未绑定人体顶点。Godot 独立工程实际识别 Skeleton3D 与五条 AnimationPlayer 动作。
- **仍缺成品动作质量**：目前是 FK 关键姿态与小幅循环，不是最终 IK 接触锁定、动作混合/过渡和手指抓握系统；阅读书本道具当前是 Blender 姿态样板中的摆位，尚无游戏内道具挂接/事件实现。近景手部、衣服褶皱与猫头接触还应继续调整。

## GLB 架构与真实 Godot 验证

- `exports/female_rigged.glb`、`male_rigged.glb`：独立可复用的完整蒙皮与动作。
- `exports/room_realtime.glb`：**只包含场景/家具**，不把一个无动作的 A-pose 角色塞进房间充数。Godot 示例用独立角色播放 Sit_Desk，放在 (.55,0,-1.82)、Y 旋转 PI，组合出与 Blender 一致的坐桌状态。
- `exports/city_realtime.glb` + 六个独立模块 GLB。
- 面数核对区分唯一 mesh 与场景 mesh 实例；房间复用了地砖/墙体，不能把唯一 mesh 总面数误当实例化后的总面数。重导按实例化后、去除重复索引面的面数比较。另列极小面积三角诊断值（平方叉积阈值 1e-18），不武断声称这些小面会被导入器删除。贴图全部打包在 GLB；材质乘色改用 glTF 支持的 `ShaderNodeMix/RGBA MULTIPLY`，实测修复旧 MixRGB 导出后衣服变白的问题。方盒反向法线也已在本轮检查中修正并重渲。
- 实测环境：Godot 4.5.1 / OpenGL Compatibility / Mesa llvmpipe。不是性能指标，不可据此承诺目标设备帧率。
- `godot_dither_probe/project.godot` 是独立诊断项目，不是游戏仓库。`probe.gd` 遍历 MeshInstance3D、Skeleton3D 与 AnimationPlayer；结果 `godot_dither_probe/runtime_verification.json`。

## 方案二遮挡

`godot_dither_probe/circle_dither.gdshader`：屏幕像素半径圆形窗口、4×4 Bayer 75% discard、8px 边缘羽化，只裁比主角焦点更靠近相机的遮挡片元；没有用整栋建筑透明代替圆形镂空。保留真实 PBR 贴图与深度写入。

`occlusion_driver.gd` 每帧从 Camera3D 投影主角焦点，将 UV、视空间深度与像素半径传给指定墙/树材质。不要给地面、主角或所有场景材质一刀切使用。

Blender 演示为真正的 Window-space 圆形 mask + 50% ordered checker Transparent BSDF；Godot 演示为真正 4×4 Bayer shader。两者覆盖率不同，明确标注，不伪称同一个渲染器。

未完成的生产验证：多重遮挡、镜头缩放、多个主角切换、阴影代理（避免随 discard 形成不期望阴影）、移动端/Forward+ 与目标设备的抗闪烁/帧率。

## 自动技术检查

{check_rows}

所有详细数据、源文件 MD5、导出 SHA256、重导结果、每个物体面数与 Origin 在 `verification.json`。

## 质量门与下一步

1. 已亲自读取主图和放大裁切；持书时穿过椅背、逗猫时手掌与袖口断开的首轮失败也已据实发现，调整了角色朝向、双骨可达目标和骨段变换后重渲。已改正脸部因骨骼 roll 被转到背面的错误、尖肩套袖、床垫穿出被子的白斑、方盒法线、glTF 材质乘色丢失和房间 A-pose 导出问题。角色转台摄影台高度也已校正到脚底 z=0，避免展示图脚底悬空。
2. **自检仍不批准作为最终替换美术交付**：头发整体感、人物手部、衣服造型、猫的有机解剖、书本抓握、城市门头建筑细节仍偏简化。素材确实有纹理和真实骨骼，不等于美术已经足够漂亮。
3. 下一轮应优先锁定一个角色的脸/发/手/衣服近景与坐桌接触，再迁移另一性别；城市只保留当前可复用骨架，待角色与室内通过门槛后再精修六地标。
4. 暂不改游戏代码，不把 Cycles 图当 Godot 实机图，也不把“格式导入成功”描述成“最终美术验收通过”。

## 复现

```bash
python3 blender_scripts/download_assets.py
python3 blender_scripts/make_textures.py
/workspace/tools/blender-4.5.3-linux-x64/blender -b -t 4 --python blender_scripts/build_sample.py
# 各 mode 独立运行：characters / room / poses / dither / city / landmarks
/workspace/tools/blender-4.5.3-linux-x64/blender -b -t 6 --python blender_scripts/render_sample.py -- room
/workspace/tools/blender-4.5.3-linux-x64/blender -b -t 2 --python blender_scripts/verify_glb.py
```

原生可编辑文件：`blender_realtime_sample.blend`，已 Pack 所有贴图；原始贴图也保留在 `textures/`。所有生成脚本、日志、验证工程均在此目录，未对用户机器或游戏仓库写入。
'''
(P/'REPORT.md').write_text(report)
print(json.dumps(checks,ensure_ascii=False,indent=2));print('TECHNICAL_PASS',quality['technical_pass'],'VISUAL_GATE',quality['visual_gate'])
