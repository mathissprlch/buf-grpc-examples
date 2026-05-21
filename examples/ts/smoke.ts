// In-memory Connect round trip against the buf-generated TypeScript code.
// The Connect-ES runtime here also speaks the gRPC and gRPC-Web protocols.
import { createClient, createRouterTransport } from "@connectrpc/connect";

import { GreetService } from "../../gen/ts/greet/v1/greet_pb.js";

async function main(): Promise<void> {
  const transport = createRouterTransport(({ service }) => {
    service(GreetService, {
      greet(req) {
        return { greeting: `Hello, ${req.name}` };
      },
    });
  });

  const client = createClient(GreetService, transport);
  const res = await client.greet({ name: "TypeScript" });

  if (res.greeting !== "Hello, TypeScript") {
    throw new Error(`unexpected greeting: ${res.greeting}`);
  }
  console.log("typescript Connect round trip ok:", res.greeting);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
