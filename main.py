import argparse
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

from nl2sql_pkg.config import AppConfig, config


def cmd_index(args):
    from nl2sql_pkg.indexer import Indexer
    indexer = Indexer()

    if args.status:
        status = indexer.status()
        print(f"表文档: {status['vector_tables']}，字段文档: {status['vector_columns']}")
        print(f"表节点: {status['graph_tables']}")
        return 

    tables = args.tables or None
    print("构建知识库")
    indexed = indexer.run(tables)
    print(f"完成，已索引 {len(indexed)} 张表: {indexed}")


def cmd_query(args, config: AppConfig):
    from nl2sql_pkg.sql_generator import SQLGenerator
    from sqlalchemy import create_engine, text
    import json

    gen = SQLGenerator(config)
    engine = create_engine(config.db.url)

    def run_once(question: str):
        print("\n生成 SQL 中...")
        result = gen.generate(question)
        print(f"\nSQL:\n{result.sql}\n")

        if not result.valid:
            print(f"SQL 验证失败: {result.error}")
            if result.hint:
                print(f"提示: {result.hint}")
            return

        if result.warnings:
            print("性能警告:")
            for w in result.warnings:
                print(f"  ⚠ {w}")

        try:
            with engine.connect() as conn:
                res = conn.execute(text(result.sql))
                rows = res.fetchmany(100)
                columns = list(res.keys())
                data = [dict(zip(columns, row)) for row in rows]
            print(f"\n结果（{len(data)} 行）:")
            print(json.dumps(data, ensure_ascii=False, indent=2, default=str))
        except Exception as e:
            print(f"执行出错: {e}")

    if args.question:
        run_once(args.question)
        gen.close()
        return

    print("SQL 生成模式（输入 'exit' 退出）")
    print("-" * 50)
    while True:
        try:
            q = input("\n请输入问题: ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if not q or q.lower() in ("exit", "quit", "q"):
            break
        run_once(q)
    gen.close()

def cmd_agent(args, config: AppConfig):
    from nl2sql_pkg.agent import build_agent

    print("初始化 Agent...")
    agent = build_agent(config)

    def run_once(question: str):
        result = agent.invoke({"messages": [("human", question)]})
        print("\n=== 结果 ===")
        print(result["messages"][-1].content)

    if args.question:
        run_once(args.question)
        return

    print("Agent 模式（输入 'exit' 退出）")
    print("-" * 50)
    while True:
        try:
            q = input("\n请输入问题: ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if not q or q.lower() in ("exit", "quit", "q"):
            break
        try:
            run_once(q)
        except Exception as e:
            print(f"执行出错: {e}")

def main():
    parser = argparse.ArgumentParser(description="NL2SQL — 自然语言转 SQL")
    sub = parser.add_subparsers(dest="cmd", required=True)

    # index
    p_index = sub.add_parser("index", help="构建知识库（必须先执行）")
    p_index.add_argument("--status", action="store_true", help="查看知识库状态")
    p_index.add_argument("--tables", nargs="+", metavar="TABLE", help="只索引指定表（空则全量）")

    # query
    p_query = sub.add_parser("query", help="直接生成并执行 SQL（轻量模式）")
    p_query.add_argument("question", nargs="?", default=None, help="自然语言问题")

    # agent
    p_agent = sub.add_parser("agent", help="Agent 模式（多工具调用）")
    p_agent.add_argument("question", nargs="?", default=None, help="自然语言问题")

    args = parser.parse_args()

    if args.cmd == "index":
        cmd_index(args)
    elif args.cmd == "query":
        cmd_query(args, config)
    elif args.cmd == "agent":
        cmd_agent(args, config)


if __name__ == "__main__":
    main()
