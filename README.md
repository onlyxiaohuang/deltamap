# DeltaMap 三角洲战术地图

一款轻量化的《三角洲行动》全面战场地图编辑工具。支持官方底图、据点边界、自由绘图、载具与固定工事标记、本地自动保存以及 PNG/JSON 导入导出。

JDI出品，欢迎各路大神加入JDI。

项目仓库：[onlyxiaohuang/deltamap](https://github.com/onlyxiaohuang/deltamap)

觉得项目有用，欢迎打开仓库右上角点一个 **Star**，让更多玩家找到这个工具。

## 一键下载

普通玩家不需要安装开发环境：

1. 打开 [GitHub Releases](https://github.com/onlyxiaohuang/deltamap/releases)。
2. 展开最新版本的 `Assets`。
3. 下载 `DeltaMap.exe`。
4. 双击 `DeltaMap.exe`，地图会以独立窗口打开。

EXE 已包含全部地图、边界、图标、脚本和样式，不需要另外下载资源文件。首次启动会把内置资源释放到 `%LOCALAPPDATA%\DeltaMap\app`，后续启动会直接复用。

> Windows SmartScreen 可能提示“Windows 已保护你的电脑”。这是个人开源项目未购买代码签名证书导致的。确认文件来自本仓库 Release 后，可选择“更多信息” -> “仍要运行”。

## 功能

- 13 张 PC 全面战场官方地图
- 攻防与占领模式切换
- 官方据点、基地、载具、补给、固定武器和地图装置图层
- 战区边界、阶段边界和据点边界
- 画笔、直线、箭头、矩形、圆形、文字和标记点
- 两点测距工具，按当前地图官方世界坐标比例显示米数
- 可自由放置、着色和拖动的人员、载具与固定工事
- 浏览器本地自动保存
- 撤销、重做和清空
- PNG 图片与 JSON 战术方案导入导出
- 完整离线资源

## 一键生成 EXE

仓库根目录提供了 [`build-exe.ps1`](build-exe.ps1)。它使用 Windows 自带的 .NET Framework C# 编译器，不要求安装 Visual Studio、Node.js 或 Electron。

在项目目录空白处按住 `Shift` 并右键打开 PowerShell，然后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\build-exe.ps1
```

也可以直接右键 `build-exe.ps1`，选择“使用 PowerShell 运行”。生成结果位于：

```text
release\DeltaMap.exe
```

脚本会自动收集全部本地资源、生成内置压缩包、编译启动器，并把所有内容嵌入单个 EXE。打包完成后会自动删除临时文件。

## 网页版运行

不需要 EXE 时，也可以直接双击 `index.html` 使用。所有运行资源均已本地化。

战术视频来源关注列表保存在 [`sources/bilibili-watchlist.json`](sources/bilibili-watchlist.json)，当前关注“索菲亚堂主直播回放”和“天堂的手比赛解说”。


无需下载完整视频即可随机抽取 B 站预览帧：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sample-bilibili-storyboard.ps1 -Bvid BV1QxGM66EJN -SampleCount 24
```

脚本只下载随机帧所在的预览拼图，输出独立 JPG 和带时间点的 `manifest.json`，不会下载完整视频。

## 数据说明

### 地图比例尺

官方地图数据的 `info.width`、`info.height`、`centerX`、`centerY` 和 `rotate` 用于把游戏世界坐标映射到地图。世界坐标使用 Unreal 厘米单位，因此工具按 `100 坐标单位 = 1 米` 换算。例如断轨官方宽高均为 `70000`，对应约 `700m x 700m`；攀升为 `100000 x 100000`，对应约 `1000m x 1000m`。贯穿地图存在旋转且宽高略有差异，测距时已交换对应轴向比例。

选择左侧尺子按钮，在地图任意两点之间拖动即可生成测距线。显示结果是二维平面直线距离，不包含地形高差、道路曲线或建筑楼层高度。

战术标注默认保存在浏览器本地存储中。更换电脑、清理浏览器数据或重装系统前，请先导出 JSON 战术文件。

地图与点位素材来自《三角洲行动》官方地图工具，仅用于玩家战术交流。游戏内容及相关素材版权归其权利人所有。
