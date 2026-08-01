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

## 赛事战术复盘

[`plans`](plans/) 目录保存了可以直接导入 DeltaMap 的赛事战术方案。目前包含百姓杯 SEA vs JDI 断轨地图两回合攻守复盘，蓝色表示 SEA，橙色表示 JDI。

同目录还提供本场的[详细中文复盘](plans/SEA-vs-JDI-断轨-详细复盘.md)、[结构化分析数据](plans/SEA-vs-JDI-断轨-详细复盘.json)和可复用于其他比赛的 [JSON Schema](plans/analysis-schema.json)。分析统一记录阶段时间、主攻/次攻方向、人员移动、载具移动、防守结构、转折点和置信度，便于批量积累不同地图与队伍的战术样本。

导入方法：打开 DeltaMap，点击右上角“导出” -> “导入战术文件”，选择对应的 JSON 文件。

战术视频来源关注列表保存在 [`sources/bilibili-watchlist.json`](sources/bilibili-watchlist.json)，当前关注“索菲亚堂主直播回放”和“天堂的手比赛解说”。

无需下载完整视频即可随机抽取 B 站预览帧：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sample-bilibili-storyboard.ps1 -Bvid BV1QxGM66EJN -SampleCount 24
```

脚本只下载随机帧所在的预览拼图，输出独立 JPG 和带时间点的 `manifest.json`，不会下载完整视频。

## 数据说明

战术标注默认保存在浏览器本地存储中。更换电脑、清理浏览器数据或重装系统前，请先导出 JSON 战术文件。

地图与点位素材来自《三角洲行动》官方地图工具，仅用于玩家战术交流。游戏内容及相关素材版权归其权利人所有。
