# ReBoundaryMetaServer 深入解析

ReBoundaryMetaServer 作为游戏大厅及外围系统的服务端，采用 Node.js 实现（`index.js`），用来模拟曾经官方部署的鉴权与配置服务。

## 模块组成

- `express`, `body-parser`: 提供 HTTP/HTTPS 端点处理登陆流程。
- `net` (TCP Server): 维持游戏大厅里的长连接，处理各种游戏大厅的事件/操作请求。
- `dgram` (UDP Server): 提供快速的心跳测试/服务器发现服务。
- `protobufjs`: 核心解码库，用来将收到的二进制字节流反序列化为可以阅读的 JSON/Object 对象，并将模拟返回的配置进行序列化。

## 伪造登录与验证 (Express)

通过开启监听于常见端口（针对代码中的 `process.env.PORT` 或 8000），处理客户端初期的 HTTP 调用：

- **`//connectServer`** / **`/connectServer`**: 拦截客户端发送过来的 Token，不再进行实质的后台校验，而是直接返回硬编码的虚拟 `gateToken`、`userId` 并且下发后续长连接 TCP 需要对接的 Endpoint `204.12.195.98:6969`。

## 游戏核心长连接逻辑 (Net / TCP Server 6969端口)

客户端拿到 Endpoint 后会发起 TCP 连接，随后所有通信以包含四字节头部（长度标识）的 Protobuf 数据帧格式流转。

代码中 `socket.on('data', ...)` 剥离长连接中的多条消息，将每条 RPC 投递到指定的处理器中。

### 重要 RPC 模拟点

1. **Token 握手**：如果 RPC Path 等于刚才下发的假 Token，则回声响应，代表鉴权成功。
2. **解锁数据下发 (`UpdateRoleArchiveV2`, `UpdateWeaponArchiveV2`)**：通知游戏，相关槽位数据获取成功。
3. **通知下发 (`QueryNotification`)**：下发欢迎测试、补丁日志（Patchnotes）用于在游戏内展示各种维护及测试群交流信息。
4. **小队机制 (`party.party/Create`, `party.party/Ready`, `party.party/SetPresence`)**：大厅组队的模拟。将状态切换在客户端与自身维护并回传给不同玩家。
5. **匹配服务 (`/matchmaking.Matchmaking/...`)**：
   - `QueryUnityMatchmakingRegion`: 返回可选匹配区节点。
   - `StartUnityMatchmaking`: 处理客户端点击“开始匹配”。由于项目目前为私服状态，此操作通常会成功返回一个虚拟标志从而放任客户端进入加载阶段。
6. **比赛与播放列表 (`QueryPlayList`)**：加载硬编码的 JSON 项，如“Purge - Playtest a very early version of Project Rebound”，这些信息驱动着游戏主页按钮及其图片资源的展现（通过语言包本地化 `zh` 或 `en` 返回不同的内容）。

## Matchmaking UDP QoS 服务 (UDP 9000端口)

负责响应游戏客户端为了检查网络延迟而发送的探测包。

- 监听 9000 端口的消息。如果消息字节首位为 `0x59`（心跳测试标志），则构建一串以 `0x95 0x00` 开头的回应包，与原包中的负载合并返回。
- 保证客户端以为网络节点畅通可用。

## Wire.py 说明

在 `ReBoundaryMetaServer` 中附加了一个 `wire.py` 辅助脚本，这是一个独立的 Protobuf 二进制解码器。
开发者可以用交互式或提供字节码的方式，快速解析截获的未知封包字段以及类型（Wire Type 与 Field Number）。这个工具对逆向工程初期极具价值，可以帮助开发者构建对应的预设 `.proto` 描述文件。
