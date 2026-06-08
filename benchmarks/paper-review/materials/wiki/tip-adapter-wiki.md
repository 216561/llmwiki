# Tip-Adapter: Training-free Adaption of CLIP for Few-shot Classification

## 0. 元信息
- 标题：Tip-Adapter: Training-free Adaption of CLIP for Few-shot Classification
- 作者：Renrui Zhang*, Wei Zhang*, Rongyao Fang, Peng Gao†, Kunchang Li, Jifeng Dai, Yu Qiao, Hongsheng Li（*平等贡献，†通讯作者）
- 年份：2022 (arXiv: 2207.09519v1, 2022年7月19日)
- 会议 / 期刊：arXiv preprint
- 研究方向关键词：Vision-language learning, few-shot classification, cache model, CLIP adaption, training-free
- 论文链接：https://arxiv.org/abs/2207.09519
- 代码链接（如有）：https://github.com/gaopengcuhk/Tip-Adapter

## 1. 研究背景
CLIP（Contrastive Vision-Language Pre-training）通过大规模图像-文本对对比学习，提供了可迁移的视觉表示，并在零样本图像分类中展现出令人印象深刻的能力。为了进一步提升CLIP在下游任务上的适配能力，现有方法（如CoOp和CLIP-Adapter）提出微调额外的可学习模块，显著提升了少样本性能，但引入了额外的训练时间和计算资源消耗。论文提出一个关键问题：能否同时获得"零样本CLIP无需训练"和"训练方法强少样本性能"两者的优势？

## 2. 任务定义
论文聚焦于少样本图像分类（Few-shot Image Classification）任务。具体来说，给定一个N类的新数据集，每类提供K张标注图像作为训练样本（即K-shot N-class设置），模型需要在测试集的完整图像上进行分类。实验涵盖了1-shot、2-shot、4-shot、8-shot和16-shot多种设置，测试于完整测试集（而非小样本query set），与传统全量训练方法的评估方式一致。

## 3. 论文要解决的核心问题
如何在无需SGD训练的前提下，将少样本训练集中的新知识注入预训练的CLIP模型，使其少样本分类性能接近甚至达到需要训练的适配方法水平？进一步地，若允许极少量训练，能否以远少于现有方法的训练代价达到state-of-the-art？

## 4. 方法总览
论文提出Tip-Adapter（Training-free adaption method for CLIP），核心思路是通过少样本训练集构建一个key-value cache model作为非参数化适配器。该cache model以CLIP视觉编码器提取的少样本图像特征作为keys，以对应的one-hot标签向量作为values。推理时，测试图像的特征作为query，通过计算与cache中所有keys的余弦相似度来检索，加权聚合values得到适配器预测，再通过残差连接与CLIP原始预测融合。

在此基础上，Tip-Adapter-F进一步将cache中的keys解冻为可学习参数，通过少量epoch的SGD微调来提升性能。仅微调keys（冻结values和CLIP两个编码器）即可在极低的训练代价下达到SOTA。

## 5. 方法关键模块

**（1）Cache Model 构造**：给定K-shot N-class训练集共NK张图像，使用CLIP预训练视觉编码器提取每张图像的C维L2归一化特征，构成Ftrain ∈ R^(NK×C)作为keys。将对应标签转为N维one-hot向量，构成Ltrain ∈ R^(NK×N)作为values。

**（2）Few-shot Knowledge Retrieval**：测试图像特征ftest作为query，其与所有cache keys的亲和度通过A = exp(-β(1 - ftest Ftrain^T))计算，其中β为调节锐度的超参数。适配器的预测通过A与values的线性组合得到：A Ltrain。

**（3）Knowledge Incorporation**：通过残差连接将适配器预测与CLIP原始预测融合：logits = α A Ltrain + ftest Wc^T，其中Wc为CLIP文本编码器生成的分类器权重，α为残差比例。

**（4）Fine-tuning Variant（Tip-Adapter-F）**：将cache keys Ftrain解冻为可学习参数，冻结values Ltrain和CLIP的两个编码器，通过20 epoch SGD微调进行更新。

## 6. 关键公式与机制说明

**Cache Model 构造公式**：
Ftrain = Visual Encoder(I_K),   Ltrain = OneHot(L_N)

**亲和度计算（Eq. 3）**：
A = exp(-β(1 - ftest Ftrain^T))
其中ftest和Ftrain均为L2归一化，ftest Ftrain^T等价于余弦相似度。指数函数将相似度转为非负值，β控制锐度。

**最终预测（Eq. 4）**：
logits = α φ(ftest Ftrain^T) Ltrain + ftest Wc^T
其中φ(x) = exp(-β(1 - x))。α为残差比例，控制few-shot知识与CLIP先验知识的融合权重。

**多模态Cache视角（Eq. 9）**：
logits = α φ(ftest Fvis^T) Lvis + (ftest Ftex^T) Ltex
作者将式(4)重新解释为视觉缓存检索与文本缓存检索的结合，其中Ftex = Wc（CLIP分类器权重，即文本特征）, Ltex = I（单位矩阵）。

**与CLIP-Adapter的关系**：当设置W1 = Ftrain, W2 = Ltrain^T Wc^(-1), b1 = b2 = 0, φ(x) = exp(-β(1-x))时，CLIP-Adapter退化为Tip-Adapter的特例。

## 7. 训练与推理流程

**Tip-Adapter（训练无关版本）**：
1. 预处理：使用CLIP视觉编码器提取NK张训练图像的特征Ftrain，对应的one-hot标签为Ltrain
2. 推理时：对测试图像提取特征ftest → 计算与Ftrain的余弦相似度 → 指数激活（β=5.5）→ 加权聚合values → 与CLIP原始预测残差融合（α=1.0）→ 输出logits
3. 无需SGD训练，零额外训练时间

**Tip-Adapter-F（微调版本）**：
1. 以Tip-Adapter构造的cache keys Ftrain作为初始化
2. 冻结values Ltrain、CLIP视觉编码器和文本编码器
3. 仅对Ftrain进行SGD微调，batch size=256，lr=0.001，AdamW优化器+cosine scheduler
4. 除EuroSAT外所有数据集训练20 epoch，EuroSAT训练100 epoch
5. 训练后推理流程与Tip-Adapter相同

## 8. 实验设置

**数据集**：共11个广泛使用的图像分类数据集——ImageNet (1000类)、StanfordCars、UCF101、Caltech101、Flowers102、SUN397、DTD、EuroSAT、FGVCAircraft、OxfordPets、Food101。

**Few-shot设置**：1、2、4、8、16-shot，每类随机选取K张训练图像，测试于完整测试集。

**Baseline方法**：Zero-shot CLIP（无训练）、Linear-probe CLIP（训练线性分类器）、CoOp（可学习prompt，200 epoch）、CLIP-Adapter（两层MLP适配器，200 epoch）。

**模型配置**：默认CLIP backbone为ResNet-50视觉编码器 + Transformer文本编码器，权重预训练自[48]且冻结。ImageNet使用7模板prompt ensembling，其他10数据集使用单一半手工prompt。Tip-Adapter超参α=1.0（默认）、β=5.5（默认）。

## 9. 主要实验结果

**ImageNet (16-shot)**：Tip-Adapter无训练达到62.03%（+1.70%超越Zero-shot CLIP 60.33%），接近CLIP-Adapter 63.59%和CoOp 62.95%（两者均需200 epoch培训）。Tip-Adapter-F仅20 epoch（5分钟）达到65.51%，超越所有方法。

**效率对比**：Tip-Adapter-F训练时间仅为CLIP-Adapter的1/10（5min vs 50min），为CoOp的1/176（5min vs 14h40min）。推理速度10.42ms几乎等同于Zero-shot CLIP的10.22ms。GPU显存2227MiB与Zero-shot CLIP相同，CoOp需要7193MiB（3.2倍）。

**不同backbone (16-shot ImageNet)**：Tip-Adapter-F在ResNet-50 (65.51)、ResNet-101 (68.56)、ViT-B/32 (68.65)、ViT-B/16 (73.69)、RN50x16 (75.81)上均最优。论文未提供CoOp和CLIP-Adapter在RN50x16上的结果。

**10个其他数据集**：Tip-Adapter在全部10个数据集上无训练即提升Zero-shot CLIP。Tip-Adapter-F在所有数据集上一致最优。EuroSAT提升最大（约+33pp），Food101提升最小（约+0.51pp）。

**分布偏移鲁棒性 (ImageNet→ImageNetV2/Sketch)**：Tip-Adapter在ImageNet-Sketch上35.90%超越CLIP-Adapter 35.68%和CoOp 31.04%。Tip-Adapter-F在两个目标数据集上均为最优。

**对抗全量训练方法**：Tip-Adapter (ViT-L, 16-shot, 0参数) 达到76.1%，超越ResNet-50全量训练74.2%和DeiT-T全量训练72.2%。Tip-Adapter-F (6min) 达到79.4%，接近DeiT-S的79.9%。

## 10. 论文贡献总结

1. 提出Tip-Adapter，一种训练无关的CLIP适配方法，通过cache model直接注入少样本知识，无需SGD训练即可达到与训练方法可比的性能。
2. 提出Tip-Adapter-F，通过仅微调cache keys（20 epoch）即可达到SOTA性能，收敛速度比CoOp和CLIP-Adapter快10倍以上。
3. 在11个广泛使用的少样本分类数据集上进行全面实验和消融研究，验证了方法的有效性和通用性。
4. 揭示了cache model在分布偏移场景下比训练方法具有更强的鲁棒性（因训练无关构造减轻了过拟合风险）。
5. 证明了16-shot零参数Tip-Adapter即可超越全量训练的传统视觉模型（如ResNet-50）。

## 11. 方法特点总结

- **训练无关**：无需SGD训练即可生效，这是区别于CoOp和CLIP-Adapter最核心的特点
- **高度非参数化**：cache model直接从训练数据构造，不含随机初始化参数
- **极低推理开销**：额外计算仅为两个小矩阵乘法，推理速度几乎与Zero-shot CLIP无异
- **分布偏移鲁棒**：训练无关的构造缓解了少样本场景下的过拟合风险
- **可微调扩展**：解冻keys后仅需极少量epoch即可显著提升性能
- **多模态Cache**：天然结合了视觉和文本两种模态的缓存检索
- **与CLIP-Adapter的理论统一**：证明CLIP-Adapter可视为Tip-Adapter的特例

## 12. 术语与概念表

| 术语 | 英文 | 定义/说明 |
|------|------|----------|
| Cache Model | Cache Model | 以训练集特征为keys、标签为values的key-value存储结构 |
| Keys | Keys | cache model中的少样本训练图像特征（Ftrain） |
| Values | Values | cache model中的one-hot标签向量（Ltrain） |
| Residual Ratio α | Residual Ratio | 控制cache预测与CLIP原始预测融合比例的超参数 |
| Sharpness Ratio β | Sharpness Ratio | 控制亲和度计算中指数函数锐度的超参数 |
| Tip-Adapter | Tip-Adapter | 训练无关版本，直接构造cache model不训练 |
| Tip-Adapter-F | Tip-Adapter-F | 微调版本，解冻keys进行少量epoch SGD |
| Feature Retrieval | Feature Retrieval | 通过余弦相似度从cache中检索相关训练样本知识 |
| Prompt Ensembling | Prompt Ensembling | 使用多个手工prompt模板的结果取平均（ImageNet使用7模板） |
| Multi-modality Cache | Multi-modality Cache | 包含视觉缓存和文本缓存的异构缓存模型 |

## 13. 可复现信息

- 代码开源：https://github.com/gaopengcuhk/Tip-Adapter
- CLIP预训练权重从[48]获取（公开可用）
- 所有11个数据集均公开可获取
- 明确的数据预处理协议：同CLIP[48]（随机裁剪、缩放、随机水平翻转）
- 超参数：α=1.0（默认）、β=5.5（默认），batch size=256，lr=0.001，AdamW优化器+cosine scheduler
- 微调epoch：10个数据集20 epoch，EuroSAT 100 epoch
- 测试方式：完整测试集评估（非小样本query set）
- GPU：NVIDIA GeForce RTX 3090（单卡）
- 论文未提供：随机seeds列表、多次运行的均值和标准差、具体prompt模板文本（引用[48]）、代码依赖库版本、数据增强的详细参数（如裁剪尺寸）

## 14. 适合后续研究时重点关注的内容

1. **Training-free cache model的性能极限**：在更大shot（>128）下Tip-Adapter性能呈现饱和趋势，需要探究这是cache size瓶颈还是CLIP特征表达能力瓶颈。
2. **α随domain gap变化的定量评估**：论文仅定性说明domain gap越大α应越大，未给出跨数据集的实验验证。可建立domain gap度量与最优α的映射关系。
3. **分布偏移鲁棒性的深入分析**：仅做了ImageNet→ImageNetV2/Sketch两个目标数据集的验证，证据有限。需要更多目标域和更多源-目标对验证。
4. **Cache构造策略对比缺失**：仅使用随机分组平均构造原型，未比较K-means聚类、K-center选择等策略的影响。
5. **统计显著性缺失**：未报告多seed均值和标准差、p-value、置信区间等统计指标。
6. **跨数据集α/β最优值分布**：α=1.0, β=5.5对所有数据集是否均接近最优？这关系到方法的通用性和调参成本。
7. **非CLIP模型上的泛化**：仅使用CLIP backbone，未在其他预训练模型上验证cache model方法的通用性。
8. **微调收敛分析不足**：仅报告20 epoch后的结果，未提供loss/accuracy收敛曲线。

## 15. 一句话总结
Tip-Adapter通过从少样本训练集构建key-value cache model并直接检索，实现了无需SGD训练的CLIP少样本分类，性能接近需要200 epoch训练的方法，其微调变体Tip-Adapter-F仅需20 epoch（5分钟）即可达到SOTA。