type JSONRecord = Record<string, unknown>;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * Adds durable IDs to generated collection items before they become shared
 * state. Older model schemas did not ask for IDs, which meant each Swift
 * decoder minted a different UUID for the same logical item. That breaks
 * per-device favourites and decisions as soon as a group is reopened.
 *
 * The walk is intentionally shape-based rather than key-name-based: only the
 * generated item types that the clients identify can receive an ID. Existing
 * valid UUIDs are preserved, so retrying or republishing never changes an
 * item's identity.
 */
export function stampMissingStableIds(
  value: unknown,
  makeID: () => string = () => crypto.randomUUID(),
): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => stampMissingStableIds(item, makeID));
  }
  if (!isRecord(value)) return value;

  const stamped = Object.fromEntries(
    Object.entries(value).map(([key, child]) => [
      key,
      stampMissingStableIds(child, makeID),
    ]),
  ) as JSONRecord;

  if (isIdentifiedGeneratedItem(stamped) && !isUUID(stamped.id)) {
    stamped.id = makeID();
  }
  return stamped;
}

function isRecord(value: unknown): value is JSONRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isUUID(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function hasStrings(record: JSONRecord, ...keys: string[]): boolean {
  return keys.every((key) => typeof record[key] === "string");
}

function isIdentifiedGeneratedItem(record: JSONRecord): boolean {
  // LocationLinkableText and Itinerary.SecretTip.
  if (typeof record.text === "string") return true;

  // Suggestions.Category and deep-dive categories.
  if (hasStrings(record, "title") && Array.isArray(record.texts)) return true;

  // WorthItItem.
  if (hasStrings(record, "place", "theCase", "theCatch", "verdict")) return true;

  // StayArea.
  if (hasStrings(record, "area", "theCase", "bestFor", "watchOut")) return true;

  // KnowBeforeYouGo.Section.
  if (
    hasStrings(record, "bucket", "title", "body") &&
    Array.isArray(record.bullets)
  ) {
    return true;
  }

  // NearYou.LiveFind: web-sourced editorial content without MapKit identity.
  if (
    hasStrings(record, "name", "category", "locationHint", "explanation", "sourceURL")
  ) {
    return true;
  }

  // NearYou editorial sections. Candidate/place IDs are already grounded IDs.
  return hasStrings(record, "title") && Array.isArray(record.picks);
}
