#!/bin/bash
# ============================================================
# 日程助手 - macOS 一键安装脚本
# 双击运行：自动安装到当前登录的 Accio Work 账号
# ============================================================
cd "$(dirname "$0")" || exit 1

echo "=============================================="
echo "  日程助手 一键安装（macOS）"
echo "=============================================="
echo ""

# ---------- 1. 定位 current-space.json（多路径候选 + 全局兜底） ----------
CURRENT_SPACE=""
for candidate in \
    "$HOME/.accio/state/current-space.json" \
    "$HOME/Library/Application Support/accio/state/current-space.json" \
    "$HOME/Library/Application Support/Accio/state/current-space.json" \
    "$HOME/Library/Application Support/Accio Work/state/current-space.json"
do
    [ -f "$candidate" ] && CURRENT_SPACE="$candidate" && break
done

[ -z "$CURRENT_SPACE" ] && \
    CURRENT_SPACE=$(find "$HOME" -name "current-space.json" -maxdepth 8 \
        ! -path "*/Trash/*" 2>/dev/null | head -1 || true)

if [ -z "$CURRENT_SPACE" ]; then
    echo "[错误] 未找到 Accio Work 登录状态文件（current-space.json）。"
    echo "       请先登录 Accio Work 桌面端再运行本脚本。"
    read -r -p "按回车退出..." _
    exit 1
fi
echo "[1/5] 已定位登录状态: $CURRENT_SPACE"

# ---------- 2. 反推 accio 根目录（不硬编码 ~/.accio） ----------
ACCIO_ROOT=""
case "$CURRENT_SPACE" in
    */.accio/*) ACCIO_ROOT="$HOME/.accio" ;;
    *"Library/Application Support/accio"*) ACCIO_ROOT="$HOME/Library/Application Support/accio" ;;
    *"Library/Application Support/Accio"*) ACCIO_ROOT="$HOME/Library/Application Support/Accio" ;;
    *"Library/Application Support/Accio Work"*) ACCIO_ROOT="$HOME/Library/Application Support/Accio Work" ;;
esac
if [ -z "$ACCIO_ROOT" ]; then
    ACCIO_ROOT=$(dirname "$(dirname "$(dirname "$CURRENT_SPACE")")")
fi
echo "[2/5] Accio 根目录: $ACCIO_ROOT"

# ---------- 3. 调用 Python 完成安装（传参方式，避免转义问题） ----------
echo "[3/5] 读取账号信息..."
python3 - "$CURRENT_SPACE" "$ACCIO_ROOT" << 'PYEOF'
import json, os, shutil, sys

current_space, accio_root = sys.argv[1], sys.argv[2]

# 读取当前账号
with open(current_space, encoding='utf-8-sig') as f:
    space = json.load(f)
account_id = str(space.get('accountId', ''))

if not account_id:
    print("[错误] current-space.json 中未找到 accountId")
    sys.exit(1)

agents_root = os.path.join(accio_root, 'accounts', account_id, 'agents')
os.makedirs(agents_root, exist_ok=True)

# 生成新 Agent ID（基于时间戳，避免与源 Agent 冲突）
import time, uuid
agent_id = "MID-" + str(int(time.time() * 1000)) + "-" + uuid.uuid4().hex[:8].upper()
agent_dir = os.path.join(agents_root, agent_id)
agent_core = os.path.join(agent_dir, 'agent-core')
os.makedirs(os.path.join(agent_core, 'skills'), exist_ok=True)
os.makedirs(os.path.join(agent_dir, 'permissions'), exist_ok=True)
os.makedirs(os.path.join(agent_dir, 'runtime'), exist_ok=True)

# ---------- 复制 agent-core 文件 ----------
src_core = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'agent-core')
if not os.path.isdir(src_core):
    print("[错误] 未找到 agent-core 目录: " + src_core)
    sys.exit(1)

copied = 0
for root, dirs, files in os.walk(src_core):
    dirs[:] = [d for d in dirs if d not in ('.git', '__pycache__')]
    rel = os.path.relpath(root, src_core)
    dst_dir = agent_core if rel == '.' else os.path.join(agent_core, rel)
    os.makedirs(dst_dir, exist_ok=True)
    for name in files:
        if name in ('.DS_Store', 'skills.jsonc', 'USER.md', 'MEMORY.md'):
            continue
        shutil.copy2(os.path.join(root, name), os.path.join(dst_dir, name))
        copied += 1

# ---------- 生成 profile.jsonc ----------
profile = {
    "id": agent_id,
    "accountId": account_id,
    "name": "日程助手",
    "description": "帮我搭建日程看板和提醒",
    "vibe": "professional",
    "model": {"provider": "auto", "name": "auto"},
    "runtime": "local",
    "toolInclude": ["list","read","grep","glob","write","edit","web_search","web_fetch","bash","process","cron","image_generate","image_edit","get_time","ask_user","present_files","skill","plugin","memory_search","memory_get","task_create","task_get","task_update","task_list","sessions_spawn","video_generate_submit"],
    "creator": "user",
    "agentType": "default",
    "pluginIds": ["documents","presentations","spreadsheets","okki-crm","wecom-assistant"],
    "localMemoryIndex": True,
    "skillHarvestMode": "auto"
}
profile_path = os.path.join(agent_dir, 'profile.jsonc')
with open(profile_path, 'w', encoding='utf-8') as f:
    f.write("// Accio Agent 配置，可由 UI 或 API 修改\n\n")
    f.write(json.dumps(profile, ensure_ascii=False, indent=2))

# ---------- 生成 skills.jsonc（安装路径指向新 Agent） ----------
skills_meta = []
skill_dirs = []
for root, dirs, files in os.walk(os.path.join(agent_core, 'skills')):
    if 'SKILL.md' in files:
        skill_dirs.append(root)
        skill_id = os.path.basename(root)
        # 读取 skill 描述
        desc = ""
        try:
            with open(os.path.join(root, 'SKILL.md'), encoding='utf-8') as f:
                head = f.read(2000)
            for line in head.splitlines():
                if line.startswith('description:'):
                    desc = line[len('description:'):].strip().strip('>').strip()
                    break
        except Exception:
            pass
        skills_meta.append({
            "id": skill_id,
            "name": skill_id,
            "version": "",
            "enabled": True,
            "kind": "directory",
            "entryName": os.path.relpath(root, os.path.join(agent_core, 'skills')),
            "description": desc,
            "installPath": root
        })

skills_path = os.path.join(agent_core, 'skills', 'skills.jsonc')
with open(skills_path, 'w', encoding='utf-8') as f:
    f.write(json.dumps({"skills": skills_meta}, ensure_ascii=False, indent=2))

print("[4/5] 已安装 Agent: " + agent_id)
print("       目录: " + agent_dir)
print("       复制文件数: " + str(copied) + " | 技能数: " + str(len(skills_meta)))
PYEOF

if [ $? -ne 0 ]; then
    echo ""
    echo "[错误] 安装过程中出现问题，请截图该窗口反馈。"
    read -r -p "按回车退出..." _
    exit 1
fi

echo ""
echo "=============================================="
echo "  ✅ 安装完成！"
echo "=============================================="
echo "  接下来："
echo "  1. 完全退出 Accio Work（不是最小化）"
echo "  2. 重新打开 Accio Work"
echo "  3. 在智能体列表中找到「日程助手」"
echo ""
read -r -p "按回车退出..." _
