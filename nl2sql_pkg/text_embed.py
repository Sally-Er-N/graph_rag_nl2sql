import os
from typing import List

from openai import OpenAI
import numpy as np

DASHSCOPE_API_KEY = os.getenv("DASHSCOPE_API_KEY", "")
DASHSCOPE_BASE_URL = os.getenv("DASHSCOPE_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1")


class EmbeddingManager:
    def __init__(
        self,
        api_key: str = DASHSCOPE_API_KEY,
        base_url: str = DASHSCOPE_BASE_URL,
        model_name: str = "text-embedding-v4",
    ):
        self.client = OpenAI(api_key=api_key, base_url=base_url)
        self.model = model_name

    def get_embedding(
        self,
        text: str,
        dimension: int = 1024,
        text_type: str = "query",
    ) -> List[float]:
        completion = self.client.embeddings.create(
            model=self.model,
            input=text,
            dimension=dimension,
            text_type=text_type,
        )
        return completion.data[0].embedding

    def batch_get_embeddings(
        self,
        texts: List[str],
        dimension: int = 1024,
        text_type: str = "document",
        batch_size: int = 16,
    ) -> List[List[float]]:
        """返回与 texts 等长的 embedding 列表，失败批次逐条回退。"""
        embeddings: List[List[float]] = []
        for i in range(0, len(texts), batch_size):
            batch = texts[i:i + batch_size]
            try:
                completion = self.client.embeddings.create(
                    model=self.model,
                    input=batch,
                    dimension=dimension,
                    text_type=text_type,
                )
                for data in completion.data:
                    embeddings.append(data.embedding)
            except Exception as e:
                print(f"批处理出错 (批次 {i // batch_size + 1}): {e}")
                for text in batch:
                    try:
                        embeddings.append(self.get_embedding(text, dimension, text_type))
                    except Exception as e2:
                        print(f"处理文本失败: {text[:50]}... 错误: {e2}")
                        embeddings.append([0.0] * dimension)
        return embeddings

    @staticmethod
    def cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
        v1 = np.array(vec1)
        v2 = np.array(vec2)
        return float(np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2) + 1e-8))


if __name__ == "__main__":
    query_texts = [
        "天气怎么样？",
        "什么是机器学习？",
        "Python可以用来做什么？",
    ]
    text_list = [
        "今天天气真好，适合出去玩。",
        "人工智能正在改变世界。",
        "Python是一种非常流行的编程语言。",
        "机器学习是AI的一个分支。",
        "深度学习需要大量的计算资源。",
    ]
    embedder = EmbeddingManager()
    doc_embeddings = embedder.batch_get_embeddings(text_list, dimension=1024)
    for q in query_texts:
        q_emb = embedder.get_embedding(q, dimension=1024, text_type="query")
        results = sorted(
            [{"text": t, "similarity": EmbeddingManager.cosine_similarity(q_emb, e)}
             for t, e in zip(text_list, doc_embeddings)],
            key=lambda x: x["similarity"],
            reverse=True,
        )
        print(f"\n查询: {q}")
        for r in results[:3]:
            print(f"  - {r['text']} (相似度: {r['similarity']:.4f})")
