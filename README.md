# graph_rag_nl2sql

基于大模型 + 知识库的方式实现将自然语言转为SQL

工作流程：
  1. 用户输入自然语言查询
  2. Agent 通过工具搜索相关表、获取列结构、获取关联关系
  3. 大模型根据收集到的 schema 信息生成最终 SQL
  4. 通过 output_sql 工具输出结构化结果


## 使用

命令介绍：
-  index   — 构建知识库（必须先执行）
-  query   — 使用 SQLGenerator 直接生成并执行 SQL（轻量，无 Agent 循环）
-  agent   — 使用 Agent 模式交互（多工具调用，适合复杂问题）


用法介绍
-  python main.py index                          # 全量索引
-  python main.py index --tables orders users    # 指定表索引
-  python main.py index --status                 # 查看知识库状态
-
-  python main.py query "查询最近30天销售额最高的10个商品"
- python main.py query                          # 交互式
-
-  python main.py agent "查询用户订单详情"
-  python main.py agent                          # 交互式
