# Self-Test Report — LLMWiki Agent Benchmark

> 测试日期：2026-05-20 ~ 2026-05-22
> 测试方式：Claude Code 逐条在干净 session 喂给 agent

---

## 1. 测试结果汇总

| 指标 | 数值 |
|------|:----:|
| 总题数 | 35（Seed QA） |
| ✅ 完全通过 | **32 题 (91.4%)** |
| ⚠️ 部分通过 | **3 题 (8.6%)** |
| ❌ 不通过 | **0 题 (0.0%)** |
| 可回答率 | **100%** |

## 2. 逐题结果

| 题号 | 领域 | 题型 | 结果 | 说明 |
|:----:|------|:----:|:----:|------|
| Q1 | Distillation | 事实检索 | ✅ | ProCo metric 正确检索 |
| Q2 | Distillation | 跨论文比较 | ✅ | 长尾蒸馏 vs ProCo 方法区分正确 |
| Q3 | Distillation | 机制理解 | ✅ | Trajectory vs Snapshot 解释正确 |
| Q4 | OOD Detection | 跨论文比较 | ✅ | LSN vs NegPrompt 差异明确 |
| Q5 | OOD Detection | 机制理解 | ⚠️ | 缺定量细节：prompt 数(8 vs 2)和 epoch(25 vs 5) |
| Q6 | Spectrum | 机制理解 | ✅ | 5 步 pipeline 正确 |
| Q7 | Spectrum | 边界判断 | ✅ | 4 项局限正确 |
| Q8 | Autonomous Driving | 事实检索 | ✅ | PDQN 混合动作空间原因正确 |
| Q9 | Autonomous Driving | 边界判断 | ⚠️ | 缺 PALCAS 绝对碰撞率 2.45% |
| Q10 | Federated Learning | 机制理解 | ✅ | EASE 三个残差锚正确 |
| Q11 | Federated Learning | 跨域连接 | ✅ | FedHD↔Distillation 连接正确 |
| Q12 | Federated Learning | 事实检索 | ✅ | AgentReputation 分类正确 |
| Q13 | Cross-Domain | 跨域连接 | ✅ | 联邦蒸馏跨 3 域正确 |
| Q14 | Cross-Domain | 事实检索 | ⚠️ | 期望答案过时（14 篇非 6 篇 full-paper） |
| Q15 | Cross-Domain | 事实检索 | ✅ | 6 篇孤儿论文正确 |
| Q16 | LLM Reasoning | 事实检索 | ✅ | Predictive perplexity 正确 |
| Q17 | LLM Reasoning | 机制理解 | ✅ | 协同解码两局限正确 |
| Q18 | LLM Reasoning | 跨域连接 | ✅ | 模型级 vs 数据级蒸馏区分正确 |
| Q19 | LLM Reasoning | 跨论文比较 | ✅ | CoRD↔FedHD 共性区别正确 |
| Q20 | Federated Learning | 机制理解 | ✅ | FedSD2C 双层信息损失正确 |
| Q21 | Federated Learning | 跨论文比较 | ✅ | FedHAW hypergradient 洞察正确 |
| Q22 | Federated Learning | 跨论文比较 | ✅ | FedHarmony vs FedAvg 差异正确 |
| Q23 | Federated Learning | 机制理解 | ✅ | FedACT alignment scoring 因素正确 |
| Q24 | Federated Learning | 边界判断 | ✅ | FedACT 硬件和数字正确 |
| Q25 | Distillation | 事实检索 | ✅ | COBRA barycenter 计算正确 |
| Q26 | Distillation | 跨论文比较 | ✅ | COBRA vs RLDD 维度差异正确 |
| Q27 | Distillation | 机制理解 | ✅ | COBRA 兼容性原理正确 |
| Q28 | Distillation | 边界判断 | ✅ | RLDD 三组件贡献正确 |
| Q29 | Cross-Domain | 跨域连接 | ✅ | FedSD2C vs ProCo 哲学异同正确 |
| Q30 | Cross-Domain | 跨域连接 | ✅ | TAFAP vs CoRD 哲学共性正确 |
| Q31 | Cross-Domain | 机制理解 | ✅ | Cross-modal coupling 三重角色正确 |
| Q32 | Meta | 事实检索 | ✅ | 缺少的 comparison 页正确 |
| Q33 | Meta | 事实检索 | ✅ | 孤儿论文重组方案正确 |
| Q34 | Meta | 边界判断 | ✅ | 升级优先级正确 |
| Q35 | Meta | 事实检索 | ✅ | 4 项结构问题正确 |

## 3. 3 题部分通过分析

### Q5 — Positive vs negative prompt learning 差异

| 项目 | 内容 |
|------|------|
| **agent 正确回答了** | Positive 比 negative 需要更多 prompt 和训练 |
| **缺失细节** | 具体数字：8 个 prompt vs 2 个 prompt；25 epochs vs 5 epochs |
| **原因** | wiki LSN 论文页缺这些定量数字 |
| **修复** | P0：补充 LSN 论文页 Table 5 的具体数字 |

### Q9 — PALCAS 安全模型和关键数字

| 项目 | 内容 |
|------|------|
| **agent 正确回答了** | RSS 安全模型，MSR 93.33% |
| **缺失细节** | 绝对碰撞率 2.45% at 60% CAV |
| **原因** | wiki PALCAS 论文页未收录该数字 |
| **修复** | P0：补充 PALCAS 论文页实验结果 |

### Q14 — 当前 wiki 中 full-paper 论文

| 项目 | 内容 |
|------|------|
| **agent 正确回答了** | 有 full-paper 列表 |
| **期望答案过时** | 从 6 篇变为 14 篇（持续 ingest 升级） |
| **修复** | 更新期望答案或改为动态描述 |

## 4. Expansion QA（15 题）状态

| ID | 领域 | 题型 | 状态 | 说明 |
|:--:|------|:----:|:----:|------|
| N1 | Distillation | 机制理解 | 🔲 待执行 | CD UKT-UKF trade-off |
| N2 | Distillation | 机制理解 | 🔲 待执行 | SE2D 方法 |
| N3 | Distillation | 边界判断 | 🔲 待执行 | COBRA 低 IPC 鲁棒性 |
| N4 | Distillation | 跨域连接 | 🔲 待执行 | CD vs DD |
| N5 | Federated Learning | 事实检索 | 🔲 待执行 | FedHD 组件 |
| N6 | Federated Learning | 机制理解 | 🔲 待执行 | FedKPer forgetting |
| N7 | Federated Learning | 边界判断 | 🔲 待执行 | FedACT fairness |
| N8 | Federated Learning | 机制理解 | 🔲 待执行 | FSCLB 双 sketch |
| N9 | Federated Learning | 跨论文比较 | 🔲 待执行 | FedHarmony vs COBRA |
| N10 | Cross-Domain | 跨域连接 | 🔲 待执行 | 受控增量整合三域体现 |
| N11 | Cross-Domain | 跨域连接 | 🔲 待执行 | UKF vs FL forgetting |
| N12 | Cross-Domain | 跨域连接 | 🔲 待执行 | Matching 家族 |
| N13 | Meta | 事实检索 | 🔲 待执行 | Evidence_level 对 benchmark 影响 |
| N14 | Meta | 事实检索 | 🔲 待执行 | Method/Dataset/Metric 独立化进度 |
| N15 | Meta | 边界判断 | 🔲 待执行 | Wiki 改进优先级 |

## 5. 改进路线图

```
P0（立即修复）
├── 补充 LSN 论文页的 prompt 数 (8 vs 2) 和 epoch (25 vs 5)
├── 补充 PALCAS 论文页的绝对碰撞率 2.45%
└── 更新 Q14 期望答案为当前 14 篇 full-paper

P1（短期改进）
├── 创建首批 comparison 页 (LSN vs NegPrompt 优先)
├── 执行 Expansion 15 题的 Claude Code 测试
└── 修复 Q5/Q9 缺失的定量细节

P2（长期工程）
├── 创建 method/dataset/metric 独立页
├── 消除 6 篇孤儿论文
├── 每次 major ingest 后执行 5-8 题捞针
└── 新增论文后同步创建对应 QA
```

## 6. 与历史执行对比

| 指标 | 5/5 (初始 15 题) | 5/20 (Seed 35 题) | 本次提交 |
|:----:|:----------------:|:----------------:|:--------:|
| 题目数 | 15 | 35 | **50** |
| 已执行 | 0 | 35 | 35 / 50 |
| 可回答率 | — | 100% | 100% (Seed) |
| 完全通过率 | — | 91.4% | 91.4% (Seed) |
| 覆盖领域 | 4 | 7 | 7 |
| 题型数 | 3 | 6 | 6 |
