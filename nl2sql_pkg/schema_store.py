"""
向量存储（ChromaDB）+ 图存储（Neo4j）的封装。

修复内容：
  1. Neo4j 变长路径不支持参数化深度 — 改为固定深度 Cypher
  2. 外键双向存储 — 同时存 REFERENCES 快捷边（Table->Table）
  3. 多跳 JOIN 路径 — 用 shortestPath 找链式 JOIN
  4. schema 缓存到 ChromaDB metadata — get_table_schema 不再查数据库

向量库 collection：
  - table_schemas  : 每张表一条文档，metadata 含完整 schema_json
  - column_schemas : 每个字段一条文档

图库节点/边：
  - (:Table {name, comment})
  - (:Column {id, table, name, type, comment, primary_key})
  - (:Table)-[:HAS_COLUMN]->(:Column)
  - (:Column)-[:FK_TO {ref_table}]->(:Column)          # 字段级外键
  - (:Table)-[:REFERENCES {via_col, ref_col}]->(:Table) # 表级快捷边（双向可查）
"""
import hashlib
import json
from typing import Dict, List, Optional, Tuple

import chromadb

from .schema_reader import TableSchema
from .text_embed import EmbeddingManager


class VectorStore:
    """ChromaDB 向量检索 + 关键词精确匹配，支持批量 embedding。"""

    def __init__(self, persist_dir: str, embedding_model_name: str, batch_size: int = 64):
        self.client = chromadb.PersistentClient(path=persist_dir)
        self.batch_size = batch_size
        self.embedder = EmbeddingManager()

        self.col_tables = self.client.get_or_create_collection(
            "table_schemas",
            metadata={"hnsw:space": "cosine"},
        )
        self.col_columns = self.client.get_or_create_collection(
            "column_schemas",
            metadata={"hnsw:space": "cosine"},
        )

    def index_schemas(self, schemas: List[TableSchema]) -> None:
        """
        批量写入所有表结构到向量库（upsert，可重复调用）。

        优化：将所有文本收集后一次性批量 encode，
        相比逐条 encode 速度提升 5-10x（尤其有 GPU 时）。
        """
        # ── 表级批量 ──────────────────────────────────────────
        table_ids, table_docs, table_metas = [], [], []
        for schema in schemas:
            table_ids.append(hashlib.md5(schema.table_name.encode()).hexdigest())
            table_docs.append(schema.to_text())
            table_metas.append({
                "table_name": schema.table_name,
                "comment": schema.table_comment,
                "schema_json": json.dumps(schema.to_dict(), ensure_ascii=False, default=str),
            })
        table_embeddings = self.embedder.batch_get_embeddings(table_docs, dimension=1024)
        # ChromaDB upsert 支持批量，按 batch_size 分块避免单次过大
        for i in range(0, len(table_ids), self.batch_size):
            self.col_tables.upsert(
                ids=table_ids[i:i + self.batch_size],
                embeddings=table_embeddings[i:i + self.batch_size],
                documents=table_docs[i:i + self.batch_size],
                metadatas=table_metas[i:i + self.batch_size],
            )

        # ── 字段级批量 ────────────────────────────────────────
        col_ids, col_docs, col_metas = [], [], []
        for schema in schemas:
            for col in schema.columns:
                col_ids.append(
                    hashlib.md5(f"{schema.table_name}.{col.name}".encode()).hexdigest()
                )
                col_docs.append(
                    f"表 {schema.table_name} 字段 {col.name} "
                    f"类型 {col.type} "
                    f"注释 {col.comment or ''} "
                    f"主键 {col.primary_key}"
                )
                col_metas.append({
                    "table_name": schema.table_name,
                    "column_name": col.name,
                    "primary_key": str(col.primary_key),
                    "col_type": col.type,
                    "comment": col.comment or "",
                })

        col_embeddings = self.embedder.batch_get_embeddings(col_docs, dimension=1024)
        for i in range(0, len(col_ids), self.batch_size):
            self.col_columns.upsert(
                ids=col_ids[i:i + self.batch_size],
                embeddings=col_embeddings[i:i + self.batch_size],
                documents=col_docs[i:i + self.batch_size],
                metadatas=col_metas[i:i + self.batch_size],
            )

    def search_tables(self, query: str, top_k: int = 5) -> List[Tuple[str, float]]:
        """
        混合检索 + RRF 重排序。

        三路信号：
          A. 向量检索（语义相似度）
          B. 表名精确/前缀匹配（BM25 近似：token 命中计数）
          C. 注释关键词匹配（token 命中计数）

        用 Reciprocal Rank Fusion (RRF) 合并三路排名，
        最终按 RRF 分数降序返回（分数越高越相关）。
        返回格式改为 [(table_name, rrf_score), ...]，score 越大越相关。
        """
        total = self.col_tables.count()
        if total == 0:
            return []

        # ── 预处理查询词 ──────────────────────────────────────
        query_lower = query.lower()
        tokens = [t for t in query_lower.replace("_", " ").split() if len(t) > 1]

        # ── A. 向量检索 ───────────────────────────────────────
        n_vector = min(max(top_k * 3, 15), total)
        vector_results = self.col_tables.query(
            query_embeddings=[self.embedder.get_embedding(query)],
            n_results=n_vector,
            include=["metadatas", "distances"],
        )
        # 向量排名列表（按 distance 升序，distance 越小越好）
        vector_ranked: List[str] = [
            m["table_name"] for m in vector_results["metadatas"][0]
        ]

        # ── B & C. 关键词匹配（表名 + 注释）─────────────────
        # 只对向量候选集做关键词评分，避免全量扫描
        keyword_scores: Dict[str, float] = {}
        for table_name in vector_ranked:
            meta_result = self.col_tables.get(
                where={"table_name": table_name},
                include=["metadatas"],
            )
            if not meta_result["metadatas"]:
                continue
            meta = meta_result["metadatas"][0]
            name_lower = meta["table_name"].lower()
            comment_lower = meta.get("comment", "").lower()

            score = 0.0
            for tok in tokens:
                # 表名完全匹配权重最高
                if tok == name_lower:
                    score += 3.0
                # 表名前缀匹配
                elif name_lower.startswith(tok):
                    score += 2.0
                # 表名包含
                elif tok in name_lower:
                    score += 1.5
                # 注释包含
                if tok in comment_lower:
                    score += 1.0

            if score > 0:
                keyword_scores[table_name] = score

        # 关键词排名列表（按 score 降序）
        keyword_ranked: List[str] = sorted(
            keyword_scores, key=lambda t: keyword_scores[t], reverse=True
        )

        # ── RRF 融合 ──────────────────────────────────────────
        # RRF(d) = Σ 1 / (k + rank_i(d))，k=60 是标准常数
        K = 60
        rrf_scores: Dict[str, float] = {}

        for rank, table_name in enumerate(vector_ranked, start=1):
            rrf_scores[table_name] = rrf_scores.get(table_name, 0.0) + 1.0 / (K + rank)

        for rank, table_name in enumerate(keyword_ranked, start=1):
            rrf_scores[table_name] = rrf_scores.get(table_name, 0.0) + 1.0 / (K + rank)

        # 按 RRF 分数降序排列，取 top_k
        ranked = sorted(rrf_scores.items(), key=lambda x: x[1], reverse=True)
        return ranked[:top_k]

    def search_columns(self, query: str, top_k: int = 10) -> List[dict]:
        """返回匹配字段的 metadata 列表。"""
        total = self.col_columns.count()
        if total == 0:
            return []
        results = self.col_columns.query(
            query_embeddings=[self.embedder.get_embedding(query)],
            n_results=min(top_k, total),
        )
        return results["metadatas"][0]

    def get_table_schema_from_cache(self, table_name: str) -> Optional[str]:
        """
        从 ChromaDB metadata 缓存读取表结构，不查数据库。
        返回 schema 文本，未找到返回 None。
        """
        results = self.col_tables.get(
            where={"table_name": table_name},
            include=["metadatas"],
        )
        if not results["metadatas"]:
            return None
        schema_json = results["metadatas"][0].get("schema_json")
        if not schema_json:
            return None
        data = json.loads(schema_json)
        # 重建文本格式
        lines = [
            f"表名: {data['table_name']}",
            f"表注释: {data['table_comment']}",
            f"字段列表: {json.dumps(data['columns'], ensure_ascii=False, indent=2)}",
        ]
        if data.get("foreign_keys"):
            lines.append("外键关系:")
            for fk in data["foreign_keys"]:
                lines.append(f"  - {fk['column']} -> {fk['ref_table']}.{fk['ref_column']}")
        if data.get("indexes"):
            lines.append("索引信息:")
            for idx in data["indexes"]:
                lines.append(f"  - {idx['name']} (columns: {', '.join(idx['columns'])}, unique: {idx['unique']})")
        return "\n".join(lines)


class GraphStore:
    """
    Neo4j 图存储，使用连接池复用连接。

    Neo4j Python Driver 的 GraphDatabase.driver() 本身就维护一个连接池，
    默认最大连接数为 100。这里通过配置参数显式控制池大小和超时，
    并将 driver 生命周期与 GraphStore 实例绑定（单例使用）。

    连接池关键参数：
      max_connection_pool_size : 池中最大连接数，默认 100
      connection_timeout        : 建立连接超时（秒）
      max_connection_lifetime   : 连接最长存活时间（秒），超时自动回收
      keep_alive                : 保持 TCP 长连接
    """

    def __init__(
        self,
        uri: str,
        user: str,
        password: str,
        max_pool_size: int = 20,
        connection_timeout: float = 10.0,
        max_connection_lifetime: int = 3600,
    ):
        from neo4j import GraphDatabase
        self.driver = GraphDatabase.driver(
            uri,
            auth=(user, password),
            max_connection_pool_size=max_pool_size,
            connection_timeout=connection_timeout,
            max_connection_lifetime=max_connection_lifetime,
            keep_alive=True,
        )
        self._ensure_indexes()

    def _ensure_indexes(self):
        """创建必要的索引以加速查询。"""
        with self.driver.session() as session:
            session.run("CREATE INDEX table_name IF NOT EXISTS FOR (t:Table) ON (t.name)")
            session.run("CREATE INDEX column_id IF NOT EXISTS FOR (c:Column) ON (c.id)")

    def close(self):
        """关闭连接池，释放所有连接。仅在进程退出时调用。"""
        self.driver.close()

    def verify_connectivity(self) -> bool:
        """检查连接池是否可用。"""
        try:
            self.driver.verify_connectivity()
            return True
        except Exception:
            return False

    def index_schemas(self, schemas: List[TableSchema]) -> None:
        with self.driver.session() as session:
            # Pass 1: upsert all Table + Column nodes
            for schema in schemas:
                session.execute_write(self._upsert_nodes, schema)
            # Pass 2: upsert FK edges (all nodes guaranteed to exist now)
            for schema in schemas:
                session.execute_write(self._upsert_fk_edges, schema)

    @staticmethod
    def _upsert_nodes(tx, schema: TableSchema):
        tx.run(
            "MERGE (t:Table {name: $name}) SET t.comment = $comment",
            name=schema.table_name,
            comment=schema.table_comment,
        )
        for col in schema.columns:
            tx.run(
                """
                MERGE (c:Column {id: $id})
                SET c.table = $table, c.name = $name, c.type = $type,
                    c.comment = $comment, c.primary_key = $pk
                WITH c
                MATCH (t:Table {name: $table})
                MERGE (t)-[:HAS_COLUMN]->(c)
                """,
                id=f"{schema.table_name}.{col.name}",
                table=schema.table_name,
                name=col.name,
                type=col.type,
                comment=col.comment or "",
                pk=col.primary_key,
            )

    @staticmethod
    def _upsert_fk_edges(tx, schema: TableSchema):
        for fk in schema.foreign_keys:
            src_id = f"{schema.table_name}.{fk.column}"
            dst_id = f"{fk.ref_table}.{fk.ref_column}"

            # 跳过自引用（防止图遍历死循环）
            if schema.table_name == fk.ref_table:
                continue

            # 字段级外键边
            tx.run(
                """
                MATCH (src:Column {id: $src_id})
                MATCH (dst:Column {id: $dst_id})
                MERGE (src)-[:FK_TO {ref_table: $ref_table}]->(dst)
                """,
                src_id=src_id,
                dst_id=dst_id,
                ref_table=fk.ref_table,
            )
            # 表级快捷边（用于多跳路径查询）
            tx.run(
                """
                MATCH (from_t:Table {name: $from_table})
                MATCH (to_t:Table {name: $to_table})
                MERGE (from_t)-[:REFERENCES {via_col: $via_col, ref_col: $ref_col}]->(to_t)
                """,
                from_table=schema.table_name,
                to_table=fk.ref_table,
                via_col=fk.column,
                ref_col=fk.ref_column,
            )

    def get_join_paths(self, table_names: List[str]) -> List[dict]:
        """
        给定一组表名，返回它们之间所有可用的 JOIN 路径（含多跳中间表）。
        返回格式: [{"from_table", "from_col", "to_table", "to_col", "path_tables"}]
        """
        if len(table_names) < 2:
            return []

        with self.driver.session() as session:
            # 1. 直接外键（一跳）
            direct = session.run(
                """
                MATCH (src:Column)-[r:FK_TO]->(dst:Column)
                WHERE src.table IN $tables AND dst.table IN $tables
                RETURN src.table AS from_table, src.name AS from_col,
                       dst.table AS to_table, dst.name AS to_col,
                       [src.table, dst.table] AS path_tables
                """,
                tables=table_names,
            )
            results = [dict(row) for row in direct]

            # 2. 多跳路径（最多3跳，找连接给定表集合的中间路径）
            multi = session.run(
                """
                UNWIND $pairs AS pair
                MATCH path = shortestPath(
                    (t1:Table {name: pair[0]})-[:REFERENCES*1..4]-(t2:Table {name: pair[1]})
                )
                WHERE length(path) > 1
                WITH path, [n IN nodes(path) | n.name] AS path_tables
                UNWIND range(0, length(path)-1) AS i
                WITH path_tables,
                     relationships(path)[i] AS rel,
                     nodes(path)[i] AS from_t,
                     nodes(path)[i+1] AS to_t
                RETURN from_t.name AS from_table,
                       rel.via_col AS from_col,
                       to_t.name AS to_table,
                       rel.ref_col AS to_col,
                       path_tables
                """,
                pairs=[[table_names[i], table_names[j]]
                       for i in range(len(table_names))
                       for j in range(i + 1, len(table_names))],
            )
            # 合并去重
            seen = {(r["from_table"], r["from_col"], r["to_table"], r["to_col"]) for r in results}
            for row in multi:
                key = (row["from_table"], row["from_col"], row["to_table"], row["to_col"])
                if key not in seen:
                    seen.add(key)
                    results.append(dict(row))

        return results

    def get_related_tables(self, table_name: str, depth: int = 1) -> List[str]:
        """
        通过 REFERENCES 快捷边扩展关联表（双向，固定深度展开，避免参数化变长路径）。
        depth=1: 直接关联；depth=2: 两跳关联。
        """
        with self.driver.session() as session:
            if depth == 1:
                # 无向匹配：不论外键方向，只要有 REFERENCES 边就算关联
                result = session.run(
                    """
                    MATCH (t:Table {name: $name})-[:REFERENCES]-(related:Table)
                    WHERE related.name <> $name
                    RETURN DISTINCT related.name AS name
                    """,
                    name=table_name,
                )
            else:
                # depth=2: 两跳展开（固定写法，避免参数化变长路径）
                result = session.run(
                    """
                    MATCH (t:Table {name: $name})-[:REFERENCES]-(mid:Table)
                          -[:REFERENCES]-(related:Table)
                    WHERE related.name <> $name
                    RETURN DISTINCT related.name AS name
                    UNION
                    MATCH (t:Table {name: $name})-[:REFERENCES]-(related:Table)
                    WHERE related.name <> $name
                    RETURN DISTINCT related.name AS name
                    """,
                    name=table_name,
                )
            return [row["name"] for row in result]
