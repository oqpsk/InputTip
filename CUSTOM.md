# 简繁规则定制版

基于 InputTip v3.6.12 / upstream commit `00998a53`。保留上游署名和 AGPL-3.0 许可。
`main` 留作同步上游；定制功能位于 `feature/chinese-script`。

## 固定按键约定

| InputTip 动作 | 默认按键 | 输入法需要执行 |
| --- | --- | --- |
| 字符集切换 - 强制繁体 | Ctrl+Alt+F11 | `traditionalization = true` |
| 字符集切换 - 强制简体 | Ctrl+Alt+F12 | `traditionalization = false` |

重复执行必须保持同一状态，不能使用 toggle。原来的 Ctrl+Shift+F 可继续手动切换。
输入法应消费这两个按键，正常同步简繁状态、失效旧候选并刷新候选；不应更改中英文模式、提交未完成的输入或切换输入法。

支持 Rime 按键绑定的输入法可将以下内容合入自己的 `default.custom.yaml`，保留已有的 `patch` 和绑定；重新部署后核对当前方案确实导入了这些绑定：

```yaml
patch:
  key_binder/bindings/+:
    - { when: always, accept: Control+Alt+F11, set_option: traditionalization }
    - { when: always, accept: Control+Alt+F12, unset_option: traditionalization }
```

也可以由输入法后端原生处理固定状态按键。此仓库不安装或修改任何输入法配置。
设置界面允许选择 Ctrl+Alt+F1～F12；两边必须使用同一套按键，两个目标不能使用相同按键。

## InputTip 设置

1. 将定制版放在独立目录，备份原版 `src/data`。不要让原版和定制版同时运行。
2. 在输入法中先验证两个固定按键：连续按繁体两次仍为繁体，连续按简体两次仍为简体。
3. InputTip → 输入法相关 → 简繁控制，核对按键并启用。功能默认关闭。
4. 规则管理 → 窗口，添加游戏进程的“字符集切换 - 强制繁体”。从窗口选择器获取真实进程名。
5. 按需添加其他程序的“强制简体”，或用 `.*` 建立简体兜底规则；精确游戏进程规则优先于兜底。

简繁动作和中文/英文状态、键盘布局动作使用独立冲突组，可共同匹配。
脚本保持当前中文输入法，不会自动选择别的中文输入法；如果游戏使用英文键盘，需要另外配置现有的中文键盘/状态规则。
只有规则触发后才启动短暂定时器：至少等待 150 ms，并等待修饰键释放；离开目标窗口、暂停或超时 1 秒均取消，只发送一次。

InputTip 无法通过这个按键接口读取或确认简繁状态。游戏不接受 IME 输入、聊天框尚未获得输入上下文、权限不匹配或快捷键冲突时，按键可能无效。
此时需要在目标游戏实测，或让输入法提供能够确认结果的固定状态接口；不能把“已发送按键”当作“已切换成功”。

## 更新与回退

本分支暂停启动更新、手动更新入口和独立 updater 的上游下载覆盖。旧配置中的更新开关也不能重新启用覆盖。
上游发布到 WinGet 的工作流仅允许在原仓库运行。

后续在干净的工作目录中同步：

```sh
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
git switch feature/chinese-script
git merge upstream/main
powershell -NoProfile -File tests/run.ps1
git push origin feature/chinese-script
```

如有冲突，逐项解决并复测。主分支同步不会自动把修改带入定制分支。
上游原版可能删除不认识的规则 ID，回退时请使用原版的独立数据备份，不要共用定制配置。

## 验证边界

`tests/run.ps1` 使用项目随附的 AutoHotkey v2.0.26（运行时不纳入 Git），执行：

- 主程序、updater、JAB 的加载/语法验证，不启动主程序。
- 41 项按键、定时、重复触发、焦点取消、超时和更新策略测试，发送器为测试替身，不向桌面发键。
- 30 项真实 INI 读写、规则解析/优先级、重复加载和中英文文案测试。
- 中英文原生设置窗口的隐藏创建与控件检查。

以上不等于游戏端联调通过。尚未安装定制版，尚未修改输入法，尚未验证暗黑 4 内的切换效果。
