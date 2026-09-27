import assert from "node:assert/strict";
import test from "node:test";
import { allTools } from "./index.js";

const expected = new Set([
  "get_system_info",
  "get_resource_usage",
  "get_storage_info",
  "list_installed_packages",
  "list_active_connections",
  "list_containers",
  "get_container_details",
  "list_container_images",
]);

test("production registry exposes exactly the approved read-only tools", () => {
  assert.deepEqual(new Set(allTools.map((tool) => tool.name)), expected);
});

test("production registry exposes no destructive, file, photo, download, or generic bridge tools", () => {
  for (const tool of allTools) {
    assert.equal(tool.readOnly, true, `${tool.name} must be read-only`);
    assert.ok(!tool.name.includes("file"));
    assert.ok(!tool.name.includes("photo"));
    assert.ok(!tool.name.includes("download"));
    assert.ok(!tool.name.includes("generic"));
    assert.ok(!tool.name.includes("control"));
    assert.ok(!tool.name.includes("delete"));
  }
});
