import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "../create-context";

const CRAZYTEL_API_BASE = "https://www.crazytel.io/api/v1";

// Helper for making requests to CrazyTel API
async function crazytelRequest(
  path: string,
  apiKey: string,
  method = "GET",
  body?: unknown
) {
  if (!apiKey) {
    throw new Error("CrazyTel API key is required");
  }

  const options: RequestInit = {
    method,
    headers: {
      "Content-Type": "application/json",
      "accept": "application/json",
      "X-Crazytel-Api-Key": apiKey,
    },
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  const res = await fetch(`${CRAZYTEL_API_BASE}${path}`, options);
  
  if (!res.ok) {
    let errorMessage = `CrazyTel Error (${res.status})`;
    try {
      const errorJson = await res.json();
      if (errorJson?.error?.message) {
        errorMessage = `CrazyTel Error (${res.status}): ${errorJson.error.message}`;
      } else {
        errorMessage = `CrazyTel Error (${res.status}): ${JSON.stringify(errorJson)}`;
      }
    } catch {
      const errorText = await res.text();
      errorMessage = `CrazyTel Error (${res.status}): ${errorText}`;
    }
    throw new Error(errorMessage);
  }

  return res.json();
}

export const crazytelRouter = createTRPCRouter({
  testConnection: publicProcedure
    .input(z.object({ apiKey: z.string() }))
    .mutation(async ({ input }) => {
      try {
        await crazytelRequest("/balance/", input.apiKey);
        return { success: true };
      } catch (error: unknown) {
        return { success: false, error: (error as Error).message };
      }
    }),

  fetchBalance: publicProcedure
    .input(z.object({ apiKey: z.string() }))
    .query(async ({ input }) => {
      return crazytelRequest("/balance/", input.apiKey);
    }),

  fetchOwnedDIDs: publicProcedure
    .input(z.object({ apiKey: z.string() }))
    .query(async ({ input }) => {
      return crazytelRequest("/phone-numbers/", input.apiKey);
    }),

  fetchAvailableNumbers: publicProcedure
    .input(z.object({ apiKey: z.string() }))
    .query(async ({ input }) => {
      return crazytelRequest("/phone-numbers/available-numbers/", input.apiKey);
    }),

  fetchAddresses: publicProcedure
    .input(z.object({ apiKey: z.string() }))
    .query(async ({ input }) => {
      return crazytelRequest("/phone-numbers/addresses/", input.apiKey);
    }),

  fetchOwners: publicProcedure
    .input(z.object({ apiKey: z.string() }))
    .query(async ({ input }) => {
      return crazytelRequest("/phone-numbers/owners/", input.apiKey);
    }),

  purchaseDID: publicProcedure
    .input(
      z.object({
        apiKey: z.string(),
        number: z.string(),
        addressId: z.string(),
        ownerId: z.string(),
      })
    )
    .mutation(async ({ input }) => {
      return crazytelRequest("/phone-numbers/purchase", input.apiKey, "POST", {
        number: input.number,
        addressId: input.addressId,
        ownerId: input.ownerId,
      });
    }),

  sendSMS: publicProcedure
    .input(
      z.object({
        apiKey: z.string(),
        from: z.string(),
        to: z.string(),
        message: z.string(),
      })
    )
    .mutation(async ({ input }) => {
      return crazytelRequest("/sms/send", input.apiKey, "POST", {
        from_number: input.from,
        to_number: input.to,
        message: input.message,
      });
    }),
});
