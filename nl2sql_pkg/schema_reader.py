import json
from dataclasses import dataclass
from typing import Dict, List, Optional

import pandas as pd
from sqlalchemy import create_engine, inspect, text


@dataclass
class ColumnInfo:
    name: str
    type: str
    nullable: bool
    primary_key: bool = False
    comment: Optional[str] = None  # 验证添加注释与没有注释准确率的差距

    def to_dict(self) -> Dict:
        return {
            "name": self.name,
            "type": self.type,
            "nullable": self.nullable,
            "primary_key": self.primary_key,
            "comment": self.comment,
        }


@dataclass
class ForeignKeyInfo:
    column: str
    ref_table: str
    ref_column: str

    def to_dict(self) -> Dict:
        return {
            "column": self.column,
            "ref_table": self.ref_table,
            "ref_column": self.ref_column,
        }


@dataclass
class IndexInfo:
    name: str
    columns: List[str]
    unique: bool

    def to_dict(self) -> Dict:
        return {"name": self.name, "columns": self.columns, "unique": self.unique}


@dataclass
class TableSchema:
    table_name: str
    table_comment: str
    columns: List[ColumnInfo]
    foreign_keys: List[ForeignKeyInfo]
    indexes: List[IndexInfo]
    sample_data: Optional[pd.DataFrame] = None

    def to_text(self) -> str:
        text = (
            f"表名: {self.table_name}\n"
            f"表注释: {self.table_comment}\n"
            f"字段列表: {json.dumps([c.to_dict() for c in self.columns], ensure_ascii=False, indent=2)}\n"
        )
        if self.foreign_keys:
            text += "外键关系:\n"
            for fk in self.foreign_keys:
                text += f" - {fk.column} -> {fk.ref_table}.{fk.ref_column}\n"
        if self.indexes:
            text += "索引信息:\n"
            for idx in self.indexes:
                text += f" - {idx.name} (columns: {', '.join(idx.columns)}, unique: {idx.unique})\n"
        if self.sample_data is not None:
            text += f"样本数据:\n{self.sample_data.to_string(index=False)}\n"
        return text

    def to_dict(self) -> Dict:
        return {
            "table_name": self.table_name,
            "table_comment": self.table_comment,
            "columns": [c.to_dict() for c in self.columns],
            "foreign_keys": [fk.to_dict() for fk in self.foreign_keys],
            "indexes": [idx.to_dict() for idx in self.indexes],
            "sample_data": self.sample_data.to_dict(orient="records") if self.sample_data is not None else None,
        }


class SchemaReader:
    """连接数据库，提取所有表结构。"""

    def __init__(self, db_url: str, sample_rows: int = 3):
        self.engine = create_engine(db_url)
        self.inspector = inspect(self.engine)
        self.sample_rows = sample_rows

    def read_all(self) -> List[TableSchema]:
        schemas = []
        for table_name in self.inspector.get_table_names():
            schemas.append(self._read_table(table_name))
        return schemas

    def _read_table(self, table_name: str) -> TableSchema:
        # 列信息
        pk_cols = {c for c in self.inspector.get_pk_constraint(table_name).get("constrained_columns", [])}
        columns = [
            ColumnInfo(
                name=col["name"],
                type=str(col["type"]),
                nullable=col["nullable"],
                primary_key=col["name"] in pk_cols,
                comment=col.get("comment") or "",
            )
            for col in self.inspector.get_columns(table_name)
        ]

        # 外键
        foreign_keys = [
            ForeignKeyInfo(
                column=fk["constrained_columns"][0],
                ref_table=fk["referred_table"],
                ref_column=fk["referred_columns"][0],
            )
            for fk in self.inspector.get_foreign_keys(table_name)
            if fk["constrained_columns"] and fk["referred_columns"]
        ]

        # 索引
        indexes = [
            IndexInfo(
                name=idx["name"] or "",
                columns=idx["column_names"],
                unique=idx["unique"],
            )
            for idx in self.inspector.get_indexes(table_name)
        ]

        # 表注释（MySQL）
        table_comment = self._get_table_comment(table_name)

        # 样本数据
        sample_data = None
        if self.sample_rows > 0:
            try:
                with self.engine.connect() as conn:
                    sample_data = pd.read_sql(
                        text(f"SELECT * FROM `{table_name}` LIMIT :n"),
                        conn,
                        params={"n": self.sample_rows},
                    )
            except Exception:
                pass

        return TableSchema(
            table_name=table_name,
            table_comment=table_comment,
            columns=columns,
            foreign_keys=foreign_keys,
            indexes=indexes,
            sample_data=sample_data,
        )

    def _get_table_comment(self, table_name: str) -> str:
        try:
            with self.engine.connect() as conn:
                row = conn.execute(
                    text(
                        "SELECT TABLE_COMMENT FROM information_schema.TABLES "
                        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :t"
                    ),
                    {"t": table_name},
                ).fetchone()
            return row[0] if row and row[0] else ""
        except Exception:
            return ""

if __name__ == "__main__":
    reader = SchemaReader("mysql+pymysql://root:111111@localhost:3306/employee_management")
    schemas = reader.read_all()
    for s in schemas:
        print(s.to_text())