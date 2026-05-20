"""
LangChain 1.0 Tool 定义，供 Agent 调用。

工具列表：
  1. list_all_tables  — 直接查询 MySQL，列出所有表名和注释
  2. search_tables    — 向量+关键词混合检索相关表，图库扩展外键关联表
  3. search_columns   — 向量检索相关字段
  4. get_join_paths   — 图库查询多跳 JOIN 路径
  5. get_table_schema — 从 ChromaDB 缓存读取表结构，回退到直连 DB
  6. validate_sql     — MySQL 语法检测（EXPLAIN 预检，不执行查询）
  7. execute_sql      — 只读 SELECT 执行
"""
import json
import re
from typing import List

from langchain_core.tools import tool
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

from .schema_reader import SchemaReader
from .schema_store import GraphStore, VectorStore


def build_tools(
    vector_store: VectorStore,
    graph_store: GraphStore,
    schema_reader: SchemaReader,
    db_url: str,
) -> list:
    """工厂函数，将依赖注入到各工具闭包，返回工具列表。"""

    ro_engine = create_engine(db_url)

    @tool
    def list_all_tables(dummy: str = "") -> str:
        """列出数据库中所有表的名称和注释，直接查询 MySQL information_schema。
        当不确定有哪些表时，优先调用此工具获取全貌。
        输入: 无需输入（传空字符串即可）。
        输出: JSON 数组，每项包含 table_name、table_comment。
        """
        try:
            with ro_engine.connect() as conn:
                result = conn.execute(text(
                    "SELECT TABLE_NAME, TABLE_COMMENT "
                    "FROM information_schema.TABLES "
                    "WHERE TABLE_SCHEMA = DATABASE() "
                    "ORDER BY TABLE_NAME"
                ))
                rows = result.fetchall()
            tables = [{"table_name": r[0], "table_comment": r[1] or ""} for r in rows]
            return json.dumps(tables, ensure_ascii=False)
        except Exception as e:
            return f"查询表列表失败: {e}"

    @tool
    def search_tables(query: str) -> str:
        """根据自然语言查询检索最相关的数据库表名。
        使用向量语义检索 + 关键词匹配双路信号，通过 RRF 重排序合并结果，
        并通过外键关系自动扩展关联表。
        输入: 用户的自然语言问题或关键词。
        输出: JSON 数组，每项包含 table_name、rrf_score（越大越相关）、source。
        """
        # search_tables 返回 [(table_name, rrf_score)]，score 越大越相关
        results = vector_store.search_tables(query, top_k=5)
        expanded: dict = {}
        for table_name, rrf_score in results:
            expanded[table_name] = {"rrf_score": rrf_score, "source": "hybrid"}
            for related in graph_store.get_related_tables(table_name, depth=1):
                if related not in expanded:
                    expanded[related] = {"rrf_score": None, "source": "fk_expand"}

        output = [{"table_name": t, **v} for t, v in expanded.items()]
        return json.dumps(output, ensure_ascii=False)

    @tool
    def search_columns(query: str) -> str:
        """根据自然语言查询检索最相关的字段信息。
        输入: 用户的自然语言问题或字段描述关键词。
        输出: JSON 数组，每项包含 table_name、column_name、col_type、comment、primary_key。
        """
        results = vector_store.search_columns(query, top_k=10)
        return json.dumps(results, ensure_ascii=False)

    @tool
    def get_join_paths(table_names_json: str) -> str:
        """查询给定表列表之间的所有 JOIN 路径，包含多跳中间表路径。
        输入: JSON 数组字符串，如 ["orders", "customers", "order_item"]。
        输出: JSON 数组，每项包含 from_table、from_col、to_table、to_col、path_tables（完整路径）。
        """
        try:
            tables: List[str] = json.loads(table_names_json)
        except json.JSONDecodeError:
            return '输入格式错误，请传入 JSON 数组，如 ["table1", "table2"]'
        paths = graph_store.get_join_paths(tables)
        return json.dumps(paths, ensure_ascii=False)

    @tool
    def get_table_schema(table_name: str) -> str:
        """获取指定数据库表的完整结构（字段、类型、注释、主键、索引、外键）。
        优先从知识库缓存读取，无需连接数据库。
        输入: 表名字符串。
        输出: 表结构的文本描述。
        """
        cached = vector_store.get_table_schema_from_cache(table_name)
        if cached:
            return cached
        try:
            schema = schema_reader._read_table(table_name)
            return schema.to_text()
        except Exception as e:
            return f"获取表结构失败: {e}"

    @tool
    def validate_sql(sql: str) -> str:
        """检测 SQL 语句的语法是否正确，不执行查询，不返回数据。
        使用 MySQL EXPLAIN 预检，能发现：语法错误、表名不存在、字段名不存在、
        JOIN 条件缺失、子查询错误等问题。
        输入: 待检测的 SQL 语句（SELECT）。
        输出: JSON 对象，包含 valid（是否合法）、error（错误信息）、
              warnings（警告列表，如全表扫描）。
        """
        stripped = sql.strip().lstrip(";").strip()

        # 安全检查：只允许 SELECT
        first_word = stripped.split()[0].upper() if stripped.split() else ""
        if first_word != "SELECT":
            return json.dumps({
                "valid": False,
                "error": "只支持检测 SELECT 语句",
                "warnings": [],
            }, ensure_ascii=False)

        warnings = []
        try:
            with ro_engine.connect() as conn:
                result = conn.execute(text(f"EXPLAIN {stripped}"))
                rows = result.fetchall()
                keys = list(result.keys())

            # 分析 EXPLAIN 结果，提取潜在性能警告
            explain_rows = [dict(zip(keys, row)) for row in rows]
            for row in explain_rows:
                table = row.get("table", "")
                type_ = str(row.get("type", "")).lower()
                extra = str(row.get("Extra", "")).lower()
                rows_est = row.get("rows", 0)

                if type_ == "all":
                    warnings.append(f"表 `{table}` 全表扫描（type=ALL），建议添加索引")
                if "using filesort" in extra:
                    warnings.append(f"表 `{table}` 使用文件排序（Using filesort），ORDER BY 字段建议加索引")
                if "using temporary" in extra:
                    warnings.append(f"表 `{table}` 使用临时表（Using temporary），GROUP BY/DISTINCT 可能较慢")
                if isinstance(rows_est, int) and rows_est > 100000:
                    warnings.append(f"表 `{table}` 预估扫描行数 {rows_est}，查询可能较慢")

            return json.dumps({
                "valid": True,
                "error": None,
                "warnings": warnings,
                "explain": explain_rows,
            }, ensure_ascii=False, default=str)

        except SQLAlchemyError as e:
            # 从异常信息中提取 MySQL 错误码和描述
            err_msg = str(e.orig) if hasattr(e, "orig") and e.orig else str(e)
            # 常见错误码映射为中文提示
            friendly = _mysql_error_to_hint(err_msg)
            return json.dumps({
                "valid": False,
                "error": err_msg,
                "hint": friendly,
                "warnings": [],
            }, ensure_ascii=False)

    @tool
    def execute_sql(sql: str) -> str:
        """执行 SQL 查询语句并返回结果。仅支持 SELECT 语句。
        建议先调用 validate_sql 检测语法后再执行。
        输入: 合法的 SELECT SQL 语句。
        输出: JSON 格式的查询结果（最多 100 行）。
        """
        stripped = sql.strip().lstrip(";").strip()
        if not stripped.upper().startswith("SELECT"):
            return "安全限制：只允许执行 SELECT 语句。"
        try:
            with ro_engine.connect() as conn:
                result = conn.execute(text(stripped))
                rows = result.fetchmany(100)
                columns = list(result.keys())
                data = [dict(zip(columns, row)) for row in rows]
            return json.dumps(
                {"columns": columns, "rows": data, "count": len(data)},
                ensure_ascii=False,
                default=str,
            )
        except Exception as e:
            return f"SQL 执行错误: {e}"

    return [list_all_tables, search_tables, search_columns, get_join_paths, get_table_schema, validate_sql, execute_sql]


def _mysql_error_to_hint(err_msg: str) -> str:
    """将常见 MySQL 错误信息转换为中文提示。"""
    patterns = [
        (r"Table '.*?' doesn't exist",        "表不存在，请检查表名是否正确"),
        (r"Unknown column '.*?'",              "字段不存在，请检查字段名是否正确"),
        (r"You have an error in your SQL",     "SQL 语法错误，请检查关键字、括号、引号是否匹配"),
        (r"Column '.*?' in .* is ambiguous",   "字段名歧义，多表查询时请加表名前缀，如 table.column"),
        (r"Unknown table '.*?'",               "JOIN 中引用了未知表，请检查表名"),
        (r"Subquery returns more than 1 row",  "子查询返回了多行，请使用 IN/EXISTS 替代 ="),
        (r"Division by zero",                  "除零错误，请检查 WHERE 条件或计算表达式"),
    ]
    for pattern, hint in patterns:
        if re.search(pattern, err_msg, re.IGNORECASE):
            return hint
    return "SQL 存在错误，请根据 error 字段信息修正"

