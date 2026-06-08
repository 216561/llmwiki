# Visual Prompt Tuning

## 0. 元信息
- 标题：Visual Prompt Tuning
- 作者：Menglin Jia, Luming Tang, Bor-Chun Chen, Claire Cardie, Serge Belongie, Bharath Hariharan, Ser-Nam Lim
- 年份：2022
- 会议 / 期刊：arXiv preprint（论文中未明确说明正式发表会议；arXiv: 2203.12119）
- 研究方向关键词：Parameter-Efficient Transfer Learning, Visual Prompting, Vision Transformer, Fine-Tuning, Foundation Model Adaptation
- 论文链接：https://arxiv.org/abs/2203.12119
- 代码链接（如有）：https://github.com/kmnp/vpt

## 1. 研究背景

当下最准确的视觉识别模型通常依赖于适应大规模预训练基础模型（Foundation Models），这一趋势与自然语言处理（NLP）的发展相呼应。然而，适应这些大模型到下游任务面临显著挑战：最直接且通常最有效的方法是全量微调（Full Fine-Tuning），即端到端地更新整个预训练模型。该方法要求为每个任务单独存储和部署一整套 backbone 参数，对于现代基于 Transformer 的架构（如 ViT-Huge 的 632M 参数相比 ResNet-50 的 25M 参数）来说，存储成本极高且往往不可行。已有的参数高效迁移学习方法包括：仅微调分类头（Linear）、微调部分 backbone 层（Partial-k）、仅更新偏置项（Bias）、插入适配器模块（Adapter）、训练旁路网络（Sidetune）等。但这些方法在准确率上通常不及全量微调。与此同时，NLP 领域的 Prompt Tuning 方法（在输入空间添加可学习的连续向量）取得了令人瞩目的成果，受此启发，作者探索将类似思想应用于视觉 Transformer 的适应问题。

## 2. 任务定义

给定一个在大型数据集（如 ImageNet-21k）上预训练的视觉 Transformer 模型，目标是将其高效地适应到下游视觉识别任务（如图像分类、语义分割），在尽可能减少每任务可训练参数和存储成本的同时，保持或超越全量微调的性能。

## 3. 论文要解决的核心问题

**如何有效且高效地将大规模预训练视觉 Transformer 模型适应到下游任务？** 具体而言：能否在不更新 backbone 参数的情况下，通过在输入空间中引入少量可学习参数（Visual Prompts）来实现与全量微调相当甚至更优的性能？该方法能否在不同 backbone 规模、不同架构、不同预训练目标和不同下游任务上泛化？

## 4. 方法总览

Visual Prompt Tuning (VPT) 从 NLP 的 Prompt Tuning 中获得灵感，在预训练 Vision Transformer 的输入空间中引入少量任务特定的可学习连续向量（称为 prompts），并在下游训练期间冻结整个预训练 backbone，仅更新 prompts 和线性分类头。方法有两个变体：

- **VPT-Shallow**：仅在第一个 Transformer 层的输入序列前拼接 prompts。
- **VPT-Deep**：在每个 Transformer 层的输入序列前拼接 prompts（各层独立的 prompts）。

Prompts 以 prepend 方式插入到图像 patch embedding 序列中，与 [CLS] token 和图像 patch token 一起作为 Transformer 层的输入序列。对于 ViT-Base（86M 参数），50 个 shallow prompts 仅引入 0.038M 参数（0.04%），deep prompts 引入 0.46M 参数（0.53%）。

## 5. 方法关键模块

- **Prompt Tokens**：一组 d 维可学习连续向量（d 为 backbone 特征维度），每个 prompt 记为 p_k ∈ R^d。ViT 上 prompt 长度搜索范围为 {1, 5, 10, 50, 100, 200}，Swin 上为 {1, 5, 10, 50}。
- **Prepend 插入方式**：默认将 prompts 拼接到图像 patch 嵌入序列之前（而非之后），形成 [x_0, P, E_0] 的序列结构。由于 prompts 插入在位置编码之后，prompt 位置（前或后）数学上等价。
- **VPT-Shallow**：仅在第一层 L_1 的输入插入 prompts P，后续层沿用上一层的输出（包含 prompts 的隐层表示 Z_i）。
- **VPT-Deep**：在每个 Transformer 层 L_i 的输入插入独立的 prompts P_{i-1}，每层 prompts 不共享参数。
- **Linear Head**：可学习的线性分类头，将最终 [CLS] token 的嵌入 x_N 映射为类别概率分布。
- **VPT-Prefix（等价实现）**：推理时将 prompt 参数直接 prepend 到 Self-Attention 的 key/value 中，可显著降低大 p 值下的计算开销和显存。
- **Prompt 初始化**：默认使用 xavier uniform 随机初始化。论文也探索了基于下游任务类别 [CLS] 原型均值初始化（CLS initialization），但随机初始化在实践中表现更优。
- **Prompt Dropout**：VPT-Deep 上应用 dropout=0.1。

## 6. 关键公式与机制说明

**Patch 嵌入**：输入图像划分为 m 个固定大小 patch，每个 patch 投影到 d 维隐空间并添加位置编码：

e_0^j = Embed(I_j), \quad j = 1, 2, ..., m

**标准 ViT 公式**：第 i 层 Transformer 的输入为 [CLS] token x_{i-1} 和 patch 嵌入序列 E_{i-1} 的拼接：

[x_i, E_i] = L_i([x_{i-1}, E_{i-1}]), \quad i = 1, 2, ..., N

y = Head(x_N)

**VPT-Shallow 公式**：在第一层前将 prompts P 插入序列：

[x_1, Z_1, E_1] = L_1([x_0, P, E_0])

[x_i, Z_i, E_i] = L_i([x_{i-1}, Z_{i-1}, E_{i-1}]), \quad i = 2, 3, ..., N

**VPT-Deep 公式**：每层前插入该层专用 prompts P_{i-1}：

[x_i, \_, E_i] = L_i([x_{i-1}, P_{i-1}, E_{i-1}]), \quad i = 1, 2, ..., N

其中 Z_i ∈ R^{p×d} 是 prompts 经过第 i 层后的特征，[·, ·] 表示在序列长度维度上的拼接。所有 backbone 参数冻结（蓝色表示），prompts 和 head 可学习（红色表示）。每个 Transformer 层 Li 由多头自注意力（MSA）和前馈网络（FFN）组成，包含 LayerNorm 和残差连接。

## 7. 训练与推理流程

**训练流程**：
1. 加载预训练 backbone 并冻结其所有参数。
2. 在指定层（浅层仅第 1 层，深层所有层）的输入空间随机初始化 prompts。
3. 初始化线性分类头。
4. 端到端训练：仅更新 prompts 和分类头参数，通过反向传播优化。
5. 使用验证集搜索最优 prompt 长度 p（VPT 唯一的额外超参数）。
6. 优化器：VPT 使用 SGD（momentum=0.9）；Full/Partial/Bias/Adapter 使用 AdamW。
7. 学习率搜索范围（VPT）：{50.0, 25.0, 10.0, 5.0, 2.5, 1.0, 0.5, 0.25, 0.1, 0.05}，遵循线性缩放规则 lr = base_lr x batch_size / 256。
8. Cosine decay 学习率调度，10 个 warmup epoch。
9. 总 epoch：ViT-B/Swin-B 为 100，ViT-L/H 为 50。

**推理流程**：
1. 加载冻结的 backbone 和训练好的 prompts + 分类头。
2. 标准前向传播：图像经 Embed 层后与 prompts 拼接作为 Transformer 输入。
3. 取最终层 [CLS] token 的嵌入，通过分类头得到预测。
4. 可选 VPT-prefix 等价实现以降低计算开销。

## 8. 实验设置

**预训练 Backbone**：
- ViT-B/16（85M，d=768）、ViT-L/16（307M，d=1024）、ViT-H/14（630M，d=1280）——监督 ImageNet-21k
- ViT-B/16（MAE 自监督，ImageNet-1k）
- ViT-B/16（MoCo v3 自监督，ImageNet-1k）
- Swin-B（88M，监督 ImageNet-21k）
- ConvNeXt-B（88M，监督 ImageNet-21k）
- ResNet-50（23M，监督 ImageNet-1k）

**下游任务**：
- **FGVC（Fine-Grained Visual Classification）**：5 个细粒度分类任务（CUB-200-2011, NABirds, Oxford Flowers, Stanford Dogs, Stanford Cars）
- **VTAB-1k（Visual Task Adaptation Benchmark）**：19 个分类任务，每组 1000 训练样本（800 训练/200 验证），分为 Natural（7 任务）、Specialized（4 任务）、Structured（8 任务）三组
- **ADE20K 语义分割**：150 类别场景解析，使用 SETR-PUP（ViT-L/16 backbone）

**Baseline 方法**：
- Full（全量微调）、Linear（仅线性头）、Partial-1（微调最后 1 层）、Mlp-k（MLP 头）、Sidetune（侧网络）、Bias/BitFit（仅偏置）、Adapter（插入 MLP 模块）、VPT-shallow、VPT-deep

**训练配置**：PyTorch, NVIDIA A100-40GB GPU。图片分辨率默认 224x224（附加 384x384）。数据增强：FGVC 使用随机裁剪和水平翻转；VTAB-1k 仅 resize 至 224x224，不做增强。

## 9. 主要实验结果

**ViT-B/16 监督预训练（Table 1）—— 24 个下游任务**：

| 任务组 | Full | VPT-Shallow | VPT-Deep | VPT-Deep 胜场 vs Full |
|-------|------|------------|---------|---------------------|
| FGVC（5 任务平均）| 88.54 | 84.62 | **89.11** | 4/5 |
| VTAB-Natural（7 任务平均）| 75.88 | 76.81 | **78.48** | 6/7 |
| VTAB-Specialized（4 任务平均）| 83.36 | 79.66 | **82.43** | 2/4 |
| VTAB-Structured（8 任务平均）| 47.64 | 46.98 | **54.98** | 8/8 |

- **VPT-Deep 在 20/24 个任务上超越 Full**，可训练参数不足 backbone 的 1%（多个任务平均约 0.98%-1.14%），多任务存储代价仅 1.18x backbone vs Full 的 24.02x。
- **在所有参数高效方法中**，VPT-Deep 在 4 个任务组中全部最优，超越 Linear、Partial、Mlp、Sidetune、Bias、Adapter 等所有基线。
- **Structured 组提升最显著**：VPT-Deep 平均 +7.34 超越 Full（54.98 vs 47.64），8/8 任务全胜。
- **低数据场景**（Figure 3）：VPT-Deep 在所有训练数据规模（10%-80%）下持续优于 Full，而 Linear 和 Adapter 仅在低数据区域占优。

**不同 backbone 规模**（Figure 4，ViT-B/L/H）：VPT-Deep 在 Natural 和 Structured 组显著超越 Full，在 Specialized 组性能相当，优势随模型规模扩大保持。

**Swin-B**（Table 2）：VPT 在所有参数高效方法中仍最优。但 Full 整体表现最佳。与 ViT 不同，VPT-Shallow 在 Natural 组（79.85）优于 VPT-Deep（76.78）。

**不同预训练目标**（Table 4）：
- 监督 ImageNet-21k：VPT-Deep 最优（20/24 高于 Full）。
- MAE 自监督：VPT-Deep 表现很差（Natural 36.02 vs Full 59.29），远不如 Partial-1。
- MoCo v3 自监督：VPT-Deep 具有竞争力但非最优，Bias 和 Partial-1 表现更好。

**语义分割 ADE20K**（Table 3）：VPT-Deep（mIoU-SS 42.11）无法接近 Full（48.31），但以远少参数（13.43M vs 318.31M）接近 ResNet-101 全量微调（45.47）。

**ConvNet 适配**（Table 5）：ConvNeXt-B 上 VPT 在 Natural 组 6/7 任务超越 Full，但 Structured 组落后（44.64 vs 60.41）。ResNet-50 上 VPT 无明显优势。

**消融实验关键发现**：
- **Prompt 位置**：Prepend（默认）优于 Add、Prepend-pixel 和 Concat-channel。在 latent 嵌入空间比像素空间更适合 prompt。
- **Prompt 长度**：最优长度因任务而异。Structured 任务需更多 prompts（平均 107.5），Natural 较少（平均 12.4）。即使 p=1，VPT-Deep 仍显著优于其他基线。
- **Prompt 深度**：性能与插入层数正相关。早期层 prompts 比后期层更重要。
- **最终输出**：[CLS] token 与 Image-pool 效果相当，使用 Prompt-pool/Global-pool 性能下降。
- **输入序列长度 vs 可学习参数**：VPT 优势来自可学习参数本身，而非序列长度增加（冻结 prompt 后性能降至 Linear 水平）。
- **Prompt 初始化**：随机初始化（xavier uniform）优于基于类别 [CLS] 原型的初始化，与 NLP 领域结论不同。
- **VPT+Bias 组合**：不是互补方法，VPT-Deep+Bias 在所有三组 VTAB 任务上均降低 VPT-Deep 的性能。
- **Prompt Ensembling**：5 个不同种子的 prompts 集成，VPT-Deep 在低存储成本下获得确定性提升（+2.1~+4.7）。
- **统计显著性**：Wilcoxon signed-rank 检验确认 VPT-Deep 显著优于所有基线（p<0.05）；Welch t 检验在 127/152 对比中显著。

## 10. 论文贡献总结

1. **提出 VPT 方法**：首个将输入空间 prompt tuning 系统应用于视觉 Transformer 编码器（非文本编码器）的工作，引入小于 1% 的可训练参数即可适应下游任务。
2. **验证 VPT 超越全量微调**：在 24 个分类任务中，VPT-Deep 在 20 个任务上超越全量微调，同时多任务存储成本降低约 20 倍。这与 NLP 领域中 prompt tuning 仅能匹配但不超过全量微调的结论形成对比。
3. **系统性实验验证**：在多种 backbone（ViT-B/L/H, Swin, ConvNeXt, ResNet-50）、多种预训练目标（监督、MAE、MoCo v3）、多个任务领域（FGVC, VTAB, 语义分割）上进行全面评估。
4. **深入消融分析**：对 prompt 位置、长度、深度、初始化、共享策略、输出方式等设计维度进行系统消融，揭示了视觉 prompt 与文本 prompt 的根本性差异。
5. **开源代码**：提供完整可复现的代码、配置和逐任务结果。

## 11. 方法特点总结

- **参数高效**：可训练参数不足 backbone 的 1%，多任务场景存储优势显著。
- **输入空间操作**：不修改 backbone 结构或参数，仅修改输入序列，保持预训练知识完好。
- **架构无关（原则上）**：可应用于 ViT、Swin、ConvNeXt 等多种架构，但最佳表现于 ViT。
- **超参数简洁**：仅需额外调节 prompt 长度 p（其他超参数与基线一致）。
- **随机初始化即最优**：不同于 NLP prompt tuning 需要精心设计的初始化策略，VPT 的随机初始化效果最佳。
- **NLP prompt tuning 有根本性差异**：（1）VPT 超越全量微调；（2）随机初始化最优；（3）早期层 prompts 更重要——均与 NLP 的观察不同。
- **预训练目标依赖性强**：在监督预训练下表现极佳，在 MAE/MoCo v3 自监督下效果急剧下降。
- **小 backbone 上收益有限**：在 ResNet-50（23M）等较小模型上优势不明显，收益与 backbone 规模正相关。

## 12. 术语与概念表

| 术语 | 定义 |
|------|------|
| VPT (Visual Prompt Tuning) | 在视觉 Transformer 输入空间添加可学习 prompt 向量的参数高效微调方法 |
| VPT-Shallow | 仅在第一层 Transformer 输入插入 prompts |
| VPT-Deep | 在所有 Transformer 层输入插入 prompts（每层独立） |
| Prompt Token | 可学习的 d 维连续向量，作为额外 token prepend 到输入序列 |
| Prompt Length (p) | 每层插入的 prompt token 数量 |
| Prompt Depth | 插入 prompt 的 Transformer 层范围（多少层参与） |
| [CLS] Token | 分类标记（Class Token），其最终层嵌入用于分类头输入 |
| VTAB-1k | Visual Task Adaptation Benchmark，包含 19 个分类任务，每任务 1k 训练样本 |
| FGVC | Fine-Grained Visual Classification，细粒度视觉分类（5 任务） |
| Full Fine-Tuning | 更新所有 backbone 和分类头参数的标准微调方式 |
| BitFit / Bias | 仅更新 backbone 偏置项的参数高效微调方法 |
| Adapter | 在 Transformer 层内插入轻量 MLP 模块的参数高效微调方法 |
| Prompt Ensembling | 训练多个 prompts（不同种子），推理时批量推理取平均 |
| VPT-Prefix | VPT 的等价实现，将 prompt 参数 prepend 到 Self-Attention 的 key/value |
| Prompt-Fixed | 冻结 prompts 不更新的对照设置，用于验证可学习参数的必要性 |
| Shared-inter | 不同 Transformer 层间共享同一组 prompt 参数 |
| Shared-intra | 同一层内多个 prompt token 共享同一参数 |
| SETR-PUP | 使用 ViT 为编码器的语义分割框架，PUP 为渐进上采样策略 |
| Wilcoxon signed-rank test | 非参数配对单侧统计检验，用于验证 VPT-Deep 是否显著优于基线 |

## 13. 可复现信息

- **代码**：https://github.com/kmnp/vpt（论文中公开）
- **框架**：PyTorch，NVIDIA A100-40GB GPU
- **预训练 checkpoint**：均使用标准预训练模型（ViT/Swin 从标准库获取，如表 8 所示包含 checkpoint 来源列）
- **超参数搜索范围**：
  - Prompt 长度 p：ViT 上 {1, 5, 10, 50, 100, 200}，Swin 上 {1, 5, 10, 50}，ConvNet 上 {1, 3, 5, 7, 9, 11}
  - Adapter 缩减率 r：{8, 64, 256}
  - 学习率搜索范围：Table 6 完整列出
  - 优化器：VPT 使用 SGD（momentum=0.9），Full/Partial/Bias/Adapter 使用 AdamW
  - 学习率调度：Cosine decay + 10 warmup epochs
  - 总 epoch：100（ViT-B, Swin-B），50（ViT-L/H）
  - Batch size：按 backbone 和方法类型在 Table 8 中列出
- **数据**：所有数据集均为公开 benchmark（FGVC 5 个 + VTAB-1k 19 个 + ADE20K），数据获取方式在 Table 7 中说明
- **逐任务结果**：Appendix D（Table 13 和 Table 14）提供所有 24 个分类任务的逐任务结果、最优 prompt 长度和可训练参数比例
- **论文未明确说明**：单次完整训练的实际墙钟时间；不同 backbone 下 VPT 的具体 FLOPs 对比；多 GPU 分布式训练配置细节；VPT 在 ImageNet 全量（1.2M 样本）上的微调结果

## 14. 适合后续研究时重点关注的内容

1. **VPT 在自监督预训练下失效的根因**：MAE 和 MoCo v3 上 VPT 从最优变为接近最差（MAE Natural: 36.02 vs Full 59.29）。需要诊断这是否与 ViT 特征表示结构或注意力模式在自监督 vs 监督预训练下的差异有关，以及能否设计通用的 prompt 初始化策略解决。
2. **VPT 超越全量微调的理论解释**：为何在输入空间添加不到 1% 的可学习参数能超越更新全部 backbone 参数的全量微调？是否存在某种"特征保护"机制，使 prompts 在不破坏预训练知识的前提下引导模型聚焦任务相关特征？
3. **Prompt 长度与任务复杂度的关系**：Structured 任务需要更多 prompts（平均 107.5）而 Natural 任务较少（平均 12.4）。能否根据任务属性（类别数、任务类型、数据量）预测最优 prompt 长度？
4. **VPT 在更大数据规模上的表现**：VTAB-1k 仅 1k 训练样本，FGVC 数据量也不大。在 ImageNet 全量（1.2M）上 VPT 是否还能超越 Full？
5. **Prompt Ensembling 的实用价值**：在几乎无额外存储成本下获得确定性提升（+2-5%），值得研究能否成为实际部署的标准方案。
6. **Swin 上 VPT-Shallow > VPT-Deep 的反常现象**：是否与局部窗口注意力的特性有关——深层 prompts 在局部窗口间传播受限？
7. **VPT 在检测、视频理解等非分类任务上的表现**：论文仅验证了分类和分割，更广泛的任务有待探索。
8. **VPT 与 NLP prompt tuning 根本性差异的成因**：三个显著差异（VPT 超越 Full、随机初始化最优、早期层 prompt 更重要）暗示视觉和语言 Transformer 的参数高效微调机制存在本质区别，值得深入探究。

## 15. 一句话总结

VPT 通过在视觉 Transformer 输入空间添加不到 1% 的可学习 prompt 向量，在冻结 backbone 的情况下以 20/24 任务超越全量微调，多任务存储降低约 20 倍，但该优势在自监督预训练（MAE/MoCo v3）和小规模 backbone（ResNet-50）上显著减弱。
