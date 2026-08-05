/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as generate from "../generate.js";
import type * as groups from "../groups.js";
import type * as http from "../http.js";
import type * as lib_codes from "../lib/codes.js";
import type * as lib_components from "../lib/components.js";
import type * as lib_dto from "../lib/dto.js";
import type * as lib_openai from "../lib/openai.js";
import type * as lib_prompts from "../lib/prompts.js";
import type * as lib_schemas from "../lib/schemas.js";
import type * as lib_tokens from "../lib/tokens.js";
import type * as lib_validators from "../lib/validators.js";
import type * as quota from "../quota.js";
import type * as share from "../share.js";
import type * as sharedTrips from "../sharedTrips.js";
import type * as trips from "../trips.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  generate: typeof generate;
  groups: typeof groups;
  http: typeof http;
  "lib/codes": typeof lib_codes;
  "lib/components": typeof lib_components;
  "lib/dto": typeof lib_dto;
  "lib/openai": typeof lib_openai;
  "lib/prompts": typeof lib_prompts;
  "lib/schemas": typeof lib_schemas;
  "lib/tokens": typeof lib_tokens;
  "lib/validators": typeof lib_validators;
  quota: typeof quota;
  share: typeof share;
  sharedTrips: typeof sharedTrips;
  trips: typeof trips;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
