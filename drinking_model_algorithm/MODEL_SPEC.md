# Drinking Tracker App
## Dynamic Standard Drink Model Specification
### Version 1.4 (Human-State Simulator UX Revision)
### Date: 2026-02-19

---

## 1. Purpose

本规范定义“人体酒精状态模拟器”的计算方法与展示策略。  
本版目标是同时满足：

1. 物理直觉：没酒精时不继续代谢，不透支未来。
2. 行为真实：吸收有延迟，不是入口即上升。
3. 用户可理解：默认只看“多久清空”，细节按需展开。
4. 工程可落地：支持极短时间连喝的稳定计算。

本模型用于行为提醒，不构成医疗、法律或驾驶建议。

---

## 2. Scope

### 2.1 In Scope

1. 标准杯摄入建模（含吸收延迟）。
2. 体内存量与代谢建模（非负、非透支）。
3. 极短间隔连喝的聚合规则（burst merge）。
4. 面向用户的“主信息 + 细节信息”分层展示规范。
5. 可运行的增量算法与验证协议。

### 2.2 Out of Scope

1. 医疗级 BAC 精确估计。
2. 个体差异深度建模（食物、药物、肝病等）。
3. 法律合规判断。

---

## 3. Core Concept (Human-State Simulator)

系统跟踪 `B(t)`（体内有效标准杯存量）作为内部状态：

```text
B(t) >= 0
display_sd(t) = B(t)
```

这是“人体吸收-代谢状态”的内部数值，不是主 UI 重点。  
主 UI 应回答：`我现在处于什么状态？还要多久清空？`

推荐状态阶段：

1. `准备吸收`：已记录饮酒，但仍在吸收延迟窗口。
2. `吸收上升`：`B(t)` 正在上升。
3. `代谢下降`：`B(t)` 正在下降。
4. `已清空`：`B(t)=0` 且后续不会因当前记录回升。

---

## 4. Symbols

1. `v_i`: 第 `i` 杯标准杯值（SD）。
2. `s_i`: 第 `i` 杯开始时间。
3. `e_i`: 第 `i` 杯结束时间。
4. `A(t)`: 截至 `t` 的累计吸收量。
5. `a(t)=dA/dt`: 瞬时吸收速率（SD/h）。
6. `r`: 代谢速率（SD/h）。
7. `B(t)`: 时刻 `t` 体内有效标准杯存量。

---

## 5. Configurable Parameters

1. `default_duration_minutes`：默认 `30`。
2. `metabolism_rate_sd_per_hour`：默认 `0.8`。
3. `absorption_lag_minutes`：默认 `15`。  
   含义：饮用后到吸收开始的延迟。
4. `min_absorption_duration_minutes`：默认 `20`。  
   含义：单次吸收窗口最短时长，避免异常陡峭。
5. `burst_merge_window_minutes`：默认 `2`。  
   含义：极短间隔记录合并为一个吸收块。

---

## 6. Drink Data Structure

每条输入记录至少包含：

1. `v_i: Double`（`>= 0`）
2. `s_i: Timestamp`
3. `e_i: Timestamp`（`e_i >= s_i`）

---

## 7. Timing and Burst Preprocessing

### 7.1 Base Timing

`Add Drink` 时：

1. `s_new = now`
2. 可选规则：上一杯 `e_prev = min(now, s_prev + default_duration)`
3. `e_new = s_new + default_duration`

### 7.2 Burst Merge Rule

按 `s_i` 升序后，若相邻记录开始时间差 `<= burst_merge_window_minutes`，合并为同一簇。  
每簇映射为一个“有效吸收块”：

```text
v_cluster = sum(v_i)
s_cluster = min(s_i)
e_cluster = max(e_i)
```

说明：保留原始记录用于审计/回放；模型计算使用合并后的簇。

---

## 8. Absorption Model (with Lag)

对每个有效吸收块 `j`（可是一杯或合并簇）：

```text
as_j = s_j + absorption_lag_minutes
ae_j = max(e_j + absorption_lag_minutes, as_j + min_absorption_duration_minutes)
```

吸收比例：

```text
if t <= as_j:        p_j(t) = 0
if as_j < t < ae_j:  p_j(t) = (t - as_j) / (ae_j - as_j)
if t >= ae_j:        p_j(t) = 1
```

累计吸收：

```text
A(t) = Σ_j [ v_j * p_j(t) ]
```

---

## 9. Physical Metabolism Model

连续形式：

```text
if B(t) > 0:
    dB/dt = a(t) - r
if B(t) = 0:
    dB/dt = max(0, a(t) - r)
```

结论：

1. 有存量才有代谢流出。
2. 无存量时不会继续扣减，不会产生负债。

---

## 10. Segment Update (Exact in Piecewise-Linear Regime)

在不跨越任何 `as_j/ae_j` 边界的子区间内，`a(t)=a_seg` 为常数。  
设 `dt_h`（小时）、起点存量 `B0`：

1. `B0 == 0` 且 `a_seg <= r`：`B1 = 0`
2. `B0 == 0` 且 `a_seg > r`：`B1 = (a_seg - r) * dt_h`
3. `B0 > 0` 且 `a_seg >= r`：`B1 = B0 + (a_seg - r) * dt_h`
4. `B0 > 0` 且 `a_seg < r`：`B1 = max(0, B0 - (r - a_seg) * dt_h)`

---

## 11. Runtime Algorithm

运行态：

1. `current_stock_sd`（`>= 0`）
2. `last_update_time`
3. `effective_drink_blocks[]`（burst 合并后）

刷新：

1. 先按当前参数生成有效吸收窗口 `[as_j, ae_j]`。
2. 将 `[last_update_time, now]` 以所有落入区间的 `as_j/ae_j` 切分。
3. 每段按第 10 节推进 `current_stock_sd`。
4. `last_update_time = now`。

---

## 12. Real-World Interpretation

### 12.1 Two drinks, wait 5 hours, then one drink

在默认参数（`r=0.8`，`lag=15`）下：

1. 前两杯早已代谢完，第三杯开始时 `B=0`。
2. 第三杯在 15 分钟内仍接近 0（吸收延迟）。
3. 之后才开始上升，不会被历史空窗“扣成负债”。

### 12.2 Five drinks logged within 1 minute

默认 `burst_merge_window=2` 时会合并为单簇，避免 5 条超短记录叠出不稳定尖峰。  
再叠加 `lag + min_absorption_duration`，可得到更合理的上升曲线。

---

## 13. User-Facing Output Guidance

### 13.1 Product principle

默认界面只回答一个问题：`还要多久清空？`  
具体数值（吸收到哪、当前多少 SD）放到 detail 页面按需查看。

### 13.2 Main card (default view)

1. 主指标：`距离代谢完成`（倒计时）
2. 次指标：`预计完成时间`（绝对时间，如 `01:40`）
3. 状态标签：`准备吸收 / 吸收上升 / 代谢下降 / 已清空`

### 13.3 Detail page (on demand)

若用户点开 detail，再展示：

1. `当前体内估计 SD`（`B(now)`）
2. `待吸收估计 SD`（`pending_sd(now)`）
3. `预计峰值 SD` 与 `峰值时间`
4. 最近一次饮酒记录时间、已持续代谢时长

其中：

```text
pending_sd(t) = Σ_j [ v_j * (1 - p_j(t)) ]
```

### 13.4 Definition of "distance to clear"

`距离代谢完成` 在本模型中的定义是：

```text
从当前时刻起不再新增饮酒输入时，
模型预测 B(t) 进入并持续保持 0 的剩余时间
```

也就是“模型中的体内有效标准杯最终清空时间”。

说明：

1. 不是“某一瞬间碰到 0 就算完成”。
2. 必须是“后续不会再因已记录饮酒而回升”的那个时刻。
3. 这样可以覆盖吸收延迟场景（例如刚喝完但尚未进入吸收）。

### 13.5 Human-feeling mapping (non-medical)

为增强“人体真实感受”的可解释性，可将状态标签映射为体验文案：

1. `准备吸收`：`刚喝完，身体反应可能还在延迟中`
2. `吸收上升`：`体内负荷正在上升，建议放慢节奏`
3. `代谢下降`：`体内负荷正在下降，继续补水和休息`
4. `已清空`：`模型估计本轮饮酒影响已清空`

这些文案是行为提示，不是医学判断。

### 13.6 Important disclaimer

`距离代谢完成` 仅表示本模型中的 `B(t)` 归零。

1. 它不直接等价于真实 BAC 测量值。
2. 它是行为提醒指标，不是医学结论。

建议 UI 固定文案：

1. 主标签：`预计代谢完成（模型）`
2. 副文案：`仅表示模型估计的体内有效标准杯最终清空时间。`

---

## 14. Validation Protocol

脚本：

`/Users/ryanlee/Development/AreUWorkingTmr/drinking_model_algorithm/validate_model.py`

运行：

```bash
cd /Users/ryanlee/Development/AreUWorkingTmr/drinking_model_algorithm
python3 validate_model.py
```

默认会输出两组候选相对“physical reference”的误差：

1. `Physical_v1.2+_runtime`
2. `Legacy_v1.1_bookkeeping`

---

## 15. Current Validation Snapshot (Default Cases)

基于当前默认参数和场景（2026-02-19）：

1. `Physical_v1.2+_runtime` 与 reference 误差为 `0`。
2. `Legacy_v1.1_bookkeeping` 在长间隔场景出现明显低估（可达 `0.6 SD`）。
3. Monte Carlo 200 组：
   - runtime-vs-reference worst error: `0.0000000000`
   - legacy-vs-reference worst error: `2.3906701761`

---

## 16. Acceptance Tests

至少覆盖：

1. `lag_single_drink`（10-20 分钟延迟验证）
2. `two_drinks_then_5h_then_one`
3. `long_gap_second_drink`
4. `one_minute_five_drinks_burst`
5. 随机 Monte Carlo 回归

---

## 17. Assumptions and Limitations

1. 吸收仍为线性近似，不是完整药代模型。
2. 参数是群体近似，不代表个体医学事实。
3. 不等价于呼气/血液 BAC 检测结果。

---

## 18. Migration Notes (v1.1 -> v1.4)

1. 废弃 `M(t)=r*(t-s_first)` 的连续全局扣减。
2. 废弃可跨时段结转的“负债”状态。
3. 增加 `absorption_lag_minutes`、`min_absorption_duration_minutes`。
4. 增加 `burst_merge_window_minutes` 和簇合并预处理。
5. 将回归测试加入 lag 与 burst 关键场景。
6. UI 改为“时间优先（主卡）+ 数值细节（detail）”。
7. 文案叙事从“水箱类比”改为“人体状态模拟器”。
