import { trpcServer } from "@hono/trpc-server";
import { Hono } from "hono";
import { cors } from "hono/cors";

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
  const html = await Bun.file("./app/dashboard.html").text();
  return c.html(html);
});

app.get("/ui/styles.css", async (c) => {
  const css = await Bun.file("./app/dashboard.css").text();
  c.header("Content-Type", "text/css; charset=utf-8");
  return c.body(css);
});

app.get("/ui/app.js", async (c) => {
  const js = await Bun.file("./app/dashboard.js").text();
  c.header("Content-Type", "application/javascript; charset=utf-8");
  return c.body(js);
});

export default app;
