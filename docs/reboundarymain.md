# ReBoundaryMain 深入解析

ReBoundaryMain 是项目的客户端核心，采用 C++ 编写，通过 DLL 注入技术侵入 Boundary.exe 进程，在不修改游戏本体文件的情况下改变游戏行为以支持私服。

## 工作目录组织

- `dxgi/`：劫持模块。编译为 `dxgi.dll`，由于 Windows 加载 DLL 的优先级，放置在游戏目录下的 dxgi.dll 会被优先加载，它负责在被加载时悄悄启动 `Payload.dll`，并将原版功能转发给系统的真实 DirectX。
- `Payload/`：实际业务模块。负责所有的 Hook 与逻辑。
  - `dllmain.cpp`：程序入口与 Hook 中心。
  - `libreplicate.cpp / .h`：自定义 Unreal Engine 网络复制同步实现。
  - `SDK/ / SDK.hpp`：导出的 Unreal Engine SDK，包含类指针和偏移量。
  - `safetyhook/`：开源 Hook 库，用于在内存中修改运行时函数。

## 核心机制：SafetyHook 函数劫持

项目利用 `safetyhook::create_inline` 修改了游戏引擎内部的核心函数流。通过硬编码的相对基址（`BaseAddress + 0x...`），拦截和篡改了以下类别的功能：

### 服务端特有 Hook (`InitServerHooks`)
当带有 `-server` 参数启动时：
- `TickFlushHook`: 劫持 `UNetDriver::TickFlush`。这是游戏引擎处理网络更新的周期函数。代码通过遍历当前世界中的可同步资源（Actors），通过调用我们自己手写的 `LibReplicate` 实例进行数据包发送。
- `NotifyActorDestroyedHook`: 拦截组件销毁事件并通告给 `LibReplicate` 取消网络同步。
- `NotifyAcceptingConnectionHook`: 处理来自客户端的新连接。
- `ProcessEventHook`: Unreal Engine 用来分发蓝图与原生系统事件的核心方法。这里拦截了复活 (`QuickRespawn`)、等待 (`ReadyToMatchIntro_WaitingToStart`)，甚至是角色选取确认 (`ServerConfirmRoleSelection`) 等，重写了判断逻辑以强制推进匹配流程。
- `PostLoginHook`: 检测有玩家连入游戏，增加计数器。
- `IsDedicatedServerHook / IsServerHook`: 强制返回 `true` 欺骗引擎我们正处于 DS 环境下运行。

### 客户端特有 Hook (`InitClientHook`)
- `ProcessEventHookClient`: 同样拦截引擎事件。其中最重要的一个拦截：`OnConnectMatchServerTimeOut`（连接匹配超时），一旦捕捉到这个事件，说明客户端原本想要连接官方分配的服务器结果断连了这时候代码强制执行 `ConnectToMatch()`，主动利用虚幻控制台命令 `travel` 跳转至我们指定（写死或动态下发）的私有服务器 IP，完成加入对局。
- `ClientDeathCrashHook`: 拦截并规避某种在客户端死亡时会引发崩溃的情况。

## LibReplicate 自定义同步库

由于游戏官方客户端剥离或缺失了针对联机的部分数据序列化/复制机制 `Payload` 内置了 `LibReplicate` 以接管这一切：

1. **连接与通道 (`ActorChannel`)**: 为每个 `UNetConnection` 建立连接。
2. **Actor 信息追踪 (`FActorInfo`)**: 维护每个网络实体的状态。
3. **前置同步与调整**: 在发送包之前，调用 `CallPreReplication` 等函数获取正确的物理与逻辑信息。
4. **底层调用**: 直接使用引擎预留的未导出函数指针 (`CreateChannel`, `SetChannelActor`, `ReplicateActorFuncPtr`) 在协议层完成底层序列化。

## 其他功能

- **武器全解锁**：在客户端版 `dllmain.cpp` 中运行 JSON 解析，从 `DT_ItemType.json` 直接取出所有武器与配件的内部命名，注入并更新 `UPBArmoryManager` 中的 `OwnedItems` 列表，使得进入游戏即解锁所有装备和插槽。
- **强制关闭渲染**：DS版由于只负责运算没有显示必要，为节约性能使用 `UKismetSystemLibrary::ExecuteConsoleCommand` 设定了 `t.maxfps 30` 或在 Tick 中阻断 Tick流程削减消耗。
