import { trpcServer } from "@hono/trpc-server";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

import { appRouter } from "./trpc/app-router";
import { createContext } from "./trpc/create-context";

const app = new Hono();

app.use("*", cors());

app.use(
  "/api/trpc/*",
  trpcServer({
    endpoint: "/api/trpc",
    router: appRouter,
    createContext,
  }),
);

app.get("/", (c) => {
  return c.json({ status: "ok", message: "Nexus API is running", version: "1.0.2" });
});

app.get("/health", (c) => {
  return c.json({ status: "ok", message: "Nexus API is healthy", version: "1.0.2" });
});

app.get("/ui", (c) => {
  return c.redirect("/ui/");
});

app.get("/ui/", async (c) => {
  try {
    const html = await readFile(join(process.cwd(), "app/dashboard.html"), "utf-8");
    return c.html(html);
  } catch (err) {
    return c.text("Dashboard HTML not found", 404);
  }
});

app.get("/ui/styles.css", async (c) => {
  try {
    const css = await readFile(join(process.cwd(), "app/dashboard.css"), "utf-8");
    c.header("Content-Type", "text/css; charset=utf-8");
    return c.body(css);
  } catch (err) {
    return c.text("CSS not found", 404);
  }
});

app.get("/ui/app.js", async (c) => {
  try {
    const js = await readFile(join(process.cwd(), "app/dashboard.js"), "utf-8");
    c.header("Content-Type", "application/javascript; charset=utf-8");
    return c.body(js);
  } catch (err) {
    return c.text("JS not found", 404);
  }
});

export default app;
