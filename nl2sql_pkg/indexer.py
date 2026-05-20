import logging
from typing import List, Optional

from .config import config
from .schema_reader import SchemaReader, TableSchema
from .schema_store import GraphStore, VectorStore

logger = logging.getLogger(__name__)


class Indexer:
    """知识库构建器，负责将数据库 schema 写入向量库和图库。"""

    def __init__(self):
        self.config = config
        self._schema_reader: Optional[SchemaReader] = None
        self._vector_store: Optional[VectorStore] = None
        self._graph_store: Optional[GraphStore] = None

    def _init_components(self):
        self._schema_reader = SchemaReader(
            self.config.db.url,
            sample_rows=self.config.sample_rows,
        )
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

    def run(self, table_names: Optional[List[str]] = None) -> List[str]:
        """
        执行知识库构建。

        Args:
            table_names: 指定要索引的表名列表，None 表示全量索引。

        Returns:
            已索引的表名列表。
        """
        self._init_components()

        logger.info("开始读取数据库表结构...")
        if table_names:
            schemas = [self._schema_reader._read_table(t) for t in table_names]
        else:
            schemas = self._schema_reader.read_all()

        if not schemas:
            logger.warning("未找到任何表，请检查数据库连接和权限。")
            return []

        logger.info(f"共读取 {len(schemas)} 张表，开始写入向量库...")
        self._vector_store.index_schemas(schemas)
        logger.info("向量库写入完成。")

        logger.info("开始写入图数据库...")
        self._graph_store.index_schemas(schemas)
        self._graph_store.close()
        logger.info("图数据库写入完成。")

        indexed = [s.table_name for s in schemas]
        logger.info(f"知识库构建完成，已索引表: {indexed}")
        return indexed

    def status(self) -> dict:
        """检查向量库和图库中已索引的表数量。"""
        self._init_components()
        try:
            table_count = self._vector_store.col_tables.count()
            col_count = self._vector_store.col_columns.count()
        except Exception as e:
            table_count = col_count = -1
            logger.warning(f"向量库状态查询失败: {e}")

        try:
            with self._graph_store.driver.session() as session:
                r = session.run("MATCH (t:Table) RETURN count(t) AS n")
                graph_table_count = r.single()["n"]
        except Exception as e:
            graph_table_count = -1
            logger.warning(f"图库状态查询失败: {e}")
        finally:
            self._graph_store.close()

        return {
            "vector_tables": table_count,
            "vector_columns": col_count,
            "graph_tables": graph_table_count,
        }

if __name__ == "__main__":
    # 简单测试
    indexer = Indexer()
    print(indexer.status())
