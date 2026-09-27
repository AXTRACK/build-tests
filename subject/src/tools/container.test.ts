import assert from "node:assert/strict";
import test from "node:test";
import { sanitizeContainerDetails } from "./container.js";

test("sanitizeContainerDetails never exposes environment values or host mount sources", () => {
  const input = {
    name: "example",
    image: "example:latest",
    status: "running",
    environment: ["DB_PASSWORD=secret", "API_TOKEN=secret-token"],
    env: { SECRET_KEY: "secret-key" },
    port_bindings: [{ container_port: 8080, host_port: 18080 }],
    volume_bindings: [
      {
        host_volume_file: "/volume1/private/database",
        mount_point: "/data",
        ro: true,
      },
    ],
    network: { bridge: true },
    restart_policy: "always",
  };

  const result = sanitizeContainerDetails(input);
  const serialized = JSON.stringify(result);

  assert.equal(result.name, "example");
  assert.equal(result.image, "example:latest");
  assert.ok(!serialized.includes("DB_PASSWORD"));
  assert.ok(!serialized.includes("API_TOKEN"));
  assert.ok(!serialized.includes("SECRET_KEY"));
  assert.ok(!serialized.includes("/volume1/private/database"));
  assert.ok(serialized.includes("/data"));
});
