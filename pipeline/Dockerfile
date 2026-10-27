# FROM：基础镜像（Python 3.13）
FROM python:3.13.11-slim
# 从官方 uv 镜像中复制 uv 二进制文件（多阶段构建模式）
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/

# RUN:在构建过程中执行命令
# RUN pip install pandas pyarrow
# WORKDIR:设置工作目录
WORKDIR /code
# 将虚拟环境添加到PATH，以便我能够使用已安装的包
ENV PATH="/code/.venv/bin:$PATH"

COPY "pyproject.toml" ".python-version" "uv.lock" ./
# 从锁定文件安装依赖
RUN uv sync --locked 


# COPY:将文件复制到镜像中
COPY ingest_data.py .
# ENTRYPOINT：要运行的默认命令
ENTRYPOINT ["python", "ingest_data.py"]