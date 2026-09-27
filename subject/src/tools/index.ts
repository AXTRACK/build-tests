import type { ToolDef } from "../tool.js";
import { containerTools } from "./container.js";
import { systemTools } from "./system.js";

/**
 * Production profile for ChatGPT. Keep this list intentionally small.
 * File Station, Photos, Download Station and the generic DSM bridge remain in
 * source for upstream compatibility/reference but are not registered.
 */
const productionToolNames = new Set([
  "get_system_info",
  "get_resource_usage",
  "get_storage_info",
  "list_installed_packages",
  "list_active_connections",
  "list_containers",
  "get_container_details",
  "list_container_images",
]);

const candidateTools: ToolDef[] = [
  ...systemTools,
  ...containerTools,
];

export const allTools: ToolDef[] = candidateTools.filter((tool) =>
  productionToolNames.has(tool.name),
);

export function buildToolIndex(tools: ToolDef[]): Map<string, ToolDef> {
  const index = new Map<string, ToolDef>();
  for (const tool of tools) {
    if (index.has(tool.name)) {
      throw new Error(`Duplicate tool name registered: ${tool.name}`);
    }
    index.set(tool.name, tool);
  }
  return index;
}
