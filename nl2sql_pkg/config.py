import os
from dataclasses import dataclass, field
from dotenv import load_dotenv

# 自动加载项目根目录 .env
env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(env_path)


@dataclass
class DBConfig:
    host: str = field(default_factory=lambda: os.getenv("DB_HOST", "localhost"))
    port: int = field(default_factory=lambda: int(os.getenv("DB_PORT", "3306")))
    user: str = field(default_factory=lambda: os.getenv("DB_USER", "root"))
    password: str = field(default_factory=lambda: os.getenv("DB_PASSWORD", "your_password"))
    database: str = field(default_factory=lambda: os.getenv("DB_NAME", "your_database"))
    charset: str = field(default_factory=lambda: os.getenv("DB_CHARSET", "utf8mb4"))

    @property
    def url(self) -> str:
        return (
            f"mysql+pymysql://{self.user}:{self.password}"
            f"@{self.host}:{self.port}/{self.database}?charset={self.charset}"
        )


@dataclass
class ChromaConfig:
    persist_directory: str = field(default_factory=lambda: os.getenv("CHROMA_PERSIST_DIR", "./data/chroma"))
    collection_tables: str = field(default_factory=lambda: os.getenv("CHROMA_COLLECTION_TABLES", "table_schemas"))
    collection_columns: str = field(default_factory=lambda: os.getenv("CHROMA_COLLECTION_COLUMNS", "column_schemas"))


@dataclass
class Neo4jConfig:
    uri: str = field(default_factory=lambda: os.getenv("NEO4J_URI", "bolt://localhost:7687"))
    user: str = field(default_factory=lambda: os.getenv("NEO4J_USER", "neo4j"))
    password: str = field(default_factory=lambda: os.getenv("NEO4J_PASSWORD", "your_neo4j_password"))
    max_pool_size: int = field(default_factory=lambda: int(os.getenv("NEO4J_MAX_POOL_SIZE", "20")))
    connection_timeout: float = field(default_factory=lambda: float(os.getenv("NEO4J_CONNECTION_TIMEOUT", "10.0")))
    max_connection_lifetime: int = field(default_factory=lambda: int(os.getenv("NEO4J_MAX_CONNECTION_LIFETIME", "3600")))


@dataclass
class LLMConfig:
    api_key: str = field(default_factory=lambda: os.getenv("OPENAI_API_KEY", "your_api_key"))
    base_url: str = field(default_factory=lambda: os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1"))
    model: str = field(default_factory=lambda: os.getenv("OPENAI_MODEL", "gpt-4o-mini"))
    temperature: float = field(default_factory=lambda: float(os.getenv("OPENAI_TEMPERATURE", "0.0")))


@dataclass
class EmbeddingConfig:
    model_name: str = field(default_factory=lambda: os.getenv("EMBEDDING_MODEL", "paraphrase-multilingual-MiniLM-L12-v2"))
    batch_size: int = field(default_factory=lambda: int(os.getenv("EMBEDDING_BATCH_SIZE", "64")))   # 批量 embed 时每批文本数量


@dataclass
class AppConfig:
    db: DBConfig = field(default_factory=DBConfig)
    chroma: ChromaConfig = field(default_factory=ChromaConfig)
    neo4j: Neo4jConfig = field(default_factory=Neo4jConfig)
    llm: LLMConfig = field(default_factory=LLMConfig)
    embedding: EmbeddingConfig = field(default_factory=EmbeddingConfig)
    sample_rows: int = field(default_factory=lambda: int(os.getenv("SAMPLE_ROWS", "3")))


config = AppConfig()