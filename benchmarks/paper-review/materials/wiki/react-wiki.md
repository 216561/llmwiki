# ReAct: Synergizing Reasoning and Acting in Language Models

## 0. 元信息
- 标题：ReAct: Synergizing Reasoning and Acting in Language Models
- 作者：Shunyu Yao, Jeffrey Zhao, Dian Yu, Nan Du, Izhak Shafran, Karthik Narasimhan, Yuan Cao
- 年份：2023
- 会议 / 期刊：ICLR 2023
- 研究方向关键词：大语言模型（LLM）、推理（Reasoning）、行动决策（Acting）、提示工程（Prompt Engineering）、few-shot learning
- 论文链接：https://arxiv.org/abs/2210.03629
- 代码链接（如有）：https://react-lm.github.io/

## 1. 研究背景

大语言模型（LLM）在语言理解和交互式决策任务上展现出惊人性能，但推理能力（如 chain-of-thought prompting）和行动能力（如动作规划生成）通常被作为独立课题研究。Chain-of-thought（CoT）推理虽然能引导模型逐步推导答案，但它是一个"静态黑箱"——模型仅依赖内部表征生成思考，不与外部世界交互，导致事实幻觉（hallucination）和错误传播问题。另一方面，将预训练语言模型用于交互式环境中的规划和行动（如 WebGPT、SayCan）的工作侧重于通过语言先验预测动作，但没有利用语言模型进行关于高层目标的抽象推理或维护工作记忆来支持行动。人类智能的一个独特能力是能够将面向任务的动作与言语推理无缝结合（内语言理论），这使得人类能够快速学习新任务、在未知情况下做出鲁棒决策。受此启发，论文提出 ReAct 范式，旨在将推理与行动协同起来。

## 2. 任务定义

ReAct 考虑一个通用的智能体与环境交互进行任务求解的设定。在时间步 t，智能体从环境中接收观测 o_t，并根据策略 pi(a_t|c_t) 执行动作 a_t，其中上下文 c_t = (o_1, a_1, ..., o_{t-1}, a_{t-1}, o_t)。论文在四个不同的 benchmark 上进行评估：(1) **HotpotQA** —— 多跳问答任务，需要基于两个或以上 Wikipedia 段落进行推理；(2) **Fever** —— 事实验证任务，每条声明标注为 SUPPORTS、REFUTES 或 NOT ENOUGH INFO；(3) **ALFWorld** —— 文本游戏，智能体需要在家中导航和操作物品完成高层目标；(4) **WebShop** —— 在线购物网站环境，基于用户指令通过网页交互购买商品。

## 3. 论文要解决的核心问题

1. **推理与行动的割裂**：现有方法要么只做推理（如 CoT），要么只做行动（如 Act-only），两者之间缺乏协同。推理无法从外部世界获取信息，行动缺乏高层推理指导。
2. **CoT 的事实幻觉问题**：仅依赖内部知识的推理导致 56% 的失败案例来自幻觉，且推理过程中的错误会传播累积。
3. **Act-only 的推理不足**：纯行动方法在需要复杂推理的任务中无法正确分解目标、跟踪进度或理解上下文。
4. **是否存在一种通用范式**能够在不同任务类型（知识密集型推理 vs. 交互式决策）上都协同利用推理与行动并带来系统性收益。

## 4. 方法总览

ReAct 的核心思路是将智能体的动作空间扩展为 A_hat = A U L，其中 L 是语言空间。在语言空间中的动作（称为 thought 或 reasoning trace）不改变外部环境，也不产生观测反馈，而是通过对当前上下文进行推理来组合有用信息，并更新上下文以支持后续推理或行动。论文主要使用冻结的大语言模型（PaLM-540B）通过 few-shot in-context examples 来生成领域特定的动作和自由形式的语言思考。每个 in-context example 是一个由人类标注的包含动作、思考和环境观测的完整轨迹。对于知识密集型推理任务，thought-action-observation 步骤密集交替出现；对于决策任务，思考仅稀疏出现在最相关的轨迹位置，由模型自主决定思考和动作的异步发生。

## 5. 方法关键模块

1. **Thought（推理轨迹）**：自由形式的语言思考，不改变外部环境，而是通过推理当前上下文来组合有用信息。可以执行多种功能：分解任务目标并创建行动规划、注入常识知识、从观测中提取重要信息、跟踪进度和转换行动规划、处理异常和调整行动规划。
2. **Action（动作）**：与外部环境交互的动作，不同任务有不同的动作空间：Wikipedia API 包括 search[entity]、lookup[string] 和 finish[answer]；ALFWorld 包括导航和物品操作（go to、take、open、put 等）；WebShop 包括 search、click、buy 等。
3. **Observation（观测反馈）**：动作执行后从环境返回的文本观测。
4. **Prompt 构建**：从训练集中随机选取若干案例，人工标注 ReAct 格式的完整轨迹作为 few-shot exemplars。HotpotQA 用 6 个，Fever 用 3 个，ALFWorld 每种任务类型用 3 个。

## 6. 关键公式与机制说明

ReAct 没有复杂的数学公式，其核心机制可以形式化描述如下：

- **扩展动作空间**：A_hat = A U L，其中 A 是原始环境动作空间，L 是语言空间。
- **思考动作**：a_hat_t in L 由模型生成，不触发环境反馈，仅更新上下文 c_{t+1} = (c_t, a_hat_t)。
- **策略**：pi(a_hat_t|c_t)，通过 LLM 的 few-shot prompting 实现。
- **推理-行动循环**：thought（推理）→ action（行动）→ observation（观测）→ thought（推理）→ ...，在推理任务中密集交替，在决策任务中稀疏异步。

论文没有使用强化学习或监督学习中的形式化损失函数。在 finetuning 实验中，使用 bootstrap 方法从 ReAct 生成的正确轨迹中收集 3,000 条数据，对较小的 PaLM-8B/62B 模型进行 finetuning，让模型学习生成完整的 thought-action-observation 轨迹。

## 7. 训练与推理流程

**推理流程（prompting 方法）**：
1. 构造包含 few-shot 例子的 prompt，每个例子由 thought-action-observation 交替组成。
2. 对于每个测试输入（问题/声明/指令），将其附加在 prompt 后输入 LLM（PaLM-540B）。
3. 模型逐步生成 thought → action → 等待环境返回 observation → 继续生成 thought，直到输出 finish 动作或达到最大步数。
4. 解码策略为 greedy decoding。CoT-SC 使用 temperature=0.7 采样 21 条轨迹后取多数答案。

**训练流程（finetuning 方法，仅在 HotpotQA 上实验）**：
1. 使用 ReAct prompting 在 HotpotQA 上生成大量轨迹。
2. 筛选出答案正确的轨迹（3,000 条）。
3. 使用这些轨迹作为训练数据，对 PaLM-8B/62B 进行 finetuning，让模型学习生成完整的推理-行动轨迹。
4. PaLM-8B 训练 4,000 步（ReAct/Act）或 2,000 步（Standard/CoT）；PaLM-62B 训练 4,000 步（ReAct/Act）或 1,000 步（Standard/CoT），batch size 64。

## 8. 实验设置

- **基础模型**：PaLM-540B（prompting），PaLM-8B/62B（finetuning），部分 GPT-3（text-davinci-002）补充实验。
- **数据集**：HotpotQA（7,405 test, fullwiki setting, EM 指标）、Fever（6,666 test, Accuracy）、ALFWorld（134 unseen eval games, 6 task types, Success Rate）、WebShop（500 test instructions, 1.18M products, Average Score + Success Rate）。
- **Baselines**：Standard prompting、CoT、CoT-SC（21 samples, temp=0.7）、Act-only、BUTLER（IL, 10^5 trajectories/task for ALFWorld）、IL/IL+RL（1,012 human trajectories for WebShop）、ReAct-IM（Inner Monologue 风格 dense thought ablation）。
- **外部工具**：HotpotQA 和 Fever 使用简单的 Wikipedia API（search、lookup、finish），限制每次只返回实体页面前 5 句，弱于 SOTA 检索器。
- **最大步数**：HotpotQA 7 步，Fever 5 步。
- **Prompt 构造**：ALFWorld 每任务类型从 3 条标注轨迹中选 2 条排列成 6 种 prompt；WebShop 使用 1-2 shot。

## 9. 主要实验结果

1. **知识密集型推理（HotpotQA + Fever）**：ReAct 在 Fever 上优于 CoT（60.9 vs 56.3 Acc），在 HotpotQA 上略逊于 CoT（27.4 vs 29.4 EM）。ReAct 在所有 benchmark 上优于 Act-only。最佳方法是 ReAct + CoT-SC 组合（HotpotQA 上 ReAct→CoT-SC 达 35.1 EM；Fever 上 CoT-SC→ReAct 达 64.9 Acc），仅需 3-5 个 CoT-SC sample 即可达到 21-sample CoT-SC 性能。

2. **交互式决策（ALFWorld）**：ReAct（best of 6）总体成功率 71%，大幅超过 Act（45%）和 BUTLER（37%），绝对提升分别为 26% 和 34%。ReAct 仅用 2-shot prompting 即超越使用 10^5 条 expert trajectories 训练的 BUTLER。

3. **交互式决策（WebShop）**：ReAct（2-shot）成功率 66.6%，超过 Act（55.6%）、IL+RL（42.0%）和 IL（19.5%），绝对提升分别为 11.0% 和 24.6%。

4. **Finetuning（HotpotQA）**：PaLM-8B finetuned ReAct 超越所有 PaLM-62B prompting 方法；PaLM-62B finetuned ReAct 超越所有 PaLM-540B prompting 方法，ReAct 从 prompting 下最差方法变为 finetuning 下最优方法。

5. **GPT-3 补充实验**：GPT-3（text-davinci-002）在 HotpotQA（30.8 EM）和 ALFWorld（78.4% SR）上均优于 PaLM-540B（29.4 EM, 70.9% SR），说明 ReAct 的有效性跨模型通用。

## 10. 论文贡献总结

1. 提出 **ReAct**，一种新的基于 prompt 的范式，在语言模型中协同推理与行动，用于通用任务求解。
2. 在四个不同 benchmark（HotpotQA、Fever、ALFWorld、WebShop）上进行广泛实验，展示了在 few-shot 学习设置下 ReAct 相对于纯推理或纯行动方法的优势。
3. 系统的消融实验和分析：揭示了推理任务中行动的重要性（减少幻觉）和交互任务中推理的重要性（稀疏思考优于密集思考）。
4. 分析了 ReAct 在 prompting 设置下的局限性，并进行了初步的 finetuning 实验，展示了通过额外训练数据改进的潜力。
5. 展示了 ReAct 的可解释性（人类可区分来自模型内部知识与外部环境的信息）和可诊断性，以及人类通过思考编辑进行在线行为纠正的能力。

## 11. 方法特点总结

- **直观易设计**：人类标注者只需在行动基础上用语言记录思考，无需特殊格式设计。
- **通用灵活**：灵活的思想空间和思考-行动发生格式使 ReAct 适用于不同任务（QA、事实验证、文本游戏、网页导航）。
- **高性能且鲁棒**：仅靠 1-6 个 in-context examples 即展现出强泛化能力，在所有领域持续优于纯推理或纯行动基线。
- **人类对齐与可控**：可解释的序列决策过程，人类可以随时通过编辑思考来纠正模型行为。
- **稀疏思考优于密集思考**：在交互式决策任务（ALFWorld）中，仅在关键决策点出现思考的稀疏模式（71% SR）远优于每步都有思考的密集模式（53% SR）。
- **事实性推理 vs. 推理灵活性 trade-off**：thought-action-observation 结构增强了基于事实的推理（幻觉率 0% vs CoT 56%），但降低了结构灵活性（推理错误率 47% vs CoT 16%）。

## 12. 术语与概念表

| 术语 | 解释 |
|------|------|
| Thought / Reasoning Trace | 语言空间中的动作，不改变外部环境，仅通过推理更新上下文 |
| Action | 与外部环境交互的动作，产生观测反馈 |
| Observation | 执行动作后从环境返回的文本反馈 |
| ReAct | 论文提出的推理+行动协同范式 |
| CoT (Chain-of-Thought) | 仅做推理的基线方法，模型逐步推导答案但不与外部交互 |
| CoT-SC (Self-Consistency) | CoT 的增强版，多次采样后取多数答案 |
| Act-only | 仅做行动（无推理思考），类 WebGPT 风格 |
| Hallucination | 模型生成不基于外部事实的信息，CoT 的主要失败模式 |
| BUTLER | ALFWorld 上的 IL 基线，使用 10^5 条 expert trajectories |
| Bootstrap Finetuning | 用 ReAct 自动生成的正确轨迹来 finetune 小模型的方法 |

## 13. 可复现信息

- **主要实验模型**：PaLM-540B（非公开模型，不可直接访问）。
- **GPT-3 实验**：text-davinci-002（可通过 OpenAI API 访问）。
- **Prompt 模板**：论文 Appendix C 提供了 HotpotQA、Fever、WebShop 和 ALFWorld 的完整 prompt 模板（Standard、CoT、Act、ReAct 格式）。
- **代码**：开源在 https://react-lm.github.io/，GPT-3 相关代码在 https://anonymous.4open.science/r/ReAct-2268/。
- **数据集**：HotpotQA、Fever、ALFWorld、WebShop 均为公开可用的 benchmark。
- **Finetuning**：使用 3,000 条 bootstrap 轨迹，batch size 64，训练步数在论文 Section B.1 中给出。
- **论文未提供**：Wikipedia API 调用的具体延迟、单次 inference 的 token 消耗、端到端 wall-clock time、GPU 显存/训练时间（finetuning 场景）、多 seed 运行的均值和标准差、统计显著性检验。

## 14. 适合后续研究时重点关注的内容

1. **Reasoning error（47%）的根因分析**：论文归因于结构约束降低灵活性、模型容易陷入重复循环，但未做受控实验验证。换用 GPT-4/Claude 等其他 LLM backbone 后是否改善值得验证。
2. **稀疏思考的最优密度**：ALFWorld 上稀疏 > 密集（71% vs 53%），但最优稀疏度未确定——每 N 步一个 thought？仅在状态切换点触发？需要系统扫描思考密度。
3. **搜索失败恢复策略**：23% 的 ReAct 失败来自搜索返回空或不含有效信息，模型一旦搜索失败很难恢复。加入 search reformulation 或 fallback retrieval 是否可改善？
4. **跨 LLM 泛化性**：仅在 PaLM 系列和 GPT-3 上测试，需要在更多模型（GPT-4、Claude、Llama 等）上验证 ReAct 是否为通用范式。
5. **Prompt 敏感性量化**：ALFWorld 上不同 prompt permutation 导致 avg 57% 与 best 71% 之间 14% 的差距，需要系统分析 prompt engineering 的影响。
6. **Hallucination 0% 的因果归因**：需要区分是 Wikipedia API 的信息贡献还是 ReAct 框架的机制贡献。
7. **人类-模型协作**：论文展示了人类通过思考编辑进行在线行为纠正的初步实验，值得系统研究。

## 15. 一句话总结

ReAct 通过让大语言模型交替生成自由形式的推理思考和任务特定的外部动作，在知识密集型推理（HotpotQA/Fever）和交互式决策（ALFWorld/WebShop）任务上均取得优于纯推理或纯行动的 few-shot 性能，同时大幅减少事实幻觉并提升可解释性。
