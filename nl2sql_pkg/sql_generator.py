"""
SQL 生成模块 — 独立于 Agent 可单独调用。

职责：
  1. 根据用户问题，从向量库检索相关表
  2. 从图库获取 JOIN 路径
  3. 用 LCEL 链（ChatPromptTemplate | LLM | SQLOutputParser）生成 SQL
  4. 用 EXPLAIN 验证 SQL 语法
  5. 返回 GenerateResult

使用方式：
  from nl2sql_pkg.sql_generator import SQLGenerator
  gen = SQLGenerator(config)
  result = gen.generate("查询最近30天每个用户的订单总金额")
  print(result.sql)
  print(result.warnings)
"""
import logging
import re
from dataclasses import dataclass, field
from typing import List, Optional

from langchain_core.output_parsers import BaseOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

from .config import AppConfig
from .schema_reader import SchemaReader
from .schema_store import GraphStore, VectorStore

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = """你是一个专业的DB助手，负责根据用户的自然语言问题生成对应的 SQL 查询语句。
请严格按照以下规则生成 SQL：
根据提供的数据库表结构和用户问题，生成准确的 SELECT SQL 语句。
规则：
- 只生成 SELECT 语句，不生成 DDL/DML
- 表名和字段名用反引号包裹
- 多表查询必须使用 JOIN，不用逗号连接
- 只输出 SQL，不要解释，不要 markdown 代码块
"""

_PROMPT = ChatPromptTemplate.from_messages([
    ("system", _SYSTEM_PROMPT),
    ("human",
     "数据库表结构：\n{schema_context}\n\n"
     "{join_hint}\n\n"
     "用户问题：{question}\n\n"
     "请生成对应的 MySQL SELECT SQL 语句："),
])


class SQLOutputParser(BaseOutputParser[str]):
    """去除 LLM 输出中的 markdown 代码块，返回纯 SQL 字符串。"""

    def parse(self, text: str) -> str:
        text = text.strip()
        if text.startswith("```"):
            lines = [l for l in text.split("\n") if not l.startswith("```")]
            text = "\n".join(lines).strip()
        return text

    @property
    def _type(self) -> str:
        return "sql_output_parser"


@dataclass
class GenerateResult:
    sql: str
    valid: bool
    error: Optional[str] = None
    hint: Optional[str] = None
    warnings: List[str] = field(default_factory=list)


class SQLGenerator:

    def __init__(self, config: AppConfig):
        self.config = config
        self._chain = None
        self._vector_store: Optional[VectorStore] = None
        self._graph_store: Optional[GraphStore] = None
        self._schema_reader: Optional[SchemaReader] = None
        self._engine = None

    def _init(self):
        if self._chain is not None:
            return
        llm = ChatOpenAI(
            api_key=self.config.llm.api_key,
            base_url=self.config.llm.base_url,
            model=self.config.llm.model,
            temperature=self.config.llm.temperature,
        )
        self._chain = _PROMPT | llm | SQLOutputParser()
        self._vector_store = VectorStore(
            persist_dir=self.config.chroma.persist_directory,
            embedding_model_name=self.config.embedding.model_name,
            batch_size=self.config.embedding.batch_size,
        )
        self._graph_store = GraphStore(
            uri=self.config.neo4j.uri,
            user=self.config.neo4j.user,
            password=self.config.neo4j.password,
            max_pool_size=self.config.neo4j.max_pool_size,
            connection_timeout=self.config.neo4j.connection_timeout,
            max_connection_lifetime=self.config.neo4j.max_connection_lifetime,
        )
        self._schema_reader = SchemaReader(self.config.db.url, sample_rows=0)
        self._engine = create_engine(self.config.db.url)

    def validate(self, sql: str) -> GenerateResult:
        """用 EXPLAIN 检测 SQL 语法，返回 GenerateResult。"""
        self._init()
        stripped = sql.strip().lstrip(";").strip()
        if not stripped.upper().startswith("SELECT"):
            return GenerateResult(sql=sql, valid=False, error="只支持检测 SELECT 语句")

        warnings = []
        try:
            with self._engine.connect() as conn:
                result = conn.execute(text(f"EXPLAIN {stripped}"))
                rows = result.fetchall()
                keys = list(result.keys())
            explain_rows = [dict(zip(keys, row)) for row in rows]
            for row in explain_rows:
                table = row.get("table", "")
                type_ = str(row.get("type", "")).lower()
                extra = str(row.get("Extra", "")).lower()
                rows_est = row.get("rows", 0)
                if type_ == "all":
                    warnings.append(f"表 `{table}` 全表扫描，建议添加索引")
                if "using filesort" in extra:
                    warnings.append(f"表 `{table}` 使用文件排序，ORDER BY 字段建议加索引")
                if "using temporary" in extra:
                    warnings.append(f"表 `{table}` 使用临时表，GROUP BY/DISTINCT 可能较慢")
                if isinstance(rows_est, int) and rows_est > 100000:
                    warnings.append(f"表 `{table}` 预估扫描 {rows_est} 行，查询可能较慢")
            return GenerateResult(sql=sql, valid=True, warnings=warnings)
        except SQLAlchemyError as e:
            err_msg = str(e.orig) if hasattr(e, "orig") and e.orig else str(e)
            return GenerateResult(
                sql=sql,
                valid=False,
                error=err_msg,
                hint=_mysql_error_to_hint(err_msg),
            )

    def generate(self, question: str, top_k: int = 5) -> GenerateResult:
        """
        根据自然语言问题生成 SQL，并自动做语法验证。

        Returns:
            GenerateResult，包含 sql、valid、error、hint、warnings。
        """
        self._init()

        # 1. 混合检索相关表（RRF 重排序，score 越大越相关）
        table_results = self._vector_store.search_tables(question, top_k=top_k)
        table_names = [t for t, _ in table_results]

        # 2. 图库扩展外键关联表
        expanded = set(table_names)
        for t in table_names:
            expanded.update(self._graph_store.get_related_tables(t, depth=1))
        all_tables = list(expanded)
        logger.info(f"相关表: {all_tables}")

        # 3. 获取每张表的完整 schema（优先从 ChromaDB 缓存）
        schema_parts = []
        for table_name in all_tables:
            cached = self._vector_store.get_table_schema_from_cache(table_name)
            if cached:
                schema_parts.append(cached)
            else:
                try:
                    schema = self._schema_reader._read_table(table_name)
                    schema_parts.append(schema.to_text())
                except Exception as e:
                    logger.warning(f"读取表 {table_name} 失败: {e}")

        # 4. 获取 JOIN 路径
        join_paths = self._graph_store.get_join_paths(all_tables)
        join_hint = ""
        if join_paths:
            lines = [
                f"  {p['from_table']}.{p['from_col']} = {p['to_table']}.{p['to_col']}"
                for p in join_paths
            ]
            join_hint = "可用的 JOIN 条件:\n" + "\n".join(lines)

        # 5. LCEL 链生成 SQL（prompt | llm | SQLOutputParser）
        schema_context = "\n\n".join(schema_parts)
        sql = self._chain.invoke({
            "schema_context": schema_context,
            "join_hint": join_hint,
            "question": question,
        })
        logger.info(f"生成 SQL: {sql}")

        # 6. 语法验证
        result = self.validate(sql)
        if not result.valid:
            logger.warning(f"SQL 验证失败: {result.error} — {result.hint}")
        elif result.warnings:
            logger.info(f"SQL 性能警告: {result.warnings}")

        return result

    def close(self):
        if self._graph_store:
            self._graph_store.close()


def _mysql_error_to_hint(err_msg: str) -> str:
    patterns = [
        (r"Table '.*?' doesn't exist",       "表不存在，请检查表名是否正确"),
        (r"Unknown column '.*?'",             "字段不存在，请检查字段名是否正确"),
        (r"You have an error in your SQL",    "SQL 语法错误，请检查关键字、括号、引号是否匹配"),
        (r"Column '.*?' in .* is ambiguous",  "字段名歧义，多表查询时请加表名前缀"),
        (r"Unknown table '.*?'",              "JOIN 中引用了未知表，请检查表名"),
        (r"Subquery returns more than 1 row", "子查询返回了多行，请使用 IN/EXISTS 替代 ="),
        (r"Division by zero",                 "除零错误，请检查 WHERE 条件或计算表达式"),
    ]
    for pattern, hint in patterns:
        if re.search(pattern, err_msg, re.IGNORECASE):
            return hint
    return "SQL 存在错误，请根据 error 字段信息修正"
