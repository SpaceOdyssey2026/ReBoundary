# 流程图

本文档展示了两个子仓库协同工作下的核心游戏流程：包括**客户端冷启动过程**以及**玩家加入比赛打通联机的全过程**。

## 客户端启动及初始化流程

```mermaid
sequenceDiagram
    participant P as 玩家
    participant EXE as Boundary.exe (客户端)
    participant DLL as Payload.dll (ReBoundaryMain)
    participant META as ReBoundaryMetaServer
    
    P->>EXE: 启动游戏
    EXE->>EXE: 自动加载欺骗性 dxgi.dll
    EXE->>DLL: 加载 Payload.dll (DLLMain attached)
    DLL->>DLL: 判断启动参数: 普通客户端模式
    DLL->>DLL: 初始化客户端 Hooks (SafetyHook)
    DLL->>DLL: 解锁所有内置武器配件、设置皮肤数据
    EXE->>META: 发起 HTTP Connect Server (登录校验)
    META-->>EXE: 返回虚拟 Token & Endpoint
    EXE->>META: 发起 TCP 长连接验证及心跳交换
    loop 虚假认证与配置拉取
        EXE->>META: [Protobuf RPC] 请求玩家档案/公告/比赛列表
        META-->>EXE: 发送伪造的响应 (Patchnotes, Level, Items)
    end
    EXE->>P: 渲染并进入主界面 (Main Menu)
```

## 创建与加入比赛联机流程

此流程展示了如果一个玩家作为房主 (Server)，其他玩家作为客户端 (Client)，整个联机的打通方式。

```mermaid
sequenceDiagram
    participant DS as Boundary.exe -server (房主)
    participant META as ReBoundaryMetaServer
    participant CL as Boundary.exe (客户端玩家)
    
    %% DS 初始化
    Note over DS: 房主启动 DS
    DS->>DS: 加载 Payload.dll 判定为 Server
    DS->>DS: 初始化ServerHooks, 关闭渲染 (限制FPS)
    DS->>DS: 执行 ConsoleCmd: open MapName?game=GameMode
    DS->>DS: 初始化 LibReplicate
    DS->>DS: 绑定 NetDriver 于 7777 端口, 开始 Listen!
    
    %% 客户端匹配
    Note over CL, META: 客户端在主界面开始匹配
    CL->>META: [Protobuf RPC] 请求 `/matchmaking.Matchmaking/StartUnityMatchmaking`
    META-->>CL: Http/TCP 成功匹配，返回联机服务器IP和状态
    
    %% 客户端连接 DS
    CL->>CL: 准备连接，触发展示 Loading 界面
    CL->>DS: 发起 UDP/TCP 连接请求至 7777 端口
    DS->>DS: 拦截 `NotifyAcceptingConnection` 等方法
    DS->>DS: LibReplicate创建通道，接收玩家
    DS-->>CL: `PostLogin` Hook触发, Join成功
    
    %% 比赛初始化
    Note over DS, CL: 所有玩家进入大厅等待
    loop TickFlush & 轮询
        DS->>DS: 计算队伍人数、检查 Ready 状态
    end
    DS->>DS: 时间到, 广播所有连接进入倒计时
    DS->>CL: 控制玩家展示武器选择 (RoleSelection UI)
    CL->>DS: [Protobuf RPC 近似] 提交配置完毕 `ServerConfirmRoleSelection`
    DS->>DS: 全部玩家确认
    DS->>DS: `StartMatch()`
    DS->>CL: 产生真实的 CharacterPawn, 并完成 Possess
    Note over DS, CL: 同步进行中，比赛开始！
```

## 网络同步循环 (LibReplicate Hook 工作流)

这是游戏实时对决时，服务端如何向客户端下发数据的流程，它完全接管了官方废弃或缺失的复制过程：

```mermaid
graph TD
    A[引擎 Tick 每帧调用] --> B[触发我们 Hook 的 TickFlush]
    B --> C{是否有人没选角色?}
    C -->|是| D[强制调用 ClientSelectRole]
    C -->|否| E[遍历全图 Actor 筛选需同步对象]
    E --> F[筛选出 PlayerControllers 和 Connections]
    F --> G[调用 LibReplicate::CallFromTickFlushHook]
    
    subgraph `LibReplicate` 复制流程
    G --> H[针对玩家控制器调用 CallPreReplication & SendClientAdjustment]
    H --> I[针对普通Actor创建或获取 ActorChannel]
    I --> J[调用底层的 ReplicateActorFuncPtr发送网络包给客户端]
    end
    J --> K[客户端接收通过虚幻引擎还原物理/开火位置]
```
