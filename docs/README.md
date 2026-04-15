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
