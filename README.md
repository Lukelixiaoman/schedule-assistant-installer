# 日程助手 - 一键安装包

> 小满科技 & Accio 线上客户成功经理（CSM）的专属日程助手：把客户培训与服务日程转化为清晰、有序、按时触发的行动看板。

## 安装方式（二选一）

### 方式一：Accio 直接执行（推荐，全程免操作）

把下面这行命令**直接发给 Accio Work 智能体执行**即可：

```bash
# macOS / Linux
git clone https://github.com/lukexiaoman/schedule-assistant-installer.git && bash "schedule-assistant-installer/安装-苹果Mac双击我.command"
```

```powershell
# Windows
git clone https://github.com/lukexiaoman/schedule-assistant-installer.git && powershell -NoProfile -ExecutionPolicy Bypass -File "schedule-assistant-installer\install_helper.ps1"
```

### 方式二：ZIP 本地安装（无 Git 或无网络时）

1. 解压 ZIP 安装包
2. **Mac**：双击 `安装-苹果Mac双击我.command`（若弹「无法验证开发者」，右键 → 打开，只需一次）
3. **Windows**：双击 `安装-Windows双击我.bat`（自动调用 PowerShell，无需安装 Python）

## 安装后必做

1. **完全退出** Accio Work 再重新打开（不是最小化）
2. 设置 → 插件 → 安装对应插件（documents / presentations / spreadsheets / okki-crm / wecom-assistant）
3. 连接器 → 绑定对应账号

## 包含内容

- Agent 核心配置（身份、人格、工具清单）
- 2 个日程管理技能：
  - CSM日程自动化与看板同步
  - 本地日程服务与看板自动化
