# Reflexion: Language Agents with Verbal Reinforcement Learning

## 0. 元信息
- 标题：Reflexion: Language Agents with Verbal Reinforcement Learning
- 作者：Noah Shinn (Northeastern University), Federico Cassano (Northeastern University), Edward Berman (Northeastern University), Ashwin Gopinath (Massachusetts Institute of Technology), Karthik Narasimhan (Princeton University), Shunyu Yao (Princeton University)
- 年份：2023
- 会议 / 期刊：arXiv preprint (arXiv: 2303.11366v4, 10 Oct 2023)。论文中未明确说明最终接受的会议或期刊。
- 研究方向关键词：口头强化学习 (Verbal Reinforcement Learning)、语言智能体 (Language Agents)、自我反思 (Self-Reflection)、大语言模型 (Large Language Models)、序列决策 (Sequential Decision-Making)、代码生成 (Code Generation)、推理 (Reasoning)
- 论文链接：https://arxiv.org/abs/2303.11366
- 代码链接（如有）：https://github.com/noahshinn024/reflexion

## 1. 研究背景

大语言模型 (LLM) 已被越来越多地用于与环境（如游戏、编译器、API）交互的目标驱动型智能体。诸如 ReAct、SayCan、Toolformer、HuggingGPT、Generative Agents 和 WebGPT 等工作已经证明了基于 LLM 核心构建自主决策智能体的可行性。这些方法使用 LLM 生成文本和动作，进而用于 API 调用并在环境中执行。然而，由于这些模型参数量巨大，传统优化方案（如带梯度下降的强化学习）需要大量计算和时间，因此它们一直局限于使用上下文示例（in-context examples）来训练智能体。当前面临的挑战是如何让语言智能体通过试错快速高效地学习。

## 2. 任务定义

Reflexion 论文定义了三种类型的任务来评估其方法：

- **序列决策 (Sequential Decision-Making)**：智能体需要在交互式文本环境中完成多步任务。使用 AlfWorld 基准（134 个 unseen 环境，涵盖 6 种任务类型，包括寻找隐藏物品、移动物品、操作物品等）。
- **推理 (Reasoning)**：基于 Wikipedia 的多跳问答任务。使用 HotPotQA 数据集（113k 问答对，实验中使用 100 题）。
- **编程 (Programming)**：根据自然语言描述生成函数体。使用 HumanEval（164 题 Python）、MBPP（约 974 题）、LeetcodeHardGym（论文新提出，40 道 hard 级 Leetcode 题）以及 Rust 语言翻译版本（通过 MultiPL-E 工具）。

## 3. 论文要解决的核心问题

LLM 作为智能体时，传统强化学习方法需要大量训练样本和昂贵的模型微调，计算和时间成本高。现有方法（如 ReAct、CoT）虽能利用上下文示例指导行为，但缺乏从失败中高效学习的机制。论文的核心问题是：能否通过语言反馈（而非权重更新）来强化语言智能体，使其能够快速从试错中学习并改进？

## 4. 方法总览

Reflexion 提出一种基于"口头强化 (Verbal Reinforcement)"的新框架。该框架不更新模型权重，而是通过语言反馈信号来强化智能体。具体而言，Reflexion 智能体对任务反馈信号进行口头反思 (verbal reflection)，然后将反思文本保存在情景记忆 (episodic memory) 缓冲区中，用于在后续尝试中引导更好的决策。该框架包含三个核心模型：Actor（生成文本和动作）、Evaluator（评分输出的质量）、Self-Reflection（生成用于自我改进的口头强化提示）。整个过程模拟了一种类似于人类通过反思失败来改进计划的迭代学习方式。

## 5. 方法关键模块

**Actor (Ma)**：基于 LLM 构建，根据当前状态观察生成所需的文本和动作。类似传统基于策略的 RL 设置，在每个时间步从当前策略 πθ 采样动作 at 并接收环境观察 ot。论文探索了多种 Actor 模型，包括 Chain of Thought (CoT) 和 ReAct。Actor 还包含一个记忆组件 mem，提供额外上下文。

**Evaluator (Me)**：评估 Actor 生成输出的质量。输入为生成的轨迹 (trajectory)，输出反映任务表现优劣的奖励分数。论文探索了多种变体：对于推理任务使用精确匹配 (EM) 评分；对于决策任务使用预定义启发式函数或 LLM 本身作为 Evaluator；对于编程任务使用自生成的单元测试套件。

**Self-Reflection (Msr)**：基于 LLM 的自我反思模型。给定稀疏奖励信号（如二元成功/失败状态）、当前轨迹和持久记忆 mem，生成更具信息量的口头反馈。反馈存储到记忆 mem 中供后续尝试使用。

**记忆 (Memory)**：包含短期记忆和长期记忆。轨迹历史作为短期记忆，Self-Reflection 模型的输出存储在长期记忆中。长期记忆采用滑动窗口，最大容量 Ω 通常设为 1-3 条经验，受限于 LLM 的最大上下文长度限制。

## 6. 关键公式与机制说明

**强化学习形式化**：论文将 Reflexion 形式化为一个迭代优化过程。初始策略定义为 πθ(ai|si)，其中 θ = {Ma, mem}，即策略参数化为 Actor 模型和记忆编码的组合。

**迭代循环 (Algorithm 1)**：
1. 初始化 Actor (Ma)、Evaluator (Me)、Self-Reflection (Msr)
2. 初始化策略 πθ(ai|si)，θ = {Ma, mem}
3. 使用 πθ 生成初始轨迹 τ0
4. 使用 Me 评估 τ0，得到评分 r0 = Me(τ0)
5. 使用 Msr 生成自我反思 sr0，存入 mem ← [sr0]
6. 循环直到 Me 通过或达到最大尝试次数：
   - 使用 πθ 生成轨迹 τt = [a0, o0, ..., ai, oi]
   - 使用 Me 评估 τt
   - 使用 Msr 生成自我反思 srt
   - 将 srt 追加到 mem

**口头反馈放大机制**：将环境提供的二值或标量反馈（如 success/fail）通过 Self-Reflection 模型放大为更细粒度的自然语言经验总结。例如在编程任务中，失败的单元测试结果被转化为具体的改进建议。

**自生成单元测试**：编程任务中使用 CoT 提示生成多样化、全面的单元测试，然后通过 AST 语法过滤提取有效的测试语句，最后从测试集合中采样最多 n=6 个测试组成测试套件 T = {t0, t1, ..., tn}。

## 7. 训练与推理流程

Reflexion 框架不需要模型微调或梯度更新。推理流程如下：

1. **首轮尝试**：Actor 与环境交互生成轨迹 τ0。
2. **评估**：Evaluator 评分 r0 = Me(τ0)。
3. **自我反思**：Self-Reflection 模型分析 {τ0, r0} 生成总结 sr0，存入记忆 mem。
4. **迭代循环**：Actor、Evaluator、Self-Reflection 协同工作，每轮将新的反思 srt 追加到 mem，直到 Evaluator 判定 τt 正确或达到最大尝试次数。
5. **记忆管理**：长期记忆采用滑动窗口，保留最近 Ω 条经验（决策/推理任务 Ω=3，编程任务 Ω=1）。

## 8. 实验设置

**基准与数据集**：
- AlfWorld：134 个 unseen 文本家居环境，6 种任务类型。使用 ReAct 作为动作生成器，GPT-3 作为 LLM。提供 2 个 domain-specific few-shot trajectories。
- HotPotQA：从 113k 数据集中选取 100 个问题。CoT 实现使用 6-shot 提示，ReAct 使用 2-shot 提示，self-reflection 使用 2-shot 提示。
- HumanEval / MBPP / LeetcodeHardGym：标准代码生成设定。GPT-4 作为基础模型，零样本代码生成。Rust 结果通过 MultiPL-E 从 Python 翻译。
- WebShop（局限性实验）：100 个电商导航环境，2-shot ReAct + Reflexion，仅 4 轮后终止。

**基线方法**：ReAct only、CoT only、CoT (GT) only（给定 ground truth 上下文）、GPT-4 zero-shot、CodeT + GPT-3.5/Codex（作为 Previous SOTA）、不同模型的 HotPotQA 基线。

**Evaluator 设计**：
- AlfWorld：启发式（相同 action+response 超过 3 个循环或动作数超过 30 触发反思）或 GPT 二元分类。
- HotPotQA：精确匹配 (EM) 评分给出二值成功信号。
- 编程：自生成单元测试套件（最多 6 个测试），CoT 生成 + AST 语法过滤 + 采样。

**最大尝试次数**：AlfWorld 为 12 次连续 trial；HotPotQA 为连续 3 次失败后停止；编程任务论文中未明确指定。

## 9. 主要实验结果

**AlfWorld 序列决策**：
- ReAct + Reflexion (Heuristic) 完成 130/134 个任务（约 97%）。
- 相比 ReAct-only 有 22% 的绝对提升（12 次迭代学习步骤内）。
- ReAct-only 的性能在 Trial 6-7 间停滞，幻觉率收敛于 22%。
- 学习曲线显示 Trial 1-2 间有快速初始提升，随后 11 个 trials 内稳步提升至近乎完美。

**HotPotQA 推理**：
- Reflexion 整体改进约 20%。
- CoT (GT) + Reflexion 将正确率从 60%（text-davinci-003）提升至 77%。
- 所有基线方法（ReAct-only、CoT-only、CoT (GT)-only）在温度 0.7 下无法概率性地改进任何任务。
- Self-reflection 比纯 episodic memory 提供额外 +8% 绝对提升。

**编程任务**：
- HumanEval Python Pass@1 达 91.0%，超越 GPT-4 的 80.1%（Previous SOTA），+11% 提升。
- HumanEval Rust Pass@1 达 68.0%（GPT-4 基线 60.0%）。
- MBPP Python 是唯一反例：Reflexion 77.1% 低于 GPT-4 基线 80.1%——根因为 MBPP Python 的自生成单元测试假阳性率 (FP) 高达 16.3%（HumanEval Python 仅 1.4%）。
- MBPP Rust Pass@1 达 75.4%（GPT-4 基线 70.9%）。
- LeetcodeHardGym Python Pass@1 达 15.0%（GPT-4 基线仅 7.5%，翻倍但绝对水平低）。
- 论文偏好 false negative > false positive，因为 FN 时可通过 self-reflection 修正测试，但 FP 会导致无效提前提交。

**WebShop 局限性**：
- ReAct + Reflexion 未能显著超越 ReAct-only，4 trials 后终止。
- Reflexion 无法处理需要大量多样性和探索的任务。

**跨模型结果**：
- Reflexion 在 GPT-4、GPT-3.5-turbo、text-davinci-003 上均有效（提升 +0.12 至 +0.25）。
- Reflexion 在弱模型 Starchat-beta 上完全无效（Pass@1 0.26 无提升），表明自我纠正是较强模型的新兴能力。

**消融实验**（HumanEval Rust 50 最难题）：
- Base model（无 test generation，无 self-reflection）：Pass@1 = 0.60
- Test generation omission（无测试，有反思）：Pass@1 = 0.52（降低）
- Self-reflection omission（有测试，无反思）：Pass@1 = 0.60（与基线持平）
- Full Reflexion（两者皆有）：Pass@1 = 0.68（最优）
结论：self-reflection 和自生成单元测试两者缺一不可。

## 10. 论文贡献总结

1. 提出 Reflexion，一种基于"口头强化 (Verbal Reinforcement)"的新范式，将策略参数化为智能体的记忆编码与 LLM 参数的组合，无需模型微调即可通过语言反馈实现学习。
2. 探索并实证展示了 LLM 中自我反思 (self-reflection) 的新兴能力，证明其在少量 trial 内学习复杂任务的有效性。
3. 引入 LeetcodeHardGym，一个包含 40 道困难 Leetcode 题（GPT-4 训练截止日期后发布）、支持 19 种编程语言的代码生成 RL 环境。
4. 在多个任务上取得超越强基线的结果，并在多个代码生成基准上达到 SOTA——HumanEval Python 上 91% Pass@1。
5. 通过消融研究验证了不同反馈信号、反馈整合方法和智能体类型对性能的影响。

## 11. 方法特点总结

**优势**：
- 轻量级：无需微调 LLM，仅通过上下文更新实现改进
- 细粒度反馈：支持标量值和自由形式语言等多种反馈信号
- 可解释性强：通过显式自然语言形式的经验记忆提供清晰的决策依据
- 框架灵活：可集成不同类型的 Actor（CoT、ReAct）、Evaluator（启发式、LLM 分类、单元测试）和反馈来源（外部环境或内部模拟）
- 与不同 LLM backbone 兼容（GPT-4、GPT-3.5、text-davinci-003）

**劣势**：
- 依赖 LLM 的自我评估能力——弱模型（如 Starchat-beta）上完全无效
- 缺乏形式化的成功保证
- 记忆容量受限（通常 1-3 条经验）
- 在需要高度多样性和探索的任务（如 WebShop 电商搜索）上失效
- 自生成单元测试的质量直接影响代码生成结果——假阳性率是性能瓶颈

## 12. 术语与概念表

| 术语 | 英文 | 定义 |
|------|------|------|
| 口头强化 | Verbal Reinforcement | 通过自然语言反馈（而非权重更新）来强化智能体的方法 |
| 自我反思 | Self-Reflection | 对失败轨迹进行分析并生成自然语言改进建议的过程 |
| Actor | Actor | 基于 LLM 的策略模型，负责生成文本和动作 |
| Evaluator | Evaluator | 评估模型，对生成轨迹评分产生奖励信号 |
| Self-Reflection 模型 | Self-Reflection Model | 生成口头强化提示的模型，分析轨迹和奖励产生反思文本 |
| 短期记忆 | Short-term Memory | 轨迹历史，提供细粒度近期细节 |
| 长期记忆 | Long-term Memory | Self-Reflection 模型输出，存储提炼后的重要经验 |
| 情景记忆 | Episodic Memory (EPM) | 包含最近轨迹的记忆形式，用于消融实验对比 |
| 口头反馈放大 | Verbal Feedback Amplification | 将稀疏标量反馈信号通过语言模型转化为丰富自然语言反馈的过程 |
| 自生成单元测试 | Self-generated Unit Tests | 编程任务中通过 CoT 提示生成的单元测试套件（最多 6 个） |
| 假阳性 | False Positive (FP) | 单元测试通过但实际实现不正确的状态，导致无效提前提交 |
| 假阴性 | False Negative (FN) | 单元测试失败但实际实现正确的状态，可通过反思修正 |
| 口头强化学习 | Verbal Reinforcement Learning | 使用自然语言进行策略优化的强化学习方法 |

## 13. 可复现信息

- 完整实现、demo 和数据集已开源：https://github.com/noahshinn024/reflexion
- AlfWorld prompt 示例见论文 Appendix B（Page 13）
- 编程任务 prompt 示例见 Appendix C（Pages 14-16）
- 推理任务 prompt 示例见 Appendix D（Pages 17-19）
- AlfWorld 使用 134 个 unseen 环境（公开可用，Shridhar et al., 2021），GPT-3 作为 LLM
- HotPotQA 使用公开数据集（Yang et al., 2018）的 100 题子集
- HumanEval / MBPP 为标准公开 benchmark
- LeetcodeHardGym 为论文新提出，代码已开源
- MultiPL-E 用于 Python 到 Rust 的翻译
- 论文建议使用隔离执行环境运行自主代码编写实验

**论文未明确说明的信息**：
- 多 seed 运行的均值和标准差（仅 Table 4 Starchat-beta 实验提供了标准差）
- 统计显著性检验（p-value、confidence interval）
- 各实验的具体解码策略参数（温度等，仅 HotPotQA 基线注明 0.7）
- 每次推理的 token 消耗量
- 端到端 wall-clock 时间
- API 调用次数总计

## 14. 适合后续研究时重点关注的内容

1. **自生成单元测试质量控制**：MBPP Python 假阳性率 16.3%（vs HumanEval 的 1.4%）是代码生成反直觉失败的根本原因。如何在不依赖人工测试的情况下提升测试质量、能否提前预测 FP 率，是值得验证的关键问题。

2. **Self-reflection 的模型能力阈值**：Starchat-beta 上完全无效（Pass@1 0.26→0.26），GPT-4 上有效。哪些模型支持/不支持口头强化？能力阈值在哪里？

3. **WebShop 探索失败的根因**：Reflexion 无法处理高多样性探索任务。需要区分是记忆机制问题、evaluator 灵敏度问题、还是任务本身的根本性框架局限。

4. **记忆容量 vs 性能的关系**：论文使用 1-3 条经验但未系统探索该参数。更大或更小的记忆窗口会如何影响性能？

5. **Self-reflection 的信噪比与过滤机制**：哪些反思文本有效、哪些是噪声？是否需要打分或过滤机制？

6. **口头强化 vs 传统 RL 的效率对比**：论文声称轻量级但未做等样本/等计算量下的定量对比。

7. **MBPP Python 反例的应对策略**：FP 率 16.3% 时 Reflexion 不如基线——加入 FP 检测或回退机制是否可挽救？

8. **记忆组件的扩展**：论文建议未来使用向量嵌入数据库或传统 SQL 数据库替代当前滑动窗口机制。

9. **LeetcodeHardGym 的精读**：GPT-4 基线仅 7.5%，Reflexion 翻倍至 15% 但绝对水平仍很低——极端困难任务上口头强化提升空间有限。

10. **不同 Evaluator 信号类型的受控对比**：论文提及多种评估方式但未设计受控对比实验。

## 15. 一句话总结

Reflexion 提出一种无需模型微调的口头强化学习框架，通过让 LLM 智能体对失败轨迹进行自我反思并将反思文本存入记忆来指导后续尝试，在序列决策（AlfWorld +22%）、推理（HotPotQA +20%）和编程（HumanEval Python 91% Pass@1 SOTA）三个领域均显著超越基线，同时发现自我纠正是较强模型的新兴能力且依赖于可靠的自生成测试质量。