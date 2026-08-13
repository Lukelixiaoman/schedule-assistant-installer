---
name: "[Harvest] 本地日程服务与看板自动化"
description: 在Obsidian库中部署Python本地HTTP服务器，为桌面HTML看板提供读写API，并配置macOS启动脚本。适用于需要动态增删改查日程且无需云端依赖的本地化管理场景。
created_by: main_agent
---
## Workflow
1. **部署本地服务器**：在 `{obsidian_root}/50_日程/` 目录下创建 `awb-schedule-server.py`。该脚本需使用 Python 标准库实现 HTTP 服务，监听 `{port}`（默认 8899），提供 GET/POST/DELETE 接口以读写 `_index.json` 及对应的 Markdown 日程文件。
2. **语法与权限自检**：执行 `python3 -m py_compile` 验证服务器脚本语法。若需创建 macOS 启动脚本 `.command`，使用 Python 的 `os.chmod` 赋予执行权限（避免直接调用被禁用的 `chmod` 命令）。
3. **改造前端看板**：重写 `{desktop_path}/日程.html`，移除静态 JSON 依赖，改为通过 Fetch API 调用本地服务器的 `/api/events` 接口。实现双击空白格新建、点击已有项编辑/删除的交互逻辑。
4. **创建桌面启动器**：编写 `启动日程.command` 脚本，内容包含启动 Python 服务器并自动调用 `open` 命令打开浏览器指向 `http://127.0.0.1:{port}/`。确保脚本具备可执行权限。
5. **链路联调验收**：运行启动脚本，在看板中执行一次完整的“新建-查看-删除”操作，确认 Markdown 文件落地、索引更新及界面实时刷新。

## Suggestions
- 服务器脚本应绑定 `127.0.0.1` 以确保安全性，避免暴露给局域网其他设备。
- HTML 看板中的统计卡片应增加点击事件，支持快速切换日/周/月视图。
- 建议在 Obsidian 中配合 Templater 插件使用标准模板录入，保证后端解析兼容性。

## Fallback / Edge Cases
- 若 `python3 -m py_compile` 报错，检查脚本中是否存在中文路径处理不当或缩进错误。
- 若浏览器无法加载看板，检查防火墙是否拦截了 `{port}` 端口，或尝试更换端口号。

## Pitfalls
- 步骤 2：macOS 环境下禁止直接使用 `chmod` 命令行工具修改权限，必须通过 Python 代码或系统偏好设置手动授权，否则会导致自动化中断。
- 步骤 3：前端 Fetch 请求需注意跨域问题，由于是本地文件访问本地服务，通常需确保服务器响应头包含正确的 CORS 配置或使用同源策略。
