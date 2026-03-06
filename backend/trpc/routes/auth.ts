import { z } from "zod/v4";
import { publicProcedure, createTRPCRouter } from "../create-context";
import { TRPCError } from "@trpc/server";

const JWT_SECRET = process.env.JWT_SECRET || "nexus-secret-key-change-in-production";
const TOKEN_EXPIRY_HOURS = 72;

interface StoredUser {
  id: string;
  email: string;
  passwordHash: string;
  name: string;
  createdAt: string;
}

const users: StoredUser[] = [];

function generateId(): string {
  return crypto.randomUUID();
}

async function createJWT(payload: { userId: string; email: string }): Promise<string> {
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);
  const body = btoa(
    JSON.stringify({
      ...payload,
      iat: now,
      exp: now + TOKEN_EXPIRY_HOURS * 3600,
    })
  );
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(JWT_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(`${header}.${body}`));
  const signature = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
  return `${header}.${body}.${signature}`;
}

export async function verifyJWT(token: string): Promise<{ userId: string; email: string } | null> {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const body = JSON.parse(atob(parts[1]));
    if (body.exp && body.exp < Math.floor(Date.now() / 1000)) return null;
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(JWT_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"]
    );
    const sigBytes = Uint8Array.from(
      atob(parts[2].replace(/-/g, "+").replace(/_/g, "/")),
      (c) => c.charCodeAt(0)
    );
    const valid = await crypto.subtle.verify(
      "HMAC",
      key,
      sigBytes,
      encoder.encode(`${parts[0]}.${parts[1]}`)
    );
    if (!valid) return null;
    return { userId: body.userId, email: body.email };
  } catch {
    return null;
  }
}

export function getUserFromStore(userId: string): StoredUser | undefined {
  return users.find((u) => u.id === userId);
}

export const authRouter = createTRPCRouter({
  register: publicProcedure
    .input(
      z.object({
        email: z.email(),
        password: z.string().min(6),
        name: z.string().min(1),
      })
    )
    .mutation(async ({ input }) => {
      const existing = users.find((u) => u.email === input.email.toLowerCase());
      if (existing) {
        throw new TRPCError({ code: "CONFLICT", message: "Email already registered" });
      }
      const passwordHash = await Bun.password.hash(input.password, { algorithm: "bcrypt" });
      const user: StoredUser = {
        id: generateId(),
        email: input.email.toLowerCase(),
        passwordHash,
        name: input.name,
        createdAt: new Date().toISOString(),
      };
      users.push(user);
      const token = await createJWT({ userId: user.id, email: user.email });
      return { token, user: { id: user.id, email: user.email, name: user.name } };
    }),

  login: publicProcedure
    .input(
      z.object({
        email: z.email(),
        password: z.string().min(1),
      })
    )
    .mutation(async ({ input }) => {
      const user = users.find((u) => u.email === input.email.toLowerCase());
      if (!user) {
        throw new TRPCError({ code: "UNAUTHORIZED", message: "Invalid email or password" });
      }
      const valid = await Bun.password.verify(input.password, user.passwordHash);
      if (!valid) {
        throw new TRPCError({ code: "UNAUTHORIZED", message: "Invalid email or password" });
      }
      const token = await createJWT({ userId: user.id, email: user.email });
      return { token, user: { id: user.id, email: user.email, name: user.name } };
    }),

  me: publicProcedure.query(async ({ ctx }) => {
    const authHeader = ctx.req.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      throw new TRPCError({ code: "UNAUTHORIZED", message: "Not authenticated" });
    }
    const payload = await verifyJWT(authHeader.slice(7));
    if (!payload) {
      throw new TRPCError({ code: "UNAUTHORIZED", message: "Invalid or expired token" });
    }
    const user = getUserFromStore(payload.userId);
    if (!user) {
      throw new TRPCError({ code: "NOT_FOUND", message: "User not found" });
    }
    return { id: user.id, email: user.email, name: user.name };
  }),
});
