from setuptools import setup, find_packages

setup(
    name="factgrid",
    version="0.1.0",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    package_data={
        "factgrid": ["domain/stories/prompts/*.txt"],
    },
    python_requires=">=3.10",
    install_requires=[
        "typer>=0.15.1",
        "httpx>=0.28.1",
        "rich>=13.9.4",
        "python-dotenv>=1.0.1",
        "requests>=2.32.3",
        "pymongo>=4.8.0",
        "openai>=1.58.1",
        "anthropic>=0.42.0",
        "fastapi>=0.115.6",
        "uvicorn[standard]>=0.34.0",
        "feedparser>=6.0.11",
    ],
    entry_points={
        "console_scripts": [
            "factgrid=factgrid.cli.main:main",
        ],
    },
)
