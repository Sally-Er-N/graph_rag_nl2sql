"""
NL2SQL Agent — LangChain 1.0

自主决策模式：agent 根据用户问题自行选择工具调用顺序，无固定流程。
需要先通过 Indexer 完成知识库构建才能使用。

依赖：langchain>=1.0, langchain-core>=0.3, langchain-openai>=0.3
"""
from langchain.agents import create_agent
from langchain_openai import ChatOpenAI

from .config import AppConfig
from .schema_reader import SchemaReader
from .schema_store import GraphStore, VectorStore
from .tools import build_tools

_SYSTEM = """你是一个专业的 MySQL SQL 生成助手。根据用户的自然语言问题，自主决定调用哪些工具、以何种顺序收集信息，最终生成SQL

可用工具说明：
- list_all_tables：列出数据库中所有表名和注释，适合在不确定有哪些表时使用
- search_tables：通过语义检索在知识库中找到与问题最相关的表（含外键扩展）
- search_columns：通过语义检索找到与问题相关的字段
- get_table_schema：获取指定表的完整结构（字段、类型、主键、索引、外键）
- get_join_paths：查询多张表之间的 JOIN 路径（含中间表）
- validate_sql：用 EXPLAIN 检测 SQL 语法，不执行查询，返回错误信息和性能警告
- execute_sql：执行 SELECT 语句并返回结果

SQL 生成规则：
- 只生成 SELECT 语句
- 表名和字段名用反引号包裹
- 多表必须用 JOIN，不用逗号连接
- 默认加 LIMIT 100
- validate_sql 返回 valid=false 时，根据 error 和 hint 修正后重新验证
- 有 warnings 时，在回答中告知用户潜在性能问题
"""


def build_agent(config: AppConfig):
    """
    构建 NL2SQL Agent（LangChain 1.0 create_agent）。
    需要先调用 Indexer.run() 完成知识库构建。

    返回 CompiledGraph，调用方式：
        result = agent.invoke({"messages": [("human", question)]})
        answer = result["messages"][-1].content
    """
    llm = ChatOpenAI(
        api_key=config.llm.api_key,
        base_url=config.llm.base_url,
        model=config.llm.model,
        temperature=config.llm.temperature,
    )

    schema_reader = SchemaReader(config.db.url, sample_rows=config.sample_rows)
    vector_store = VectorStore(
        persist_dir=config.chroma.persist_directory,
        embedding_model_name=config.embedding.model_name,
        batch_size=config.embedding.batch_size,
    )
    graph_store = GraphStore(
        uri=config.neo4j.uri,
        user=config.neo4j.user,
        password=config.neo4j.password,
        max_pool_size=config.neo4j.max_pool_size,
        connection_timeout=config.neo4j.connection_timeout,
        max_connection_lifetime=config.neo4j.max_connection_lifetime,
    )
    tools = build_tools(vector_store, graph_store, schema_reader, config.db.url)

    return create_agent(
        model=llm,
        tools=tools,
        system_prompt=_SYSTEM,
    )
