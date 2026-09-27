import { z } from "zod";
import { defineTool, humanBytes } from "../tool.js";

export function sanitizeContainerDetails(container: any): Record<string, unknown> {
  const ports = Array.isArray(container?.port_bindings)
    ? container.port_bindings
    : container?.ports;
  const mounts = Array.isArray(container?.volume_bindings)
    ? container.volume_bindings.map((mount: any) => ({
        containerPath: mount?.mount_point ?? mount?.container_path ?? mount?.destination,
        readOnly: mount?.ro ?? mount?.read_only ?? undefined,
      }))
    : undefined;

  return {
    name: container?.name,
    image: container?.image,
    status: container?.status,
    running: container?.enable_service ?? container?.status === "running",
    ports,
    mounts,
    network: container?.network ?? container?.networks,
    restartPolicy: container?.restart_policy,
  };
}

/**
 * Container Manager read-only tools for the production ChatGPT profile.
 * Environment variable values are intentionally never returned.
 */
export const containerTools = [
  defineTool({
    name: "list_containers",
    title: "List Docker containers",
    description:
      "Lists containers managed by Container Manager with image, state, CPU and memory usage.",
    readOnly: true,
    idempotent: true,
    schema: z.object({
      offset: z.number().int().min(0).default(0),
      limit: z.number().int().min(1).max(200).default(100),
    }),
    handler: async (ctx, args) => {
      const data = await ctx.client.request<{
        containers: any[];
        total: number;
      }>("SYNO.Docker.Container", "list", {
        offset: args.offset,
        limit: args.limit,
        type: "all",
      });

      return {
        total: data.total,
        containers: (data.containers ?? []).map((item: any) => ({
          name: item.name,
          image: item.image,
          status: item.status,
          running: item.enable_service ?? item.status === "running",
          cpuPercent: item.cpu,
          memoryUsed: humanBytes(Number(item.memory ?? 0)),
          memoryPercent: item.memory_percent,
        })),
      };
    },
  }),

  defineTool({
    name: "get_container_details",
    title: "Get safe container details",
    description:
      "Returns operational container details without environment variable values or other secret-bearing fields.",
    readOnly: true,
    idempotent: true,
    schema: z.object({
      name: z.string().min(1).describe("Container name as shown by list_containers"),
    }),
    handler: async (ctx, args) => {
      const data = await ctx.client.request(
        "SYNO.Docker.Container",
        "get",
        { name: args.name },
      );
      return sanitizeContainerDetails(data);
    },
  }),

  defineTool({
    name: "list_container_images",
    title: "List Docker images",
    description:
      "Lists Docker images stored on the NAS with tags and size.",
    readOnly: true,
    idempotent: true,
    schema: z.object({
      offset: z.number().int().min(0).default(0),
      limit: z.number().int().min(1).max(200).default(100),
    }),
    handler: async (ctx, args) => {
      const data = await ctx.client.request<{ images: any[]; total: number }>(
        "SYNO.Docker.Image",
        "list",
        { offset: args.offset, limit: args.limit, show_dsm: false },
      );
      return {
        total: data.total,
        images: (data.images ?? []).map((image: any) => ({
          repository: image.repository,
          tags: image.tags,
          size: humanBytes(Number(image.virtual_size ?? image.size ?? 0)),
          created: image.created,
        })),
      };
    },
  }),
];
