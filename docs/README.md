# Project ReBoundary 文档

> **Project ReBoundary** 是一个为《边境》(Boundary) 游戏提供私服联机支持的逆向工程项目。

## 项目概述

本项目通过逆向工程和服务器模拟，绕过原始官方服务器，实现《边境》游戏的私服联机功能。项目由两个核心子仓库组成：

| 子仓库 | 技术栈 | 角色 |
|--------|--------|------|
| **ReBoundaryMain** | C++ (DLL注入, Unreal Engine SDK) | 客户端/Dedicated Server 补丁 |
| **ReBoundaryMetaServer** | Node.js (Express, Protobuf, TCP/UDP) | 元数据服务器（逻辑服务器） |

## 文档索引

- [架构总览](./architecture.md) — 系统整体架构图、组件关系
- [流程图](./flowcharts.md) — 完整启动、匹配、加入比赛流程
- [ReBoundaryMain 详解](./reboundarymain.md) — 客户端 DLL 注入与 Dedicated Server 模拟
- [ReBoundaryMetaServer 详解](./reboundarymetaserver.md) — 元数据服务器协议与实现
- [通信协议](./protocol.md) — Protobuf 消息格式、RPC 路径一览

## 快速理解

```
玩家启动游戏
  → dxgi.dll (代理) 加载 Payload.dll
    → Payload 通过 Hook 重定向服务器地址到自建 MetaServer
      → MetaServer 模拟官方逻辑服务器的所有 RPC 响应
        → 一台游戏实例以 -server 模式运行，作为 Dedicated Server
          → 其他玩家通过 MetaServer 指引连接到此服务器
            → LibReplicate 处理 Unreal Engine 网络复制
              → 玩家可联机对战！
```

## 部署与启动

1. 启动 **ReBoundaryMetaServer**：
   ```bash
   node index.js
   ```
2. 启动 **Dedicated Server (专用服务端)**：
   为游戏客户端可执行文件（`Boundary.exe` 或 `ProjectBoundarySteam-Win64-Shipping.exe`）创建快捷方式，并在目标后添加以下参数：
   ```text
   -server -unattended -nullrhi -log
   ```
   *注意: `-nullrhi` 用于禁用服务端网络底层的渲染和UI，防止闪退；`-unattended` 用于跳过由于缺失客户端材质导致的弹窗警告卡死。*
3. 启动 **客户端机位**：
   在 Steam 库中找到《Boundary》，右键「属性」-「通用」-「启动选项」，填入 MetaServer 所在的大厅地址（本地启动请填本机 IP）：
   ```text
   -LogicServerURL=http://127.0.0.1:8000
   ```
   *注意：如果在大厅外联机，需要把这里的 IP 改为房主的公网或局域网 IP。*

## 💡 必读：Steam 防双开拦截（本地同机测试解法）

如果您在同一台电脑上既想开专用服务端（`-server`），又想开客户端自己连进去玩（即同机双开本地联机），您会遇到 **Steam 默认只允许同一个游戏运行一个实例** 的底层拦截。Steam 发现你要启动客户端时，会“吃掉”服务端的命令行参数或直接强制将其关掉。

为了彻底实现本地双开，请务必使用**物理隔离套皮法**：

1. **分离服务端目录**
   进入您的 Steam 库，把完整高达几十个 G 的 `ProjectBoundary` 整个游戏文件夹复制一份，粘贴出来并重命名为 `ProjectBoundary_Server`（放在任何您喜欢的独立目录下）。以后这个新克隆的文件夹专属于服务端，原版专属客户端。

2. **伪装 Steam AppID**
   进入刚才拷贝出的 `ProjectBoundary_Server\Binaries\Win64` 目录下，新建一个文本文档，命名为 `steam_appid.txt`。
   用记事本打开该文件，里面**只填写三个数字**（注意不要有多余空格和换行）：
   ```text
   480
   ```
   *(注：480 是 Steam 官方留给特定开发者的公用马甲游戏 Spacewar 的代号。填入它后，服务端启动时会被 Steam 识别为你在打 Spacewar，从而不再阻挡你正常启动 边境 客户端。)*

3. **创建独立快捷方式**
   给 `ProjectBoundary_Server\Binaries\Win64` 里原本的客户端 `exe` 右键创建快捷方式，目标后面加上所有必须的服参：
   ```text
   -server -unattended -nullrhi -log -nosteam
   ```
4. **启动顺序**
   - 先起 `Start-MetaServer.bat`（常驻黑框记录流量）
   - 再起刚建好的 `-server` 快捷方式（另一个常驻黑框渲染世界）
   - 最后在 Steam 正常启动原版客户端（畅玩）
