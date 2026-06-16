"""Unit tests for the tool handler.

`fake_context()` supplies in-memory stubs for storage / llm / embeddings so
tests run with no real backing services — the same code path the harness uses.
"""

from platform_sdk.testing import run_tool, fake_context

from ..src.handler import handle


def test_happy_path():
    ctx = fake_context()
    out = run_tool(handle, input={}, ctx=ctx)
    assert out is not None
    # assert on the shape you declared in output_schema, e.g.:
    # assert "result_file_id" in out
