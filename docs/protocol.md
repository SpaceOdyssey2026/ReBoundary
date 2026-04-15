# 核心通信协议 (Protobuf RPC)

ReBoundaryMetaServer 和 游戏客户端之间的主要长连接数据都是通过构建在 TCP 协议上的 Protobuf (Protocol Buffers) 进行通信。

## 消息封装格式 (Wrapper Types)

每次从 TCP 接口接收到的网络字节流，首先包含了 4 字节的数据长度头。当抛出前 4 个字节后，剩余的 `Payload` 被送入 `RequestWrapper.proto` 或用于发出的 `ResponseWrapper.proto` / `JSONResponseWrapper.proto`。

**Request 数据包结构（概念）**
```protobuf
message RequestWrapper {
    int32 MessageId = 1;
    string RPCPath = 2;
    bytes Message = 3;
}
```

**Response 包结构（概念）**
```protobuf
message ResponseWrapper {
    int32 MessageId = 1;
    string RPCPath = 2;
    int32 ErrorCode = 3;
    bytes Message = 4;
}
```

所有的请求都会附带一个 `RPCPath`，MetaServer 解析出 Wrapper 后，根据这个路径来分发逻辑。

## 重要 RPC Path 概览表

以下是通过抓包和逆向反编译出来的关键通讯路径：

| 路径 (RPCPath) | 用途 | ReBoundaryMetaServer 的处理方式 |
|-----------------|------|--------------------------------|
| `eyJhbGciOi` (JWT格式字符串形式) | 握手验证请求 | MetaServer 检查到 JWT，直接原样将其返回，认为验证通过 |
| `/assets.Assets/UpdateRoleArchiveV2` | 更新角色档案库 | 直接返回 `UpdateRoleArchiveV2Response` 并设 `StatusCode: 0` |
| `/assets.Assets/UpdateWeaponArchiveV2` | 更新武器档案库 | 同上，假装服务器存档成功 |
| `/notification.Notification/QueryNotification` | 核心界面：消息/补丁记录获取 | 使用 `QueryNotificationRequest` 读取玩家语言/平台，打包返回预先定义好的 Patchnotes (欢迎测试等文本)，包装成 `QueryNotificationResponse` |
| `/party.party/Create` | 在主界面建立房间队伍 | 获取一个随机生成的 UUID，作为 PartyId 传回 |
| `/party.party/Ready` | 队伍全员就绪请求 | 解析出 PartyId，回复就绪完毕状态 |
| `/party.party/SetPresence` | 更改此时的小队大厅状态 | 比如当前为 `InMatching` 等，服务端记录日志后回传 OK |
| `/party.party/QueryPresence` | 轮询当前小队状态 | 返回之前设定的 `PartyPresence` 和临时生成的用户ID |
| `/matchmaking.Matchmaking/QueryUnityMatchmakingRegion` | 客户端获取能去哪里匹配比赛 | 利用服务内预设的 UDPServerDiscovery 对象列表，如 `us-east1` 打包后返回区服列表 |
| `/matchmaking.Matchmaking/StartUnityMatchmaking` | 请求进入匹配池 | 解析 RequestorUserId 之后，返回开启成功 `StartMatchmakingResponse`，放行至下一步 |
| `/playerdata.PlayerDataClient/GetDataStatisticsInfo` | 请求生涯统计数据 | 返回结构体内的 `Datapoints` 为空，这会导致在UI中战绩被清空显示 |
| `/matchmaking.Matchmaking/QueryPlayList` | 查询主菜单上显示的比赛卡片信息 | 发送 `PLAYLISTS_JSON` 的 JSON 转换后的二进制。里面包含了具体的队列名为 `"Playtest"`和游玩模式 |
| `/profile.Profile/QueryCurrency` | 查询内置货币 | 发送5种假想的货币信息全部为 0 的回应 `QueryCurrencyResponse` |

这些路径涵盖了从登入、获取公告、组件队伍，到成功获取匹配数据从而进入实机战斗的全部必要的前置请求交互。
