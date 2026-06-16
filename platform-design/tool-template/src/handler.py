"""Tool entrypoint.

The job-runner harness does the plumbing around you:
  1. Receives a request naming this tool + version.
  2. Validates the payload against the manifest's input_schema.
  3. Calls handle(...) with the validated input and a ToolContext.
  4. Validates your return value against output_schema, then routes it back
     (inline for sync tools, via the queue/result store for async tools).

Do NOT import storage clients, LLM SDKs, or read config directly. Use `ctx`.
That indirection is exactly what keeps this tool portable across the VM
(MinIO/Redis) and AKS (Blob/Service Bus) targets without code changes.
"""

from platform_sdk.tool import ToolContext, tool   # provided by libs/


@tool   # registers handle() as this tool's entrypoint
def handle(input: dict, ctx: ToolContext) -> dict:
    # --- read inputs (already validated against input_schema) ---
    # example_arg = input["example_arg"]

    # --- do the work; reach platform services only through ctx ---
    # raw = ctx.storage.get(input["file_id"])        # object store
    # answer = ctx.llm.complete(prompt)              # LLM gateway
    # vectors = ctx.embeddings.embed([text])         # embeddings service
    # ctx.logger.info("processed", pages=n)          # telemetry + metering

    # --- return a dict matching output_schema ---
    return {
        # "result_file_id": ctx.storage.put(result_bytes),
    }
