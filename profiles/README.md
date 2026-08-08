# Potato_Figure — profiles 说明
#
# 语义化颜色合同分两层：
#   generic_biomedical.yaml  — 通用生物医学语义（默认，随仓库发布）
#   user_project.yaml        — 项目专属语义（疾病分组/分子标志，自行维护，
#                               禁止提交到公开仓库，避免把个人课题混入通用版）
#
# 用法：在 agent 提示词或 Figure Contract 中声明使用哪个 profile，
#       颜色只从对应 profile 取值，禁止 panel 内硬编码。

# ---- generic_biomedical.yaml 示例（内置默认） ----
# CONTROL:   #595959   # 对照（细胞/动物/基线）
# TREATMENT: #C95A5A   # 处理/疾病/实验组
# UP:        #C95A5A   # 上调/正向
# DOWN:      #4F79A7   # 下调/负向
# HIGHLIGHT: #D88A24   # 重点标记
# NEUTRAL:   #D7D7D7   # 非显著/背景
# GROUP_1:   #C0442B   # 第一分组
# GROUP_2:   #9A9A9A   # 第二分组
# GROUP_3:   #2C6E9C   # 第三分组
# GREY:      #E6E6E6   # 弱信息
# HEAT_LOW / HEAT_MID / HEAT_HIGH: #2166AC / #F7F7F7 / #B2182B
