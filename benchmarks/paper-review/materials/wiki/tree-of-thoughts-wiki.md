# Tree of Thoughts: Deliberate Problem Solving with Large Language Models

## 0. 元信息
- 标题：Tree of Thoughts: Deliberate Problem Solving with Large Language Models
- 作者：Shunyu Yao（Princeton University）、Dian Yu（Google DeepMind）、Jeffrey Zhao（Google DeepMind）、Izhak Shafran（Google DeepMind）、Thomas L. Griffiths（Princeton University）、Yuan Cao（Google DeepMind）、Karthik Narasimhan（Princeton University）
- 年份：2023
- 会议 / 期刊：NeurIPS 2023（37th Conference on Neural Information Processing Systems）
- 研究方向关键词：大语言模型推理、思维链、树搜索、规划、自我评估
- 论文链接：https://arxiv.org/abs/2305.10601
- 代码链接（如有）：https://github.com/princeton-nlp/tree-of-thought-llm

## 1. 研究背景

大语言模型（LM）如 GPT 和 PaLM 在数学、符号、常识和知识推理等任务上展现出日益强大的能力。然而，其底层机制仍然是原始的从左到右、逐 token 的自回归生成方式。这种"快速、自动、无意识"的决策模式类似于认知心理学中"双过程模型"的"系统 1"，缺乏人类在复杂问题解决中使用的"系统 2"式的深思熟虑——即探索多样化的替代方案、自我评估当前状态、以及进行前瞻和回溯以做出全局决策。现有的提示方法（如 Input-Output prompting、Chain-of-Thought prompting 及其自一致性变体 CoT-SC）虽然取得了一定成功，但本质上是连续的 token 级或思维链级别的采样，缺乏对推理路径的局部探索和全局规划能力。论文因此提出 Tree of Thoughts（ToT）框架，将经典人工智能中的问题求解搜索方法（如 BFS、DFS）引入 LM 推理过程。

## 2. 任务定义

ToT 将任何问题求解形式化为一个在树上进行的搜索过程。树中的每个节点是一个状态 s = [x, z1...i]，代表输入 x 加上到当前为止的思维序列 z1...i 所构成的局部解。整体目标是从初始状态 x 出发，通过搜索树中找到一条通往可接受最终输出的路径。论文在三个异构任务上验证了 ToT：
- **Game of 24（24 点游戏）**：给定 4 个数字，使用基本算术运算（+、-、*、/）得到 24。输出应为使用每个数字恰好一次的有效等式。
- **Creative Writing（创意写作）**：给定 4 个随机句子，生成一篇连贯的 4 段文章，使每段分别以给定的一个句子结尾。
- **Mini Crosswords（5x5 迷你填字游戏）**：给定 5 条横向和 5 条纵向线索，输出一个 5x5 的字母网格解决填字游戏。

## 3. 论文要解决的核心问题

大语言模型在需要探索、战略性前瞻或初始决策至关重要的任务上表现不佳。具体而言，现有方法存在两个关键不足：（1）**局部层面**：不探索一个思维过程中的不同延续——即树的分支；（2）**全局层面**：不融入任何类型的规划、前瞻或回溯来帮助评估不同的选项——即人类问题求解中典型的启发式引导搜索。这些问题在实验中暴露显著：在 Game of 24 上，GPT-4 配合 Chain-of-Thought 提示仅达到 4% 的成功率，暴露了从左到右自回归解码在需要全局规划的任务上的根本局限性。

## 4. 方法总览

ToT 是一个用于 LM 推理的通用框架，它扩展了流行的 Chain-of-Thought（CoT）方法，允许 LM 在连贯的文本单元（"思维"，thoughts）上进行探索，这些单元作为问题求解的中间步骤。ToT 通过考虑多条不同的推理路径、自我评估选择来决定下一步行动，以及在必要时进行前瞻或回溯，使 LM 能够进行深思熟虑的决策。框架的核心是将任何问题形式化为在思维树上的搜索，并围绕四个关键问题构建具体实现：思维分解方式、思维生成策略、状态评估策略和搜索算法选择。ToT 支持如广度优先搜索（BFS）和深度优先搜索（DFS）等经典搜索算法与 LM 的语义级思维生成和自我评估能力相结合。

## 5. 方法关键模块

1. **思维分解（Thought Decomposition）**：根据问题特性将中间过程分解为思维步骤。一个思维可以是几个词（填字游戏）、一行方程式（24 点游戏）或一整段写作计划（创意写作）。思维应足够"小"以便 LM 生成多样化且富有前景的样本，又足够"大"以便 LM 评估其对问题求解的前景。

2. **思维生成器 G(pθ, s, k)**：给定树状态 s，生成 k 个候选项作为下一步思维。两种策略：
   - (a) **独立同分布采样（i.i.d.）**：使用 CoT 提示从 LM 中独立采样思维。适用于思维空间丰富（如整段写作计划）的场景。
   - (b) **顺序提议（Sequential propose）**：使用"提议提示"（propose prompt）在同一上下文中提议多个不同的下一步思维。适用于思维空间受限（如单个方程或单词）的场景，可避免重复。

3. **状态评估器 V(pθ, S)**：评估前沿状态集中各状态在求解问题上的进展，作为搜索算法的启发式。两种策略：
   - (a) **独立估值**：对每个状态 s 使用价值提示（value prompt）生成标量值（如 1-10 分）或分类（如 sure/likely/impossible），可通过少量前瞻模拟和常识来引导。
   - (b) **投票选择**：使用投票提示（vote prompt）让 LM 比较多个不同状态后选出最有希望的一个，适用于难以直接对成功性进行估值的情形。

4. **搜索算法**：
   - (a) **广度优先搜索（BFS）**：每步维护一组最具前景的 b 个状态（Algorithm 1）。用于树深度有限的任务（如 Game of 24 深度为 3，Creative Writing 深度为 2）。
   - (b) **深度优先搜索（DFS）**：优先探索最有前景的状态，直至达到最终输出或状态评估器判断不可解则回溯（Algorithm 2）。用于需要较深搜索的任务（如 Mini Crosswords 最多 10 步）。

## 6. 关键公式与机制说明

- **状态表示**：s = [x, z1...i]，其中 x 为输入，z1...i 为到当前步为止的思维序列。
- **IO 提示**：y ~ p_theta^IO(y|x) = p_theta(y | prompt_IO(x))
- **CoT 提示**：依次采样 z_i ~ p_theta^CoT(z_i | x, z_1...i-1)，然后 y ~ p_theta^CoT(y | x, z_1...n)
- **思维生成**：
  - i.i.d. 采样：z^(j) ~ p_theta^CoT(z_i+1 | s)，j=1...k
  - 顺序提议：[z^(1), ..., z^(k)] ~ p_theta^propose(z^(1...k)_i+1 | s)
- **状态评估**：
  - 独立估值：V(p_theta, S)(s) ~ p_theta^value(v | s)
  - 投票选择：V(p_theta, S)(s) = 1[s=s*]，其中 s* ~ p_theta^vote(s* | S)
- **BFS 核心逻辑（Algorithm 1）**：每步 t，从当前状态集 S_{t-1} 扩展生成候选集 S'_t，经评估后保留评分最高的 b 个状态进入下一步。
- **DFS 核心逻辑（Algorithm 2）**：从当前状态 s 出发，对生成的 k 个候选按评分排序，仅当候选的估值超过阈值 v_thres 时才继续深度搜索，否则剪枝并回溯。

## 7. 训练与推理流程

**推理流程**（无需额外训练，仅需预训练 LM）：
1. 将问题输入 x 封装为初始状态。
2. 根据任务设计思维分解方案，确定思维步数和每步的思维粒度。
3. 在每步使用思维生成器从当前状态扩展 k 个候选思维。
4. 使用状态评估器对所有候选状态进行估值（独立估值或投票）。
5. 根据搜索算法选择保留或扩展哪些状态：
   - BFS：保留评分最高的 b 个状态进入下一步。
   - DFS：按评分降序探索，低于阈值则剪枝回溯。
6. 重复步骤 3-5，直到达到最大步数或搜索到可接受的解。
7. 从搜索树中提取最终输出（BFS 取最优路径终点，DFS 取最深探索状态）。

论文中三个任务的具体配置：
- **Game of 24**：3 步 BFS，propose prompt 生成，sure/maybe/impossible 估值（每思维采样 3 次），b=5。
- **Creative Writing**：2 步 BFS（plan -> passage），i.i.d. 采样生成，vote 投票评估（每步投票 5 次），b=1。
- **Mini Crosswords**：DFS，propose prompt 生成（5 次提议聚合），per-clue possibility 评估 + confidence 排序，step limit=100，剪枝回溯。

## 8. 实验设置

- **主实验模型**：GPT-4（Chat Completion mode），采样温度 0.7，实验时间 2023 年 5 月 5-16 日。
- **对比模型**：GPT-3.5-turbo（附录 B.2）。
- **数据集**：
  - Game of 24：从 4nums.com 共 1362 道题中取按人类解题时间排序较难的 901-1000 号共 100 题作为测试集。评估指标为成功率（有效方程等于 24，每个数字恰好用一次）。
  - Creative Writing：从 randomwordgenerator.com 采样 100 组随机句子，每组 4 句作为段落结尾约束。无 groundtruth，使用 GPT-4 zero-shot 1-10 分连贯性评分（5 次平均）和人工偏好对比。
  - Mini Crosswords：从 GooBix 获取 156 道 5x5 填字游戏，取 1,6,...,91,96 共 20 题测试，136,141,146,151,156 共 5 题用于 prompt 构建。评估分 Letter/Word/Game 三级成功率。
- **Baseline 方法**：IO prompting（Game of 24 5-shot，Creative Writing zero-shot，Mini Crosswords 5-shot）、CoT prompting（相应 shot + 中间步骤）、CoT-SC（k=100，仅 Game of 24）、IO+Iterative Refine（Game of 24 k=10，Creative Writing k<=5）、Best of k sampling。
- **各方法采样数**：IO/CoT 在 Game of 24 上各 100 次，Creative Writing 上各 10 次，Mini Crosswords 上各 10 次。

## 9. 主要实验结果

**Game of 24**（Table 2）：
- IO prompt：7.3%，CoT prompt：4.0%，CoT-SC (k=100)：9.0%
- **ToT (b=1)：45%，ToT (b=5)：74%**
- IO+Refine (k=10)：27%，IO (best of 100)：33%，CoT (best of 100)：49%
- 误差分析（Figure 3b）：约 60% 的 CoT 样本在第一步已失败（如前三个词"4 + 9"），暴露了从左到右解码的局限性。

**Creative Writing**（Figure 5）：
- IO：6.19，CoT：6.93，**ToT：7.56**
- IO+refine：7.67，ToT+refine：7.91
- 人工对比（100 对）：ToT 优于 CoT 41 对，CoT 优于 ToT 21 对，两者相似 38 对。
- 5 次 GPT-4 评分标准差平均约 0.56。

**Mini Crosswords**（Table 3）：
- IO：Letter 38.7%, Word 14%, Game 0%；CoT：Letter 40.6%, Word 15.6%, Game 1/20
- **ToT：Letter 78%, Word 60%, Game 4/20 (20%)**
- +best state（oracle）：Word 67.5%, Game 7/20 (35%)
- -prune（无剪枝）：Word 41.5%, Game 5%；-backtrack（无回溯）：Word 20%, Game 5%

**补充任务**（Table 4, 零样本 ToT）：
- GSM8K（100 random subset）：CoT 86 → ToT 90（+4）
- StrategyQA（100 random dev）：CoT 82 → ToT 83（+1）

**跨模型实验**（Appendix B.2）：
- Game of 24：GPT-3.5 ToT 19% 远低于 GPT-4 的 74%，但"ToT > CoT > IO"顺序一致。
- Creative Writing：GPT-3.5 ToT 6.62 > GPT-4 IO 6.19 ≈ GPT-4 CoT 6.93，说明搜索增强可部分弥补模型能力差距。
- Generation vs Evaluation 瓶颈分析：GPT-4 gen + GPT-3.5 eval = 64%，GPT-3.5 gen + GPT-4 eval = 31%，表明 thought generation 是主要瓶颈。

## 10. 论文贡献总结

1. **提出 ToT 框架**：将经典搜索方法（BFS/DFS）与 LM 的语义级思维生成和自我评估相结合，使 LM 能够进行深思熟虑的决策，包括探索多条推理路径、自我评估、前瞻和回溯。
2. **系统性的实验验证**：在三个新颖的异构挑战任务（Game of 24、Creative Writing、Mini Crosswords）上验证了 ToT 的有效性，均显著超越 CoT、IO 等基线方法，最高取得 18.5 倍提升（Game of 24: 4% → 74%）。
3. **揭示自回归解码的局限性**：通过误差分析显示约 60% 的 CoT 样本在第一步即失败，暴露了从左到右 token 级生成模式在需要全局规划任务上的根本不足。
4. **概念统一性**：证明 IO、CoT、CoT-SC 可视为 ToT 的特例（有限深度和宽度的树），实现了多种推理范式的统一。
5. **框架的通用性和模块化**：在同一框架下通过不同的思维分解、生成、评估和搜索策略适配三种不同性质的任务，且无需额外训练。

## 11. 方法特点总结

- **通用性（Generality）**：IO、CoT、CoT-SC 和自精炼均可视为 ToT 的特殊情况（有限深度和宽度的树）。
- **模块化（Modularity）**：基础 LM、思维分解、思维生成、状态评估和搜索算法均可独立变化。
- **可适应性（Adaptability）**：可适应不同的问题特性、LM 能力和资源约束。
- **便利性（Convenience）**：无需额外训练，仅需预训练 LM 即可使用。
- **无需外部工具**：所有三个任务的实验均不依赖外部工具或知识库，完全利用 LM 自身的推理能力。
- **成本可控**：允许用户根据性能-成本权衡进行定制（如改变 beam size、vote 次数、few-shot vs zero-shot、GPT-3.5 vs GPT-4 等）。
- **可解释性**：思维树中的状态是 readable、high-level 的语言推理，而非隐式的低层次 token 值，有利于人类对齐和可解释性。

## 12. 术语与概念表

| 术语 | 英文 | 定义 |
|------|------|------|
| 思维（Thought） | Thought | 一个连贯的语言序列，作为问题求解的中间步骤（如方程、写作计划、填词） |
| 思维树 | Tree of Thoughts (ToT) | 将问题求解形式化为在树上搜索的框架，节点为包含输入和思维序列的状态 |
| 状态 | State | s = [x, z1...i]，表示包含输入 x 和到当前为止的思维序列 z1...i 的局部解 |
| 思维分解 | Thought Decomposition | 根据问题特性将推理过程拆分为中间思维步骤 |
| 思维生成器 | Thought Generator G() | 从给定状态生成 k 个候选下一步思维的模块 |
| 状态评估器 | State Evaluator V() | 评估各状态在求解问题上进展的启发式模块 |
| 提议提示 | Propose Prompt | 用于在同一上下文中顺序提议多个候选思维的提示方式 |
| 价值提示 | Value Prompt | 用于对单个状态进行独立估值（如 sure/maybe/impossible）的提示方式 |
| 投票提示 | Vote Prompt | 用于比较多个状态并投票选出最佳者的提示方式 |
| 广度优先搜索 | BFS (Breadth-First Search) | 每步保留 b 个最有前景状态的搜索算法 |
| 深度优先搜索 | DFS (Depth-First Search) | 优先探索最有前景状态直至终点或剪枝后回溯的搜索算法 |
| 剪枝 | Pruning | 评估器判定某状态不可解时，将其子树从搜索中移除 |
| 回溯 | Backtracking | 当前路径探索完毕后，返回到父状态继续探索其他分支 |
| 系统 1 / 系统 2 | System 1 / System 2 | 认知心理学概念：快速自动无意识 vs 慢速深思熟虑有意识的决策模式 |

## 13. 可复现信息

- **代码仓库**：https://github.com/princeton-nlp/tree-of-thought-llm（完整代码 + 所有 prompts + 轨迹日志）
- **Prompts 路径**：https://github.com/princeton-nlp/tree-of-thought-llm/tree/master/src/tot/prompts
- **Trajectories 路径**：https://github.com/princeton-nlp/tree-of-thought-llm/tree/master/logs
- **Game of 24 数据**：4nums.com 共 1362 题，测试取 901-1000 号，按人类解题时间排序
- **Creative Writing 数据**：从 randomwordgenerator.com 采样，每次 4 句，共 100 组
- **Mini Crosswords 数据**：GooBix 共 156 题，测试取 1,6,...,91,96 共 20 题
- **模型配置**：GPT-4 Chat Completion mode，采样温度 0.7
- **总实验成本估算**：Game of 24 主实验约 $74 + Creative Writing 约 $32 + Crosswords 约 $100，总计约 $206
- **实验时间**：2023 年 5 月 5-16 日

## 14. 适合后续研究时重点关注的内容

1. **搜索算法的扩展**：论文仅实验了 BFS 和 DFS，提及 A* 和 MCTS（蒙特卡洛树搜索）可作为未来工作。RAP 是同期工作，提出基于 MCTS 的方法，但其框架缺乏 ToT 的模块化灵活性。系统对比 BFS vs DFS vs MCTS 在同一任务上的表现是直接的研究方向。
2. **Thought Generation 瓶颈的根因**：实验表明 GPT-4 gen + GPT-3.5 eval = 64%，但反向组合仅 31%，thought generation 被确认为主要瓶颈。探索更优的生成策略（如结构化输出、更好的 prompt 设计、微调生成器）是改进 ToT 的关键路径。
3. **跨 LLM 泛化性**：仅测试了 GPT-4 和 GPT-3.5，未在 LLaMA、PaLM、Claude 等模型上验证。GPT-3.5 + ToT 可以超越 GPT-4 + IO/CoT 的现象表明搜索增强可部分弥补模型差距，值得在更多模型上验证。
4. **参数敏感性系统分析**：论文未提供 breadth 中间值（b=2,3,4）的扫描、temperature 消融、vote/value 采样次数消融、step limit 消融、多 seed 均值和标准差、统计显著性检验等。这些对 ToT 的实用性和可靠性至关重要。
5. **状态评估器的校准与改进**：Mini Crosswords 中即使游戏已解决，评估器仍可能误判某些词为"impossible"，暴露了知识不确定性问题。外部检索或网页交互可增强 LM 在此类场景下的评估能力。
6. **ToT 在真实应用中的有效性**：论文仅在三个受控构造的任务上验证，未在编程、数据分析、机器人、事实性问答等真实决策任务上测试。如论文所展望，随着 LM 在更多真实世界决策应用（编码、数据分析、机器人等）中部署，更复杂的任务将出现。
7. **微调方向**：论文提出使用 ToT 式的高级反事实决策（如对下一段落的潜在选择进行深思熟虑，而非预测下一个 token）来微调 LM，可能是增强 LM 问题求解能力的重要方向。

## 15. 一句话总结

Tree of Thoughts 通过将经典树搜索算法（BFS/DFS）与 LM 的语义级思维生成和自我评估相结合，使大语言模型能够进行深思熟虑的决策，在需要规划和搜索的复杂推理任务上（Game of 24 提升 18.5 倍、Mini Crosswords 词级成功率 60% 等）显著超越 Chain-of-Thought 等现有方法。