# 复盘 JSON

复盘通过 `deltamap-force-review/v1` JSON 导入。每个时间节点必须同时包含可确认的双方兵力数字和据点状态；顶部兵力被遮挡或无法辨认的抽帧不得写入。

```json
{
  "schema": "deltamap-force-review/v1",
  "rounds": [{
    "round": 1,
    "attack": "进攻方",
    "defense": "防守方",
    "duration": 1200,
    "points": [{
      "time": 60,
      "videoTime": 300,
      "attackForce": 320,
      "defenseForce": 280,
      "objectives": [{ "id": "A", "owner": "attack", "progress": 65 }]
    }]
  }]
}
```
